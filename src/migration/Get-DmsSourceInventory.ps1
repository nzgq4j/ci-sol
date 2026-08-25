#Requires -Version 7.2
<#
.SYNOPSIS
    Inventories a migration source. Read-only.
.DESCRIPTION
    Implements PRD F-037 phase 1 and DATA-012. Produces the evidence needed to decide whether a source
    is fit to migrate: counts, sizes, duplicates, invalid names, excessive paths and unknown ownership.

    This script NEVER modifies or deletes source content (PRD ADR-014, C-009).

    Revision and status encoded in file or folder names are recorded VERBATIM as provenance and are
    deliberately NOT parsed into DmsBusinessRevision or DmsLifecycleStatus. Inferring control metadata
    from a filename manufactures evidence that does not exist.
.PARAMETER SourcePath
    Root of the source repository.
.PARAMETER OutputPath
    Directory for the inventory output.
.PARAMETER ComputeHash
    Compute SHA-256 for each file. Only where chain of custody requires it; expensive at scale.
.PARAMETER MaxPathLength
    Path length above which an item is flagged.
.EXAMPLE
    ./Get-DmsSourceInventory.ps1 -SourcePath /mnt/legacy/quality
.OUTPUTS
    PSCustomObject inventory summary.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SourcePath,
    [Parameter()][string]$OutputPath,
    [Parameter()][switch]$ComputeHash,
    [Parameter()][int]$MaxPathLength = 400
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force

if (-not (Test-Path -LiteralPath $SourcePath)) { throw "Source path not found: $SourcePath" }
if (-not $OutputPath) { $OutputPath = Join-Path (Get-DmsRepositoryRoot) 'artifacts' 'discovery' }
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

$batchId = New-DmsCorrelationId
Write-DmsLog -Action 'SourceInventory' -Target $SourcePath -Result 'Info' -CorrelationId $batchId -Message 'Read-only inventory starting.' | Out-Null

# Patterns observed in real source repositories, where revision and status live in names.
$revisionInName = '(?i)(_v\d+|[-_ ]v\d+(\.\d+)?|[-_ ]rev\s*\d+|[-_ ]r\d+|[-_ ]\d+(\.\d+)?$)'
$statusInName   = '(?i)(draft|final|gold|pink|red[- ]team|obe|superseded|obsolete|old|archive|do[- ]not[- ]use|readyforfinal)'
$invalidChars   = '["*:<>?/\\|]'

$items = [System.Collections.Generic.List[object]]::new()
$files = Get-ChildItem -LiteralPath $SourcePath -Recurse -File -ErrorAction SilentlyContinue

foreach ($f in $files) {
    $flags = [System.Collections.Generic.List[string]]::new()
    if ($f.FullName.Length -gt $MaxPathLength)      { $flags.Add('ExcessivePath')    | Out-Null }
    if ($f.Name -match $invalidChars)               { $flags.Add('InvalidName')      | Out-Null }
    if ($f.Name -match $revisionInName)             { $flags.Add('RevisionInName')   | Out-Null }
    if ($f.Name -match $statusInName -or $f.DirectoryName -match $statusInName) { $flags.Add('StatusInName') | Out-Null }
    if ($f.Length -eq 0)                            { $flags.Add('ZeroLength')       | Out-Null }

    $hash = $null
    if ($ComputeHash) {
        try { $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash } catch { $flags.Add('HashFailed') | Out-Null }
    }

    $items.Add([PSCustomObject]@{
        SourcePath       = $f.FullName
        RelativePath     = $f.FullName.Substring($SourcePath.Length).TrimStart([char]92, '/')
        Name             = $f.Name
        Extension        = $f.Extension
        SizeBytes        = $f.Length
        LastModifiedUtc  = $f.LastWriteTimeUtc.ToString('o')
        CreatedUtc       = $f.CreationTimeUtc.ToString('o')
        Sha256           = $hash
        Flags            = $flags.ToArray()
        # Deliberately verbatim. NOT parsed into controlled metadata (ADR-014).
        ProvenanceNote   = "Source name and folder recorded verbatim. Revision, status, owner and approval history are NOT inferred."
        MigrationBatchId = $batchId
    }) | Out-Null
}

# Duplicate detection: by hash when available, otherwise by name+size, which is weaker and labelled so.
# The @() must wrap the WHOLE if/else. Without it, a single duplicate set is unwrapped from its
# array and $duplicateGroups.Count returns that GroupInfo's own Count (the number of files in the
# group) instead of the number of groups - silently reporting the wrong figure in migration evidence.
$duplicateGroups = @(
    if ($ComputeHash) {
        $items | Where-Object Sha256 | Group-Object Sha256 | Where-Object Count -gt 1
    } else {
        $items | Group-Object { '{0}|{1}' -f $_.Name, $_.SizeBytes } | Where-Object Count -gt 1
    }
)

$summary = [PSCustomObject]@{
    batchId              = $batchId
    sourcePath           = $SourcePath
    inventoriedUtc       = (Get-Date).ToUniversalTime().ToString('o')
    readOnly             = $true
    fileCount            = $items.Count
    totalSizeBytes       = ($items | Measure-Object -Property SizeBytes -Sum).Sum
    duplicateSetCount    = $duplicateGroups.Count
    duplicateFileCount   = @($duplicateGroups | ForEach-Object { $_.Group }).Count
    duplicateMethod      = if ($ComputeHash) { 'SHA-256 content hash' } else { 'name+size (weaker; rerun with -ComputeHash for content-based detection)' }
    excessivePathCount   = @($items | Where-Object { $_.Flags -contains 'ExcessivePath' }).Count
    invalidNameCount     = @($items | Where-Object { $_.Flags -contains 'InvalidName' }).Count
    revisionInNameCount  = @($items | Where-Object { $_.Flags -contains 'RevisionInName' }).Count
    statusInNameCount    = @($items | Where-Object { $_.Flags -contains 'StatusInName' }).Count
    zeroLengthCount      = @($items | Where-Object { $_.Flags -contains 'ZeroLength' }).Count
    hashesComputed       = [bool]$ComputeHash
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$items   | Export-Csv -LiteralPath (Join-Path $OutputPath "source-inventory-$stamp.csv") -NoTypeInformation -Encoding utf8
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputPath "source-inventory-summary-$stamp.json") -Encoding utf8

Write-Information "" -InformationAction Continue
Write-Information ("Source inventory  batch {0}" -f $batchId) -InformationAction Continue
Write-Information ("  files                 : {0}" -f $summary.fileCount) -InformationAction Continue
Write-Information ("  total size            : {0:N0} bytes" -f $summary.totalSizeBytes) -InformationAction Continue
Write-Information ("  duplicate sets        : {0} ({1})" -f $summary.duplicateSetCount, $summary.duplicateMethod) -InformationAction Continue
Write-Information ("  revision in filename  : {0}   <- will be quarantined, not parsed" -f $summary.revisionInNameCount) -InformationAction Continue
Write-Information ("  status in name/folder : {0}   <- will be quarantined, not parsed" -f $summary.statusInNameCount) -InformationAction Continue
Write-Information ("  invalid names         : {0}" -f $summary.invalidNameCount) -InformationAction Continue
Write-Information ("  excessive paths       : {0}" -f $summary.excessivePathCount) -InformationAction Continue

return $summary
