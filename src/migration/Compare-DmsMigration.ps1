#Requires -Version 7.2
<#
.SYNOPSIS
    Reconciles a migration batch between source inventory and target.
.DESCRIPTION
    Implements PRD F-037 phase 6 and INT-010. Compares counts, sizes and, where hashes were captured,
    content. Produces the evidence required by the acceptance report.

    Read-only against both source and target.
.PARAMETER SourceInventoryPath
    CSV produced by Get-DmsSourceInventory.ps1.
.PARAMETER TargetInventoryPath
    CSV of imported items exported from the target.
.PARAMETER SizeTolerancePercent
    Permitted total-size variance. Defaults to zero: any variance is reported.
.EXAMPLE
    ./Compare-DmsMigration.ps1 -SourceInventoryPath src.csv -TargetInventoryPath tgt.csv
.OUTPUTS
    PSCustomObject reconciliation result.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceInventoryPath,
    [Parameter(Mandatory)][string]$TargetInventoryPath,
    [Parameter()][double]$SizeTolerancePercent = 0
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force

$source = @(Import-Csv -LiteralPath $SourceInventoryPath)
$target = @(Import-Csv -LiteralPath $TargetInventoryPath)

$findings = [System.Collections.Generic.List[object]]::new()
function Add-Finding { param($Check,$Expected,$Actual,$Severity,$Detail)
    $findings.Add([PSCustomObject]@{ Check=$Check; Expected=$Expected; Actual=$Actual; Severity=$Severity; Detail=$Detail; Passed=($Expected -eq $Actual) }) | Out-Null
}

$srcSize = ($source | Measure-Object -Property SizeBytes -Sum).Sum
$tgtSize = ($target | Measure-Object -Property SizeBytes -Sum).Sum

Add-Finding 'FileCount' $source.Count $target.Count 'High' 'Every inventoried file must be imported or explicitly quarantined.'

$sizeVariance = if ($srcSize -gt 0) { [math]::Abs($srcSize - $tgtSize) / $srcSize * 100 } else { 0 }
$findings.Add([PSCustomObject]@{
    Check='TotalSize'; Expected=$srcSize; Actual=$tgtSize; Severity='High'
    Detail=("Variance {0:N4}% against tolerance {1}%." -f $sizeVariance, $SizeTolerancePercent)
    Passed=($sizeVariance -le $SizeTolerancePercent)
}) | Out-Null

# Content comparison, only where the source inventory captured hashes.
$srcHashed = @($source | Where-Object { $_.PSObject.Properties.Name -contains 'Sha256' -and $_.Sha256 })
if ($srcHashed.Count -gt 0 -and ($target | Where-Object { $_.PSObject.Properties.Name -contains 'Sha256' })) {
    $tgtByPath = @{}
    foreach ($t in $target) { if ($t.RelativePath) { $tgtByPath[$t.RelativePath] = $t } }
    $mismatch = 0; $missing = 0
    foreach ($s in $srcHashed) {
        if (-not $tgtByPath.ContainsKey($s.RelativePath)) { $missing++; continue }
        if ($tgtByPath[$s.RelativePath].Sha256 -ne $s.Sha256) { $mismatch++ }
    }
    Add-Finding 'HashMismatch' 0 $mismatch 'High' 'Content differs between source and target.'
    Add-Finding 'HashMissingInTarget' 0 $missing 'High' 'Hashed source item absent from target.'
} else {
    $findings.Add([PSCustomObject]@{ Check='ContentHash'; Expected='n/a'; Actual='not captured'; Severity='Info'
        Detail='Hashes were not computed. Content equality is NOT proven. Rerun inventory with -ComputeHash where chain of custody requires it.'; Passed=$true }) | Out-Null
}

# Duplicate Document IDs in the target are a hard failure (PRD F-002).
if ($target | Where-Object { $_.PSObject.Properties.Name -contains 'DmsDocumentId' }) {
    $dupIds = @($target | Where-Object DmsDocumentId | Group-Object DmsDocumentId | Where-Object Count -gt 1)
    Add-Finding 'DuplicateDocumentId' 0 $dupIds.Count 'High' 'Duplicate Document IDs in the target violate PRD F-002.'
}

$failed = @($findings | Where-Object { -not $_.Passed })
$result = [PSCustomObject]@{
    sourceCount    = $source.Count
    targetCount    = $target.Count
    findings       = $findings.ToArray()
    failedCount    = $failed.Count
    reconciled     = ($failed.Count -eq 0)
    exitCode       = $(if ($failed.Count -gt 0) { 1 } else { 0 })
}

Write-Information "" -InformationAction Continue
Write-Information "Migration reconciliation" -InformationAction Continue
foreach ($f in $findings) {
    Write-Information ("  {0}  {1,-22} expected={2} actual={3}  {4}" -f $(if ($f.Passed) { 'PASS' } else { 'FAIL' }), $f.Check, $f.Expected, $f.Actual, $f.Detail) -InformationAction Continue
}
Write-Information ("  reconciled: {0}" -f $result.reconciled) -InformationAction Continue
return $result
