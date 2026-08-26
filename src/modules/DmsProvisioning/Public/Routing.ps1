Set-StrictMode -Version Latest

function Resolve-DmsRoutingRule {
<#
.SYNOPSIS
    Resolves the review and approval route for a submitted revision.
.DESCRIPTION
    Implements PRD F-009. Routes are configuration, not flow logic, so ordinary route changes never
    require editing a flow (PRD F-028).

    Resolution is deliberately strict:
      * Each rule criterion is an exact value or the wildcard '*'.
      * Specificity is the count of non-wildcard criteria; the highest specificity wins.
      * A tie at the winning specificity is AMBIGUOUS. The function refuses to choose arbitrarily
        and returns Ambiguous so the caller raises a blocking MissingRoute exception.
      * No match returns NoMatch, which PRD F-009 requires to be a blocking exception.

    Separation of duties (PRD SEC-003): when SoleAuthor is supplied, that principal is removed from
    every stage. If removal empties a stage, the result becomes Blocked rather than silently
    proceeding with a smaller approval set.

    This function is pure and has no tenant dependency.
.PARAMETER DocumentType
    Document type value, e.g. 'SOP'.
.PARAMETER BusinessFunction
    Business function term name.
.PARAMETER Sensitivity
    Sensitivity classification value.
.PARAMETER Model
    Routing model from config/routing-rules.json.
.PARAMETER SoleAuthor
    Optional principal that must not appear as an assignee.
.EXAMPLE
    Resolve-DmsRoutingRule -DocumentType SOP -BusinessFunction Quality -Sensitivity Internal -Model $r
.OUTPUTS
    PSCustomObject with Status, RuleName, Specificity, Stages, Reason.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DocumentType,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$BusinessFunction,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Sensitivity,
        [Parameter(Mandatory)]$Model,
        [Parameter()][AllowEmptyString()][string]$SoleAuthor = ''
    )

    $criteria = @(
        @{ Name = 'documentType';     Value = $DocumentType },
        @{ Name = 'businessFunction'; Value = $BusinessFunction },
        @{ Name = 'sensitivity';      Value = $Sensitivity }
    )

    $matches = [System.Collections.Generic.List[object]]::new()
    foreach ($rule in @($Model.ruleSets | Where-Object { $_.active })) {
        $isMatch = $true
        $specificity = 0
        foreach ($c in $criteria) {
            $ruleValue = $rule.($c.Name)
            if ($ruleValue -eq '*') { continue }
            $specificity++
            if ($ruleValue -ne $c.Value) { $isMatch = $false; break }
        }
        if ($isMatch) {
            $matches.Add([PSCustomObject]@{ Rule = $rule; Specificity = $specificity }) | Out-Null
        }
    }

    if ($matches.Count -eq 0) {
        return [PSCustomObject]@{
            Status       = 'NoMatch'
            RuleName     = $null
            Specificity  = -1
            Stages       = @()
            IsBlocking   = $true
            ExceptionType= 'MissingRoute'
            Reason       = "No active routing rule matches documentType='$DocumentType', businessFunction='$BusinessFunction', sensitivity='$Sensitivity'. PRD F-009 requires a blocking exception rather than a default route."
            Requirements = @('F-009','F-022')
        }
    }

    $maxSpec = ($matches | Measure-Object -Property Specificity -Maximum).Maximum
    $winners = @($matches | Where-Object { $_.Specificity -eq $maxSpec })

    if ($winners.Count -gt 1) {
        return [PSCustomObject]@{
            Status       = 'Ambiguous'
            RuleName     = $null
            Specificity  = $maxSpec
            Stages       = @()
            IsBlocking   = $true
            ExceptionType= 'MissingRoute'
            Reason       = "Routing is ambiguous at specificity $maxSpec between: $((@($winners | ForEach-Object { $_.Rule.name })) -join ' | '). Document Control must add an explicit combined rule. The system does not guess an approval route."
            Requirements = @('F-009','F-022')
        }
    }

    $winner = $winners[0].Rule
    $stages = [System.Collections.Generic.List[object]]::new()
    foreach ($s in @($winner.stages | Sort-Object sequence)) {
        $assignees = @($s.assignees)
        if (-not [string]::IsNullOrWhiteSpace($SoleAuthor)) {
            $assignees = @($assignees | Where-Object { $_ -ne $SoleAuthor })
        }
        if ($assignees.Count -eq 0) {
            return [PSCustomObject]@{
                Status       = 'Blocked'
                RuleName     = $winner.name
                Specificity  = $maxSpec
                Stages       = @()
                IsBlocking   = $true
                ExceptionType= 'MissingRoute'
                Reason       = "Stage '$($s.name)' has no eligible assignee after removing the sole author '$SoleAuthor'. Separation of duties (PRD SEC-003) prevents self-approval; Document Control must assign an independent reviewer."
                Requirements = @('F-009','SEC-003')
            }
        }
        $stages.Add([PSCustomObject]@{
            Sequence        = $s.sequence
            Name            = $s.name
            Mode            = $s.mode
            Assignees       = $assignees
            Quorum          = $s.quorum
            DueBusinessDays = $s.dueBusinessDays
            EscalateTo      = (Get-DmsPropertyOrDefault -InputObject $s -Name 'escalateTo' -Default $null)
        }) | Out-Null
    }

    return [PSCustomObject]@{
        Status       = 'Matched'
        RuleName     = $winner.name
        Specificity  = $maxSpec
        Stages       = $stages.ToArray()
        IsBlocking   = $false
        ExceptionType= $null
        Reason       = "Matched rule '$($winner.name)' at specificity $maxSpec."
        Requirements = @('F-009')
    }
}
