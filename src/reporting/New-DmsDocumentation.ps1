#Requires -Version 7.2
<#
.SYNOPSIS
    Generates the data dictionary and state model from configuration.
.DESCRIPTION
    These two documents are derived, not hand-maintained. Configuration is the single source of
    truth, so a schema change cannot leave documentation silently stale (PRD ADM-009).

    CI regenerates them and fails if the working tree differs, which makes drift a build failure
    rather than a discovery made months later during an audit.
.PARAMETER ConfigPath
    Configuration directory.
.PARAMETER OutputPath
    Documentation directory.
.PARAMETER Check
    Generate to memory and compare with what is on disk. Exit 1 on difference. Used by CI.
.EXAMPLE
    ./New-DmsDocumentation.ps1
.EXAMPLE
    ./New-DmsDocumentation.ps1 -Check
.OUTPUTS
    PSCustomObject with the generated file list.
#>
[CmdletBinding()]
param(
    [Parameter()][string]$ConfigPath,
    [Parameter()][string]$OutputPath,
    [Parameter()][switch]$Check
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '..' '..' 'config' }
if (-not $OutputPath) { $OutputPath = Join-Path $PSScriptRoot '..' '..' 'docs' }
$config = Get-DmsConfiguration -ConfigPath $ConfigPath -Environment dev

function Format-Cell { param([AllowNull()]$v)
    if ($null -eq $v) { return '' }
    if ($v -is [array]) { return (($v | ForEach-Object { "$_" }) -join ', ') }
    return ("$v" -replace '\|', '\|' -replace '\r?\n', ' ')
}

# ------------------------------------------------------------------ DATA_DICTIONARY.md
$dd = [System.Text.StringBuilder]::new()
[void]$dd.AppendLine('# Data Dictionary')
[void]$dd.AppendLine()
[void]$dd.AppendLine('> **Generated file.** Produced by `src/reporting/New-DmsDocumentation.ps1` from `config/site-columns.json`, `config/content-types.json` and `config/lists.json`. Do not edit by hand; edit the configuration and regenerate.')
[void]$dd.AppendLine()
[void]$dd.AppendLine('Implements PRD section 17 (Data Requirements). Internal names are stable contracts referenced by views, flows, search mappings, reports and provisioning scripts, and must not be renamed after first deployment.')
[void]$dd.AppendLine()

[void]$dd.AppendLine('## Site columns')
[void]$dd.AppendLine()
[void]$dd.AppendLine('| Internal name | Display name | Type | Required | Indexed | Data owner | Sensitivity | Set by | Editable in states | PRD |')
[void]$dd.AppendLine('|---|---|---|---|:--:|---|---|---|---|---|')
foreach ($c in $config.SiteColumns.columns) {
    $lm = $c.lifecycleMutability
    $editable = if (@($lm.editableInStates).Count -eq 0) { '_none — system only_' } else { (Format-Cell $lm.editableInStates) }
    [void]$dd.AppendLine(('| `{0}` | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} |' -f `
        $c.internalName, (Format-Cell $c.displayName), $c.type,
        $(if ($c.required) { 'Yes' } else { 'No' }),
        $(if ((Get-DmsPropertyOrDefault -InputObject $c -Name 'indexed' -Default $false)) { 'Yes' } else { '' }),
        (Format-Cell $c.dataOwner), (Format-Cell (Get-DmsPropertyOrDefault -InputObject $c -Name 'sensitivity' -Default '')),
        $lm.setBy, $editable, (Format-Cell $c.requirements)))
}
[void]$dd.AppendLine()

[void]$dd.AppendLine('## Validation rules')
[void]$dd.AppendLine()
[void]$dd.AppendLine('| Internal name | Rule |')
[void]$dd.AppendLine('|---|---|')
foreach ($c in $config.SiteColumns.columns) {
    [void]$dd.AppendLine(('| `{0}` | {1} |' -f $c.internalName, (Format-Cell $c.validation.rule)))
}
[void]$dd.AppendLine()

[void]$dd.AppendLine('## Content types')
[void]$dd.AppendLine()
[void]$dd.AppendLine('| Name | Content type ID | Parent | Abstract | Required fields |')
[void]$dd.AppendLine('|---|---|---|:--:|---|')
foreach ($ct in $config.ContentTypes.contentTypes) {
    [void]$dd.AppendLine(('| {0} | `{1}` | `{2}` | {3} | {4} |' -f `
        $ct.name, $ct.id, $ct.parentId,
        $(if ($ct.abstract) { 'Yes' } else { 'No' }),
        (Format-Cell (Get-DmsPropertyOrDefault -InputObject $ct -Name 'requiredFields' -Default @()))))
}
[void]$dd.AppendLine()

