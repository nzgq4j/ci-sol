#Requires -Version 7.2
<#
.SYNOPSIS
    Performs read-only tenant discovery for the DMS. Never changes tenant state.
.DESCRIPTION
    Implements PRD Phase 1. Collects the configuration facts the architecture depends on, so design
    decisions rest on observed state rather than assumption.

    Every operation is a read. There is no Apply mode and no mutating cmdlet in this script, which
    is verified by the discovery test in tests/pester.

    Output is written to artifacts/discovery/, which is excluded from source control because a
    tenant configuration export can contain sensitive structural detail.
.PARAMETER Connection
    PnP connection for SharePoint discovery.
.PARAMETER TenantAdminConnection
    Optional separate connection to the SharePoint admin endpoint for tenant-scope discovery.
.PARAMETER OutputPath
    Directory for discovery output.
.EXAMPLE
    ./Invoke-DmsDiscovery.ps1 -Connection $c
.OUTPUTS
    PSCustomObject with the discovery result and the report path.
#>
[CmdletBinding()]
param(
    [Parameter()]$Connection = $null,
    [Parameter()]$TenantAdminConnection = $null,
    [Parameter()][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force

if (-not $OutputPath) { $OutputPath = Join-Path (Get-DmsRepositoryRoot) 'artifacts' 'discovery' }
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

$correlationId = New-DmsCorrelationId
$discovery = [ordered]@{
    discoveredUtc = (Get-Date).ToUniversalTime().ToString('o')
    correlationId = $correlationId
    readOnly      = $true
    sections      = [ordered]@{}
    blocked       = @()
}

function Invoke-DiscoveryStep {
    param([string]$Name, [scriptblock]$Step, [string]$RequiredFor)
    try {
        $discovery.sections[$Name] = & $Step
        Write-DmsLog -Action 'Discover' -Target $Name -Result 'Info' -CorrelationId $correlationId | Out-Null
    } catch {
        $discovery.blocked += [ordered]@{ section = $Name; requiredFor = $RequiredFor; reason = (Protect-DmsSensitiveText -Text $_.Exception.Message) }
        Write-DmsLog -Action 'Discover' -Target $Name -Result 'Blocked' -Level Warning -CorrelationId $correlationId -Message $_.Exception.Message | Out-Null
    }
}

if ($null -ne $Connection) {
    Invoke-DiscoveryStep -Name 'web' -RequiredFor 'Site topology' -Step {
        $w = Get-PnPWeb -Connection $Connection
        [ordered]@{ url = "$($w.Url)"; title = "$($w.Title)"; template = "$($w.WebTemplate)"; language = "$($w.Language)" }
    }
    Invoke-DiscoveryStep -Name 'lists' -RequiredFor 'F-004 library configuration baseline' -Step {
        @(Get-PnPList -Connection $Connection | ForEach-Object {
            [ordered]@{
                title = "$($_.Title)"; itemCount = [int]$_.ItemCount; template = "$($_.BaseTemplate)"
                enableVersioning = [bool]$_.EnableVersioning; enableMinorVersions = [bool]$_.EnableMinorVersions
                enableModeration = [bool]$_.EnableModeration; forceCheckout = [bool]$_.ForceCheckout
                hasUniqueRoleAssignments = [bool]$_.HasUniqueRoleAssignments
            }
        })
    }
    Invoke-DiscoveryStep -Name 'contentTypes' -RequiredFor 'F-001 conflict detection' -Step {
        @(Get-PnPContentType -Connection $Connection | ForEach-Object { [ordered]@{ name = "$($_.Name)"; id = "$($_.Id.StringValue)"; group = "$($_.Group)" } })
    }
    Invoke-DiscoveryStep -Name 'dmsFields' -RequiredFor 'F-001 existing schema' -Step {
        @(Get-PnPField -Connection $Connection | Where-Object { "$($_.InternalName)" -like 'Dms*' } |
          ForEach-Object { [ordered]@{ internalName = "$($_.InternalName)"; type = "$($_.TypeAsString)"; indexed = [bool]$_.Indexed } })
    }
    Invoke-DiscoveryStep -Name 'siteGroups' -RequiredFor 'F-024 role model' -Step {
        @(Get-PnPGroup -Connection $Connection | ForEach-Object { [ordered]@{ title = "$($_.Title)"; ownerTitle = "$($_.OwnerTitle)" } })
    }
    Invoke-DiscoveryStep -Name 'retentionLabelsInUse' -RequiredFor 'F-018 label coverage' -Step {
        @(Get-PnPRetentionLabel -Connection $Connection | ForEach-Object { [ordered]@{ name = "$($_.TagName)" } })
    }
} else {
    $discovery.blocked += [ordered]@{ section = 'all-sharepoint'; requiredFor = 'Phase 1 discovery'; reason = 'No PnP connection was supplied.' }
}

if ($null -ne $TenantAdminConnection) {
    Invoke-DiscoveryStep -Name 'tenantSites' -RequiredFor 'OQ-10 migration scoping, F-025 sharing' -Step {
        @(Get-PnPTenantSite -Connection $TenantAdminConnection | ForEach-Object {
            [ordered]@{ url = "$($_.Url)"; template = "$($_.Template)"; sharingCapability = "$($_.SharingCapability)"; lastModified = "$($_.LastContentModifiedDate)" }
        })
    }
} else {
    $discovery.blocked += [ordered]@{ section = 'tenant'; requiredFor = 'F-025 external sharing verification'; reason = 'No tenant admin connection was supplied.' }
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$file  = Join-Path $OutputPath "dms-discovery-$stamp.json"
($discovery | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $file -Encoding utf8

Write-Information "" -InformationAction Continue
Write-Information ("Discovery written to {0}" -f $file) -InformationAction Continue
Write-Information ("Sections collected : {0}" -f $discovery.sections.Keys.Count) -InformationAction Continue
Write-Information ("Sections blocked   : {0}" -f @($discovery.blocked).Count) -InformationAction Continue
foreach ($b in $discovery.blocked) { Write-Information ("  - {0}: {1}" -f $b.section, $b.reason) -InformationAction Continue }

return [PSCustomObject]@{
    reportPath   = $file
    sectionCount = $discovery.sections.Keys.Count
    blockedCount = @($discovery.blocked).Count
    readOnly     = $true
    exitCode     = 0
}
