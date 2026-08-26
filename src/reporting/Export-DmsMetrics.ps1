#Requires -Version 7.2
<#
.SYNOPSIS
    Computes and exports the DMS metric set defined in config/metrics.json.
.DESCRIPTION
    Implements PRD F-027 and section 20. Every metric is exported with its definition, source,
    freshness timestamp, exclusions and target alongside the value, because PRD R-19 warns that
    metrics without definitions and owners drive incorrect behaviour.

    Read-only. Produces CSV for portability (NFR-018) and JSON for dashboards.

    Power BI is NOT implemented. No report artefact or reproducible build exists, so it is recorded
    as planned rather than claimed.
.PARAMETER Environment
    Environment key.
.PARAMETER Connection
    PnP connection. Without one, the metric dictionary is exported with null values so the definitions
    can still be reviewed and signed off before a tenant exists.
.PARAMETER OutputPath
    Output directory.
.EXAMPLE
    ./Export-DmsMetrics.ps1 -Environment dev -Connection $c
.OUTPUTS
    PSCustomObject with the export paths and metric rows.
#>
[CmdletBinding()]
param(
    [Parameter()][ValidateSet('dev','test','prod')][string]$Environment = 'dev',
    [Parameter()]$Connection = $null,
    [Parameter()][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force

$config = Get-DmsConfiguration -Environment $Environment
if (-not $OutputPath) { $OutputPath = Join-Path (Get-DmsRepositoryRoot) 'artifacts' 'discovery' }
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

$isOnline = ($null -ne $Connection)
$now = (Get-Date).ToUniversalTime()
$rows = [System.Collections.Generic.List[object]]::new()

# Metrics computable from SharePoint data. Others are sourced from usability tests, Purview or
# recovery exercises and are exported with a null value and their source named.
# Metrics computable from SharePoint data. Others come from usability tests, Purview or recovery
# exercises and are exported with a null value and their real source named - never estimated.
#
# Each closure receives the document/evidence sets plus the resolved retention-approval state, so
# nothing is hard-coded: an unapproved file plan produces a genuine 0%, an approved one does not.
$computable = @{
    'MET-001' = { param($docs, $evid, $approvedClasses, $activeOwners)
        if (-not $docs) { return $null }
        $eff = @($docs | Where-Object { $_.DmsCurrentEffective })
        if ($eff.Count -eq 0) { return $null }

        # Index evidence by document id + business revision so each document is matched to ITS own
        # evidence rather than to the existence of any evidence at all.
        $evidenceIndex = @{}
        foreach ($e in @($evid)) {
            $key = '{0}|{1}' -f $e.DmsDocumentId, $e.DmsBusinessRevision
            if (-not $evidenceIndex.ContainsKey($key)) { $evidenceIndex[$key] = 0 }
            $evidenceIndex[$key]++
        }

        $pass = 0
        foreach ($d in $eff) {
            $key           = '{0}|{1}' -f $d.DmsDocumentId, $d.DmsBusinessRevision
            $hasEvidence   = $evidenceIndex.ContainsKey($key)
            $ownerLogin    = if ($d.DmsDocumentOwner) { "$($d.DmsDocumentOwner.Email)" } else { '' }
            $ownerIsActive = (-not [string]::IsNullOrWhiteSpace($ownerLogin)) -and
                             (($null -eq $activeOwners) -or $activeOwners.Contains($ownerLogin))
            $retentionOk   = (-not [string]::IsNullOrWhiteSpace("$($d.DmsRetentionClass)")) -and
                             $approvedClasses.Contains("$($d.DmsRetentionClass)")

            if ((Test-DmsControlCompleteness -Document $d -HasApprovalEvidence $hasEvidence `
                    -OwnerIsActive $ownerIsActive -RetentionClassApproved $retentionOk).IsComplete) { $pass++ }
        }
        [math]::Round($pass / $eff.Count * 100, 1) }

    'MET-004' = { param($docs, $evid, $approvedClasses, $activeOwners)
        if (-not $docs) { return $null }
        $due = @($docs | Where-Object { $_.DmsCurrentEffective -and $_.DmsNextReviewDate })
        if ($due.Count -eq 0) { return $null }
        $overdue = @($due | Where-Object { [datetime]$_.DmsNextReviewDate -lt $now })
        [math]::Round($overdue.Count / $due.Count * 100, 1) }

    'MET-005' = { param($docs, $evid, $approvedClasses, $activeOwners)
        if (-not $docs) { return $null }
        @($docs | Where-Object {
            $_.DmsCurrentEffective -and (
                (-not $_.DmsDocumentOwner) -or
                (($null -ne $activeOwners) -and (-not $activeOwners.Contains("$($_.DmsDocumentOwner.Email)")))
            )
        }).Count }
}

# Retention classes that are genuinely approved. An unapproved file plan legitimately drives MET-001
# to 0%, but that must be derived from configuration, not assumed.
$approvedClasses = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@($config.RetentionMap.retentionClasses |
        Where-Object { $_.status -eq 'Approved' -and $_.retentionAuthority -ne 'REQUIRES_RECORDS_APPROVAL' -and $_.period -ne 'REQUIRES_RECORDS_APPROVAL' } |
        ForEach-Object { $_.recordClass }),
    [System.StringComparer]::OrdinalIgnoreCase)

$docs = $null; $evidence = $null; $activeOwners = $null
if ($isOnline) {
    $docs     = @(Get-PnPListItem -List 'Controlled Documents' -PageSize 500 -Connection $Connection | ForEach-Object { $_.FieldValues })
    $evidence = @(Get-PnPListItem -List 'Approval Evidence'    -PageSize 500 -Connection $Connection | ForEach-Object { $_.FieldValues })

    # Resolve which owners are still active. If the directory cannot be read, leave $activeOwners null
    # so owner status is treated as unknown rather than silently assumed active.
    try {
        $owners = @($docs | Where-Object { $_.DmsDocumentOwner } | ForEach-Object { "$($_.DmsDocumentOwner.Email)" } | Sort-Object -Unique)
        $activeOwners = [System.Collections.Generic.HashSet[string]]::new([string[]]@(), [System.StringComparer]::OrdinalIgnoreCase)
        foreach ($o in $owners) {
            try { if (Get-PnPUser -Identity $o -Connection $Connection -ErrorAction Stop) { [void]$activeOwners.Add($o) } } catch { }
        }
    } catch {
        $activeOwners = $null
        Write-Warning "Could not resolve owner status; MET-001 and MET-005 will treat owner activity as unknown."
    }
}

foreach ($m in $config.Metrics.metrics) {
    $value = $null; $note = 'Requires a tenant connection.'
    if ($isOnline -and $computable.ContainsKey($m.id)) {
        try { $value = & $computable[$m.id] $docs $evidence $approvedClasses $activeOwners; $note = 'Computed from SharePoint.' }
        catch { $note = "Computation failed: $(Protect-DmsSensitiveText -Text $_.Exception.Message)" }
    } elseif (-not $computable.ContainsKey($m.id)) {
        $note = "Sourced from: $((@($m.sources)) -join ', '). Not computable from SharePoint alone."
    }

    $rows.Add([PSCustomObject]@{
        MetricId    = $m.id
        Name        = $m.name
        Value       = $value
        Target      = $m.target
        Formula     = $m.formula
        Sources     = (@($m.sources)) -join '; '
        Refresh     = $m.refresh
        Owner       = $m.owner
        Visibility  = (@($m.visibility)) -join '; '
        Exclusions  = (Get-DmsPropertyOrDefault -InputObject $m -Name 'exclusions' -Default '')
        Requirements= (@(Get-DmsPropertyOrDefault -InputObject $m -Name 'requirements' -Default @())) -join '; '
        DataAsOfUtc = $now.ToString('o')
        Note        = $note
    }) | Out-Null
}

$stamp = $now.ToString('yyyyMMddTHHmmssZ')
$csv  = Join-Path $OutputPath "dms-metrics-$Environment-$stamp.csv"
$json = Join-Path $OutputPath "dms-metrics-$Environment-$stamp.json"
$rows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding utf8
$rows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $json -Encoding utf8

Write-Information "" -InformationAction Continue
Write-Information ("DMS metrics  environment={0}  as of {1}" -f $Environment, $now.ToString('u')) -InformationAction Continue
Write-Information ('-' * 100) -InformationAction Continue
foreach ($r in $rows) {
    Write-Information ("{0}  {1,-34} value={2,-8} target={3}" -f $r.MetricId, $r.Name, $(if ($null -ne $r.Value) { $r.Value } else { 'n/a' }), $r.Target) -InformationAction Continue
}
Write-Information ('-' * 100) -InformationAction Continue
Write-Information ("Exported {0} metric definitions to:`n  {1}`n  {2}" -f $rows.Count, $csv, $json) -InformationAction Continue
if (-not $isOnline) { Write-Warning 'No tenant connection: metric DEFINITIONS exported with null values. No metric value is claimed.' }

return [PSCustomObject]@{ csvPath=$csv; jsonPath=$json; metricCount=$rows.Count; computedCount=@($rows | Where-Object { $null -ne $_.Value }).Count; exitCode=0 }