[void]$dd.AppendLine('## Registers (lists)')
[void]$dd.AppendLine()
foreach ($l in $config.Lists.lists) {
    [void]$dd.AppendLine(('### {0}' -f $l.title))
    [void]$dd.AppendLine()
    [void]$dd.AppendLine((Format-Cell $l.description))
    [void]$dd.AppendLine()
    [void]$dd.AppendLine(('MVP treatment: {0}. PRD: {1}.' -f (Format-Cell $l.mvp), (Format-Cell $l.requirements)))
    [void]$dd.AppendLine()
    [void]$dd.AppendLine('| Field | Display name | Type | Required |')
    [void]$dd.AppendLine('|---|---|---|:--:|')
    foreach ($f in $l.fields) {
        $t = if ((Get-DmsPropertyOrDefault -InputObject $f -Name 'reuseSiteColumn' -Default $false)) { '_site column_' } else { (Get-DmsPropertyOrDefault -InputObject $f -Name 'type' -Default '') }
        [void]$dd.AppendLine(('| `{0}` | {1} | {2} | {3} |' -f $f.internalName,
            (Format-Cell (Get-DmsPropertyOrDefault -InputObject $f -Name 'displayName' -Default '')), $t,
            $(if ((Get-DmsPropertyOrDefault -InputObject $f -Name 'required' -Default $false)) { 'Yes' } else { '' })))
    }
    [void]$dd.AppendLine()
}

# ------------------------------------------------------------------ STATE_MODEL.md
$lc = $config.Lifecycle
$sm = [System.Text.StringBuilder]::new()
[void]$sm.AppendLine('# Lifecycle State Model')
[void]$sm.AppendLine()
[void]$sm.AppendLine('> **Generated file.** Produced by `src/reporting/New-DmsDocumentation.ps1` from `config/lifecycle-states.json`. Do not edit by hand.')
[void]$sm.AppendLine()
[void]$sm.AppendLine((Format-Cell $lc.description))
[void]$sm.AppendLine()
[void]$sm.AppendLine('## Business lifecycle versus platform approval status')
[void]$sm.AppendLine()
[void]$sm.AppendLine(('Business state lives in `{0}`. The native SharePoint Approval Status ({1}) is a separate platform state.' -f $lc.fieldInternalName, ((Format-Cell $lc.platformApprovalStatus.values))))
[void]$sm.AppendLine()
[void]$sm.AppendLine(('**Rule:** {0}' -f (Format-Cell $lc.platformApprovalStatus.rule)))
[void]$sm.AppendLine()

[void]$sm.AppendLine('## State diagram')
[void]$sm.AppendLine()
[void]$sm.AppendLine('```mermaid')
[void]$sm.AppendLine('stateDiagram-v2')
[void]$sm.AppendLine('    [*] --> Requested')
foreach ($t in $lc.transitions) {
    [void]$sm.AppendLine(('    {0} --> {1}: {2}' -f $t.from, $t.to, $t.id))
}
[void]$sm.AppendLine('    Obsolete --> [*]')
[void]$sm.AppendLine('```')
[void]$sm.AppendLine()

[void]$sm.AppendLine('## States')
[void]$sm.AppendLine()
[void]$sm.AppendLine('| State | Display name | Current effective | Visible to readers | Terminal | Description | PRD |')
[void]$sm.AppendLine('|---|---|:--:|:--:|:--:|---|---|')
foreach ($s in ($lc.states | Sort-Object order)) {
    [void]$sm.AppendLine(('| `{0}` | {1} | {2} | {3} | {4} | {5} | {6} |' -f $s.key, $s.displayName,
        $(if ($s.currentEffective) { 'Yes' } else { '' }), $(if ($s.readerVisible) { 'Yes' } else { '' }),
        $(if ($s.isTerminal) { 'Yes' } else { '' }), (Format-Cell $s.description), (Format-Cell $s.requirements)))
}
[void]$sm.AppendLine()

