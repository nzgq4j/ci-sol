#Requires -Version 7.2
<#
.SYNOPSIS
    Exports the live DMS configuration from a tenant and reports drift against the approved baseline.
.DESCRIPTION
    Implements PRD NFR-019: production configuration is compared to an approved baseline after each
    release and at least monthly. Also produces the portable export PRD NFR-018 requires.

    Read-only. It never changes tenant state.
.PARAMETER Environment
    Environment key.
.PARAMETER Connection
    PnP connection. Required; there is nothing to export without one.
.PARAMETER OutputPath
    Directory for the exported snapshot.
.PARAMETER CompareToBaseline
    Also emit a drift report against config/*.json.
.EXAMPLE
    ./Export-DmsConfiguration.ps1 -Environment dev -Connection $c -CompareToBaseline
.OUTPUTS
    PSCustomObject with the snapshot path and drift summary.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('dev','test','prod')][string]$Environment,
    [Parameter(Mandatory)]$Connection,
    [Parameter()][string]$OutputPath,
    [Parameter()][switch]$CompareToBaseline
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force

$config = Get-DmsConfiguration -Environment $Environment
if (-not $OutputPath) { $OutputPath = Join-Path (Get-DmsRepositoryRoot) 'artifacts' 'discovery' }
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

$correlationId = New-DmsCorrelationId
Write-DmsLog -Action 'ExportConfiguration' -Target $Environment -Result 'Info' -Environment $Environment -CorrelationId $correlationId | Out-Null

$snapshot = [ordered]@{
    exportedUtc   = (Get-Date).ToUniversalTime().ToString('o')
    environment   = $Environment
    correlationId = $correlationId
    fields        = @()
    contentTypes  = @()
    lists         = @()
}

foreach ($col in $config.SiteColumns.columns) {
    try {
        $f = Get-PnPField -Identity $col.internalName -Connection $Connection -ErrorAction Stop
        $snapshot.fields += [ordered]@{ internalName = "$($f.InternalName)"; title = "$($f.Title)"; type = "$($f.TypeAsString)"; required = [bool]$f.Required; indexed = [bool]$f.Indexed }
    } catch {
        $snapshot.fields += [ordered]@{ internalName = $col.internalName; present = $false }
    }
}

foreach ($ct in $config.ContentTypes.contentTypes) {
    try {
        $c = Get-PnPContentType -Identity $ct.name -Connection $Connection -ErrorAction Stop
        $snapshot.contentTypes += [ordered]@{ name = "$($c.Name)"; id = "$($c.Id.StringValue)"; group = "$($c.Group)" }
    } catch {
        $snapshot.contentTypes += [ordered]@{ name = $ct.name; present = $false }
    }
}

foreach ($container in (@($config.Libraries.libraries) + @($config.Lists.lists))) {
    try {
        $l = Get-PnPList -Identity $container.title -Connection $Connection -ErrorAction Stop
        $snapshot.lists += [ordered]@{
            title = "$($l.Title)"; itemCount = [int]$l.ItemCount
            enableVersioning = [bool]$l.EnableVersioning; enableMinorVersions = [bool]$l.EnableMinorVersions
            enableModeration = [bool]$l.EnableModeration; forceCheckout = [bool]$l.ForceCheckout
            draftVersionVisibility = "$($l.DraftVersionVisibility)"; enableFolderCreation = [bool]$l.EnableFolderCreation
            hasUniqueRoleAssignments = [bool]$l.HasUniqueRoleAssignments
        }
    } catch {
        $snapshot.lists += [ordered]@{ title = $container.title; present = $false }
    }
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$file  = Join-Path $OutputPath "dms-config-$Environment-$stamp.json"
($snapshot | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $file -Encoding utf8

$drift = @()
if ($CompareToBaseline) {
    foreach ($lib in $config.Libraries.libraries) {
        if (Get-DmsPropertyOrDefault -InputObject $lib -Name 'provisionWhen' -Default '') { continue }
        $actual = $snapshot.lists | Where-Object { $_.title -eq $lib.title } | Select-Object -First 1
        if (-not $actual -or (Test-DmsProperty -InputObject ([PSCustomObject]$actual) -Name 'present')) {
            $drift += [PSCustomObject]@{ resource = "Library/$($lib.title)"; setting = '(existence)'; expected = 'present'; actual = 'absent'; severity = 'High' }
            continue
        }
        $compare = @(
            @{ n='enableVersioning';       e=[bool]$lib.versioning.enableVersioning;        a=[bool]$actual.enableVersioning }
            @{ n='enableMinorVersions';    e=[bool]$lib.versioning.enableMinorVersions;     a=[bool]$actual.enableMinorVersions }
            @{ n='enableModeration';       e=[bool]$lib.contentApproval.enableModeration;   a=[bool]$actual.enableModeration }
            @{ n='forceCheckout';          e=[bool]$lib.checkOut.forceCheckout;             a=[bool]$actual.forceCheckout }
            @{ n='draftVersionVisibility'; e="$($lib.contentApproval.draftVisibility)";     a="$($actual.draftVersionVisibility)" }
        )
        foreach ($c in $compare) {
            if ($c.e -ne $c.a) {
                # Draft visibility drift is High: it is the control that keeps drafts away from readers.
                $sev = if ($c.n -in @('draftVersionVisibility','enableModeration')) { 'High' } else { 'Medium' }
                $drift += [PSCustomObject]@{ resource = "Library/$($lib.title)"; setting = $c.n; expected = $c.e; actual = $c.a; severity = $sev }
            }
        }
    }
    $driftFile = Join-Path $OutputPath "dms-drift-$Environment-$stamp.json"
    ($drift | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $driftFile -Encoding utf8
}

return [PSCustomObject]@{
    snapshotPath = $file
    driftCount   = @($drift).Count
    highSeverityDriftCount = @($drift | Where-Object severity -eq 'High').Count
    drift        = $drift
    exitCode     = $(if (@($drift | Where-Object severity -eq 'High').Count -gt 0) { 1 } else { 0 })
}
