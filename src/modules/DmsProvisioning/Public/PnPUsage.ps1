Set-StrictMode -Version Latest

function Test-DmsPnPCmdletUsage {
<#
.SYNOPSIS
    Verifies that every PnP cmdlet and parameter used in this repository actually exists.
.DESCRIPTION
    The coding standards forbid fabricating API or cmdlet support. Memory of a cmdlet signature is
    not evidence, so this function checks the repository's scripts against an index generated
    directly from the PnP.PowerShell source at a recorded commit
    (tests/fixtures/pnp-cmdlet-index.json).

    It catches two real failure classes:
      * a cmdlet that does not exist, or was renamed between versions
        (for example Get-PnPLabel does not exist; the retention cmdlets are Get-PnPRetentionLabel,
         Get-PnPFileRetentionLabel and Set-PnPFileRetentionLabel),
      * a parameter that does not exist on an otherwise valid cmdlet.

    Because the index is a committed artefact with provenance, this check runs offline and in CI
    without a tenant or an installed PnP module.
.PARAMETER Path
    Files or directories to scan. Defaults to the repository src folder.
.PARAMETER IndexPath
    Path to the generated cmdlet index.
.EXAMPLE
    Test-DmsPnPCmdletUsage -Verbose
.OUTPUTS
    PSCustomObject with IsValid and Finding detail.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()][string[]]$Path = @((Join-Path (Get-DmsRepositoryRoot) 'src')),
        [Parameter()][string]$IndexPath = (Join-Path (Get-DmsRepositoryRoot) 'tests/fixtures/pnp-cmdlet-index.json')
    )

    if (-not (Test-Path -LiteralPath $IndexPath)) {
        throw "PnP cmdlet index not found at $IndexPath. Regenerate it with tools described in docs/DEPLOYMENT_RUNBOOK.md."
    }
    $index = Read-DmsJsonFile -Path $IndexPath
    $known = @{}
    foreach ($p in $index.cmdlets.PSObject.Properties) { $known[$p.Name] = @($p.Value) }
    $commonParams = @($index.commonParameters) + @(
        'Verbose','Debug','ErrorAction','WarningAction','InformationAction','ErrorVariable',
        'WarningVariable','InformationVariable','OutVariable','OutBuffer','PipelineVariable','WhatIf','Confirm'
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $files = foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p -PathType Container) { Get-ChildItem -LiteralPath $p -Recurse -Include '*.ps1','*.psm1' -File }
        elseif (Test-Path -LiteralPath $p) { Get-Item -LiteralPath $p }
    }

    # The PowerShell parser is used rather than regular expressions. Regex over source text produces
    # false positives from cmdlet names that appear inside comments, help blocks and string literals,
    # and cannot reliably determine where one invocation ends. The AST gives exact command
    # invocations and their parameter names.
    $cmdletUsed = 0
    foreach ($file in $files) {
        $tokens = $null; $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors -and $parseErrors.Count -gt 0) {
            $findings.Add([PSCustomObject]@{
                File = $file.Name; Cmdlet = $null; Parameter = $null; Severity = 'High'
                Detail = "File does not parse: $($parseErrors[0].Message)"
            }) | Out-Null
            continue
        }

        $commands = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
        foreach ($cmd in $commands) {
            $name = $cmd.GetCommandName()
            if ([string]::IsNullOrEmpty($name) -or $name -notmatch '^[A-Za-z]+-PnP[A-Za-z0-9]+$') { continue }
            $cmdletUsed++

            if (-not $known.ContainsKey($name)) {
                $findings.Add([PSCustomObject]@{
                    File = $file.Name; Cmdlet = $name; Parameter = $null; Severity = 'High'
                    Detail = "Cmdlet '$name' does not exist in PnP.PowerShell at indexed commit $($index._provenance.commit.Substring(0,8)) ($($index._provenance.commitDate))."
                }) | Out-Null
                continue
            }

            foreach ($element in $cmd.CommandElements) {
                if ($element -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
                $param = $element.ParameterName
                if ($param -in $commonParams) { continue }
                # Accept unambiguous prefixes, which PowerShell itself resolves at runtime.
                $candidates = @($known[$name] | Where-Object { $_ -eq $param -or $_ -like "$param*" })
                if ($candidates.Count -eq 0) {
                    $findings.Add([PSCustomObject]@{
                        File = $file.Name; Cmdlet = $name; Parameter = $param; Severity = 'High'
                        Detail = "Parameter -$param does not exist on $name. Valid: $((@($known[$name]) | Sort-Object) -join ', ')"
                    }) | Out-Null
                }
            }
        }
    }

    return [PSCustomObject]@{
        IsValid       = ($findings.Count -eq 0)
        CmdletUsages  = $cmdletUsed
        FindingCount  = $findings.Count
        Findings      = $findings.ToArray()
        IndexCommit   = $index._provenance.commit
        IndexDate     = $index._provenance.commitDate
        Requirements  = @('ADM-006','ADM-007')
    }
}