[void]$sm.AppendLine('## Transitions')
[void]$sm.AppendLine()
[void]$sm.AppendLine('| ID | From | To | Trigger | Authorised actors | Preconditions | System effects | Evidence created | Idempotency key | PRD |')
[void]$sm.AppendLine('|---|---|---|---|---|---|---|---|---|---|')
foreach ($t in $lc.transitions) {
    [void]$sm.AppendLine(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | `{8}` | {9} |' -f `
        $t.id, $t.from, $t.to, $t.trigger, (Format-Cell $t.allowedActors), (Format-Cell $t.preconditions),
        (Format-Cell $t.systemEffects), (Format-Cell $t.evidenceCreated), $t.idempotencyKey, (Format-Cell $t.requirements)))
}
[void]$sm.AppendLine()

[void]$sm.AppendLine('## Events that do not change state')
[void]$sm.AppendLine()
[void]$sm.AppendLine('| ID | State | Trigger | Actors | Effects | Rule |')
[void]$sm.AppendLine('|---|---|---|---|---|---|')
foreach ($e in $lc.nonTransitionEvents) {
    [void]$sm.AppendLine(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f $e.id, $e.state, $e.trigger,
        (Format-Cell $e.allowedActors), (Format-Cell $e.systemEffects), (Format-Cell $e.rule)))
}
[void]$sm.AppendLine()

[void]$sm.AppendLine('## Invalid transition behaviour')
[void]$sm.AppendLine()
[void]$sm.AppendLine((Format-Cell $lc.invalidTransitionBehaviour.description))
[void]$sm.AppendLine()
[void]$sm.AppendLine('| From | To | Why it is refused |')
[void]$sm.AppendLine('|---|---|---|')
foreach ($x in $lc.invalidTransitionBehaviour.examples) {
    [void]$sm.AppendLine(('| {0} | {1} | {2} |' -f $x.from, $x.to, (Format-Cell $x.reason)))
}
[void]$sm.AppendLine()

[void]$sm.AppendLine('## Recovery behaviour')
[void]$sm.AppendLine()
[void]$sm.AppendLine((Format-Cell $lc.recoveryBehaviour.principle))
[void]$sm.AppendLine()
[void]$sm.AppendLine('| Condition | Action |')
[void]$sm.AppendLine('|---|---|')
foreach ($r in $lc.recoveryBehaviour.rules) {
    [void]$sm.AppendLine(('| {0} | {1} |' -f (Format-Cell $r.condition), (Format-Cell $r.action)))
}

# ------------------------------------------------------------------ write or check
$targets = @(
    @{ Path = (Join-Path $OutputPath 'DATA_DICTIONARY.md'); Content = $dd.ToString() }
    @{ Path = (Join-Path $OutputPath 'STATE_MODEL.md');     Content = $sm.ToString() }
)

$drift = @()
foreach ($t in $targets) {
    if ($Check) {
        $existing = if (Test-Path -LiteralPath $t.Path) { Get-Content -LiteralPath $t.Path -Raw -Encoding utf8 } else { '' }
        if ($existing.Replace("`r`n","`n") -ne $t.Content.Replace("`r`n","`n")) { $drift += $t.Path }
    } else {
        Set-Content -LiteralPath $t.Path -Value $t.Content -Encoding utf8 -NoNewline
        Write-Information ("Generated {0}" -f $t.Path) -InformationAction Continue
    }
}

if ($Check -and $drift.Count -gt 0) {
    Write-Error ("Generated documentation is out of date: {0}. Run src/reporting/New-DmsDocumentation.ps1 and commit the result." -f ($drift -join ', '))
    exit 1
}
return [PSCustomObject]@{ generated = @($targets | ForEach-Object { $_.Path }); driftCount = $drift.Count; exitCode = 0 }
