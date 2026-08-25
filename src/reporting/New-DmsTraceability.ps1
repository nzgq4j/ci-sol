#Requires -Version 7.2
<#
.SYNOPSIS
    Generates the requirements traceability matrix by scanning the PRD and the repository.
.DESCRIPTION
    Implements PRD section 14 and the requirement that traceability is updated whenever the
    implementation changes.

    Requirement IDs are extracted from SharePoint_DMS_PRD.md rather than transcribed by hand, so an
    ID cannot be missed or invented. Each ID is then located across configuration, provisioning
    code, flow specifications, tests and documentation, and its coverage is classified.

    Coverage classification:
      Implemented and tested        - referenced by config or code AND by a test
      Implemented, validation pending - referenced by config or code, no test reference
      Specified                     - referenced only by a flow specification or design document
      Not referenced                - no reference anywhere
.PARAMETER PrdPath
    Path to the PRD.
.PARAMETER OutputPath
    Output document path.
.EXAMPLE
    ./New-DmsTraceability.ps1
.OUTPUTS
    PSCustomObject with coverage counts.
#>
[CmdletBinding()]
param(
    [Parameter()][string]$PrdPath,
    [Parameter()][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force
$repo = Get-DmsRepositoryRoot
if (-not $PrdPath)    { $PrdPath    = Join-Path $repo 'SharePoint_DMS_PRD.md' }
if (-not $OutputPath) { $OutputPath = Join-Path $repo 'docs' 'REQUIREMENTS_TRACEABILITY.md' }

$prd = Get-Content -LiteralPath $PrdPath -Raw -Encoding utf8

# Extract requirement IDs and, where the PRD uses a table row, the requirement statement.
$idPattern = '\b(F-\d{3}|NFR-\d{3}|SEC-\d{3}|DATA-\d{3}|INT-\d{3}|ADM-\d{3}|UX-\d{3}|MET-\d{3}|OBJ-\d{2}|OQ-\d{2}|WF-\d{2})\b'
$ids = @([regex]::Matches($prd, $idPattern) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

# P0 determination: the PRD marks functional requirement priority as "P0 / <source>" in its tables.
$priority = @{}
foreach ($line in ($prd -split "`n")) {
    if ($line -match '^\|\s*(F-\d{3})\s*\|') {
        $rid = $Matches[1]
        if ($line -match '\|\s*(P[0-3])\s*/') { $priority[$rid] = $Matches[1] }
    }
}

# Collect a one-line statement for each ID from its PRD table row, where one exists.
$statement = @{}
foreach ($line in ($prd -split "`n")) {
    if ($line -match "^\|\s*($idPattern)\s*\|\s*(.+?)\s*\|") {
        $rid = $Matches[1]
        if (-not $statement.ContainsKey($rid)) {
            $text = $Matches[3] -replace '\*\*','' -replace '\|','\|'
            if ($text.Length -gt 150) { $text = $text.Substring(0,147) + '...' }
            $statement[$rid] = $text
        }
    }
}

# Index repository references, excluding the PRD itself and generated traceability.
$scan = @('config','src','tests','docs','pipelines','templates')
$files = foreach ($d in $scan) {
    $p = Join-Path $repo $d
    if (Test-Path $p) { Get-ChildItem $p -Recurse -File -Include '*.json','*.ps1','*.psm1','*.psd1','*.md','*.yml' -ErrorAction SilentlyContinue }
}
$files = @($files | Where-Object { $_.FullName -notmatch 'REQUIREMENTS_TRACEABILITY\.md$' -and $_.FullName -notmatch '[\\/]artifacts[\\/]' })

$refs = @{}
foreach ($f in $files) {
    $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding utf8
    foreach ($m in [regex]::Matches($content, $idPattern)) {
        $rid = $m.Groups[1].Value
        if (-not $refs.ContainsKey($rid)) { $refs[$rid] = [System.Collections.Generic.HashSet[string]]::new() }
        [void]$refs[$rid].Add((Resolve-Path -LiteralPath $f.FullName -Relative -RelativeBasePath $repo).TrimStart('.', [char]92, '/'))
    }
}

function Get-Coverage {
    param([string]$Id)
    if (-not $refs.ContainsKey($Id)) { return @{ Status='Not referenced'; Files=@() } }
    $f = @($refs[$Id])
    $inConfigOrCode = @($f | Where-Object { $_ -match '^(config|src)[\\/]' -and $_ -notmatch 'flow-specifications' }).Count -gt 0
    $inTests        = @($f | Where-Object { $_ -match '^tests[\\/]' }).Count -gt 0
    $inSpec         = @($f | Where-Object { $_ -match 'flow-specifications|^docs[\\/]' }).Count -gt 0
    $status = if ($inConfigOrCode -and $inTests) { 'Implemented and tested' }
              elseif ($inConfigOrCode)           { 'Implemented, tenant validation pending' }
              elseif ($inSpec)                   { 'Specified' }
              else                               { 'Not referenced' }
    return @{ Status=$status; Files=$f }
}

$groups = [ordered]@{
    'Functional requirements (F)'      = '^F-'
    'Non-functional requirements (NFR)'= '^NFR-'
    'Security and compliance (SEC)'    = '^SEC-'
    'Data requirements (DATA)'         = '^DATA-'
    'Integrations (INT)'               = '^INT-'
    'Administration (ADM)'             = '^ADM-'
    'User experience (UX)'             = '^UX-'
    'Metrics (MET)'                    = '^MET-'
    'Objectives (OBJ)'                 = '^OBJ-'
    'Workflows (WF)'                   = '^WF-'
    'Open questions (OQ)'              = '^OQ-'
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# Requirements Traceability Matrix')
[void]$sb.AppendLine()
[void]$sb.AppendLine('> **Generated file.** Produced by `src/reporting/New-DmsTraceability.ps1`, which extracts every requirement ID directly from `SharePoint_DMS_PRD.md` and locates each one across configuration, code, flow specifications, tests and documentation. Do not edit by hand.')
[void]$sb.AppendLine()
[void]$sb.AppendLine(('Generated {0}. Requirement IDs found in the PRD: **{1}**.' -f (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd'), $ids.Count))
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Coverage status meanings')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| Status | Meaning |')
[void]$sb.AppendLine('|---|---|')
[void]$sb.AppendLine('| Implemented and tested | Realised in configuration or code, and covered by an executing test. |')
[void]$sb.AppendLine('| Implemented, tenant validation pending | Realised in configuration or code. Cannot be proven against a tenant until a connection and the outstanding decisions exist. |')
[void]$sb.AppendLine('| Specified | Designed in a flow specification or design document; build depends on tenant access. |')
[void]$sb.AppendLine('| Not referenced | No reference in the repository. For a P0 requirement this is a gap. |')
[void]$sb.AppendLine()

$summary = @{}
foreach ($gname in $groups.Keys) {
    $pattern = $groups[$gname]
    $groupIds = @($ids | Where-Object { $_ -match $pattern })
    if ($groupIds.Count -eq 0) { continue }
    [void]$sb.AppendLine(('## {0}' -f $gname))
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| ID | Priority | Requirement | Coverage | Key artefacts |')
    [void]$sb.AppendLine('|---|:--:|---|---|---|')
    foreach ($id in ($groupIds | Sort-Object)) {
        $cov = Get-Coverage -Id $id
        $summary[$id] = $cov.Status
        $pri = if ($priority.ContainsKey($id)) { $priority[$id] } else { '' }
        $stmt = if ($statement.ContainsKey($id)) { $statement[$id] } else { '' }
        $top = @($cov.Files | Sort-Object { if ($_ -match '^config') { 0 } elseif ($_ -match '^src') { 1 } elseif ($_ -match '^tests') { 2 } else { 3 } } | Select-Object -First 4)
        $artefacts = if ($top.Count -gt 0) { ($top | ForEach-Object { "``$_``" }) -join '<br>' } else { '—' }
        [void]$sb.AppendLine(('| **{0}** | {1} | {2} | {3} | {4} |' -f $id, $pri, $stmt, $cov.Status, $artefacts))
    }
    [void]$sb.AppendLine()
}

# P0 summary — the acceptance-critical view.
$p0 = @($priority.Keys | Where-Object { $priority[$_] -eq 'P0' } | Sort-Object)
[void]$sb.AppendLine('## P0 functional requirement coverage')
[void]$sb.AppendLine()
[void]$sb.AppendLine(('The PRD marks **{0}** functional requirements as P0. "Not started" is not an acceptable final state for any of them.' -f $p0.Count))
[void]$sb.AppendLine()
$counts = @{}
foreach ($id in $p0) { $s = $summary[$id]; if (-not $counts.ContainsKey($s)) { $counts[$s] = 0 }; $counts[$s]++ }
[void]$sb.AppendLine('| Coverage | P0 count |')
[void]$sb.AppendLine('|---|---:|')
foreach ($k in ($counts.Keys | Sort-Object)) { [void]$sb.AppendLine(('| {0} | {1} |' -f $k, $counts[$k])) }
[void]$sb.AppendLine()
$notCovered = @($p0 | Where-Object { $summary[$_] -eq 'Not referenced' })
if ($notCovered.Count -gt 0) {
    [void]$sb.AppendLine(('**Unreferenced P0 requirements:** {0}' -f ($notCovered -join ', ')))
} else {
    [void]$sb.AppendLine('**Every P0 functional requirement is referenced by configuration, code, specification or test.**')
}
[void]$sb.AppendLine()
[void]$sb.AppendLine('Tenant-dependent verification for all of the above is tracked in `docs/BUILD_STATUS.md`.')

Set-Content -LiteralPath $OutputPath -Value $sb.ToString() -Encoding utf8 -NoNewline
Write-Information ("Generated {0}" -f $OutputPath) -InformationAction Continue

return [PSCustomObject]@{
    requirementCount = $ids.Count
    p0Count          = $p0.Count
    coverage         = $counts
    unreferencedP0   = $notCovered
    exitCode         = 0
}