function Get-DmsRequiredApiPermission {
<#
.SYNOPSIS
    Returns the API permissions the DMS automation identity requires, with justification.
.DESCRIPTION
    PRD SEC-004 and the coding standards require every API permission to be documented together with
    why it is needed, and to be the least permission that works. This function is the single source
    of truth consumed by docs/SECURITY_MODEL.md and by the administrator consent runbook.
.PARAMETER Scenario
    Provisioning for deployment automation, or Runtime for the lifecycle flows.
.OUTPUTS
    PSCustomObject[] permission records.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()][ValidateSet('Provisioning','Runtime','All')][string]$Scenario = 'All'
    )

    $all = @(
        [PSCustomObject]@{ Scenario='Provisioning'; Api='SharePoint'; Permission='Sites.FullControl.All'; Type='Application'; Justification='Create and configure site columns, content types, libraries, lists, views and permission levels. Required because library moderation, draft visibility and permission-level creation are not available at a narrower scope.'; LeastPrivilegeNote='Scoped to the DMS site collection using Sites.Selected where the tenant supports it; FullControl.All is only used for initial site creation and Content Type Hub publishing.'; Requirements=@('ADM-006','SEC-004') }
        [PSCustomObject]@{ Scenario='Provisioning'; Api='SharePoint'; Permission='Sites.Selected';        Type='Application'; Justification='Preferred steady-state permission once the DMS sites exist, so automation cannot reach unrelated sites.'; LeastPrivilegeNote='Granted per site collection. This is the target state after initial provisioning.'; Requirements=@('SEC-002','SEC-004') }
        [PSCustomObject]@{ Scenario='Provisioning'; Api='Microsoft Graph'; Permission='Group.Read.All';    Type='Application'; Justification='Read Entra groups and owners to validate the role-permission matrix and detect ownerless groups.'; LeastPrivilegeNote='Read-only. Group creation is a separate, human-approved step.'; Requirements=@('F-024','SEC-002') }
        [PSCustomObject]@{ Scenario='Provisioning'; Api='Microsoft Graph'; Permission='Directory.Read.All';Type='Application'; Justification='Resolve document owners and approvers to active identities and detect departed owners.'; LeastPrivilegeNote='Read-only.'; Requirements=@('F-015','MET-005') }
        [PSCustomObject]@{ Scenario='Runtime'; Api='SharePoint'; Permission='Sites.Selected (Write)';      Type='Application'; Justification='Publish approved major versions, set lifecycle metadata and write register entries during activation.'; LeastPrivilegeNote='Restricted to the DMS site collections only.'; Requirements=@('F-012','F-013') }
        [PSCustomObject]@{ Scenario='Runtime'; Api='Microsoft Graph'; Permission='Mail.Send';              Type='Application'; Justification='Send link-based publication and review notifications from a service mailbox.'; LeastPrivilegeNote='Constrained to a single sender mailbox using an Exchange application access policy, so it cannot send as arbitrary users.'; Requirements=@('F-017','INT-005') }
        [PSCustomObject]@{ Scenario='Runtime'; Api='Microsoft Graph'; Permission='User.Read.All';          Type='Application'; Justification='Detect disabled or departed document owners and approvers.'; LeastPrivilegeNote='Read-only.'; Requirements=@('F-015','INT-001') }
    )

    if ($Scenario -eq 'All') { return $all }
    return @($all | Where-Object Scenario -eq $Scenario)
}
