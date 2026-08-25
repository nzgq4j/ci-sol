Set-StrictMode -Version Latest

function New-DmsCorrelationId {
<#
.SYNOPSIS
    Generates a correlation ID.
.DESCRIPTION
    Correlation IDs join a document, its approval evidence, its notifications and any exception
    raised while processing it (PRD F-010, F-022, UX-007). Format is a lowercase GUID with no braces.
.OUTPUTS
    System.String
#>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    return [guid]::NewGuid().ToString('D').ToLowerInvariant()
}

function Get-DmsLifecycleTransition {
<#
.SYNOPSIS
    Returns the declared transition between two lifecycle states, if one exists.
.PARAMETER From
    Source state key.
.PARAMETER To
    Target state key.
.PARAMETER Model
    Lifecycle model object from config/lifecycle-states.json.
.OUTPUTS
    The transition object, or $null when no transition is declared.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$From,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$To,
        [Parameter(Mandatory)]$Model
    )
    return ($Model.transitions | Where-Object { $_.from -eq $From -and $_.to -eq $To } | Select-Object -First 1)
}

function Test-DmsLifecycleTransition {
<#
.SYNOPSIS
    Evaluates whether a lifecycle state change is permitted.
.DESCRIPTION
    Implements PRD F-005. A transition is permitted only when it is declared in the model AND the
    requesting actor is listed among its authorised actors. Anything else is rejected.

    The function never coerces an invalid request into the nearest valid state; PRD
    invalidTransitionBehaviour.mustNotSilentlyCoerce forbids that. A rejected transition returns a
    structured result that the caller writes to the Exception Register.

    This function is pure. It performs no tenant access and is fully unit testable offline.
.PARAMETER From
    Current lifecycle state.
.PARAMETER To
    Requested lifecycle state.
.PARAMETER Actor
    Role key of the principal requesting the change, e.g. Approver, SystemAutomation.
.PARAMETER Model
    Lifecycle model from config/lifecycle-states.json.
.PARAMETER SatisfiedPreconditions
    Precondition keys the caller has already verified. When supplied, unmet preconditions are
    reported and the transition is not permitted.
.EXAMPLE
    Test-DmsLifecycleTransition -From Authoring -To InReview -Actor Author -Model $m
.OUTPUTS
    PSCustomObject with IsPermitted, TransitionId, Reason, UnmetPreconditions, Requirements.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$From,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$To,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Actor,
        [Parameter(Mandatory)]$Model,
        [Parameter()][string[]]$SatisfiedPreconditions = $null
    )

    $result = [ordered]@{
        From                 = $From
        To                   = $To
        Actor                = $Actor
        IsPermitted          = $false
        TransitionId         = $null
        Reason               = $null
        UnmetPreconditions   = @()
        Requirements         = @()
        ExceptionSeverity    = $null
    }

    $stateKeys = @($Model.states | ForEach-Object { $_.key })
    if ($From -notin $stateKeys) {
        $result.Reason = "Unknown source state '$From'."
        $result.ExceptionSeverity = 'High'
        return [PSCustomObject]$result
    }
    if ($To -notin $stateKeys) {
        $result.Reason = "Unknown target state '$To'."
        $result.ExceptionSeverity = 'High'
        return [PSCustomObject]$result
    }

    $sourceState = $Model.states | Where-Object key -eq $From | Select-Object -First 1
    if ($sourceState.isTerminal) {
        $result.Reason = "State '$From' is terminal; no transition out of it is permitted."
        $result.ExceptionSeverity = 'High'
        return [PSCustomObject]$result
    }

    $transition = Get-DmsLifecycleTransition -From $From -To $To -Model $Model
    if ($null -eq $transition) {
        # Surface the documented rationale when this is a known-invalid example.
        $known = $Model.invalidTransitionBehaviour.examples |
                 Where-Object { $_.from -eq $From -and $_.to -eq $To } | Select-Object -First 1
        $result.Reason = if ($known) { $known.reason } else { "No transition from '$From' to '$To' is declared in the lifecycle model." }
        # A rejected attempt to reach Effective is more serious than any other invalid transition.
        $result.ExceptionSeverity = if ($To -eq 'Effective') { 'High' } else { 'Medium' }
        return [PSCustomObject]$result
    }

    $result.TransitionId = $transition.id
    $result.Requirements = @($transition.requirements)

    if ($Actor -notin @($transition.allowedActors)) {
        $result.Reason = "Actor '$Actor' is not authorised for transition $($transition.id) ($From -> $To). Authorised: $((@($transition.allowedActors)) -join ', ')."
        $result.ExceptionSeverity = if ($To -eq 'Effective') { 'High' } else { 'Medium' }
        return [PSCustomObject]$result
    }

    if ($null -ne $SatisfiedPreconditions) {
        $required = @($transition.preconditions)
        $unmet = @($required | Where-Object { $_ -notin $SatisfiedPreconditions })
        if ($unmet.Count -gt 0) {
            $result.UnmetPreconditions = $unmet
            $result.Reason = "Transition $($transition.id) has unmet preconditions: $($unmet -join ', ')."
            $result.ExceptionSeverity = 'Medium'
            return [PSCustomObject]$result
        }
    }

    $result.IsPermitted = $true
    $result.Reason = "Transition $($transition.id) permitted for actor '$Actor'."
    return [PSCustomObject]$result
}

function Test-DmsEffectiveRevisionUniqueness {
<#
.SYNOPSIS
    Verifies the single-current-effective-revision invariant.
.DESCRIPTION
    Implements PRD F-013: each controlled document must have no more than one current effective
    revision within an applicability context. This is the invariant whose breach produces the
    PRD MET-014 "wrong revision presented as current" incident, so it is checked both after
    activation and on a schedule.

    Uniqueness is evaluated per Document ID AND applicability context, because the same document may
    legitimately have different effective revisions for different applicability contexts where the
    taxonomy allows it.
.PARAMETER Revision
    Collection of revision objects. Each must expose DocumentId, Applicability, CurrentEffective and
    optionally BusinessRevision.
.PARAMETER ExpectCurrentFor
    Optional list of Document IDs that MUST have exactly one current revision. Supplying this also
    detects the "zero effective revisions" condition, which PRD recoveryBehaviour treats as a High
    blocking exception.
.EXAMPLE
    Test-DmsEffectiveRevisionUniqueness -Revision $items -ExpectCurrentFor @('QMS-SOP-0042')
.OUTPUTS
    PSCustomObject with IsValid and Violation records.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Revision,
        [Parameter()][string[]]$ExpectCurrentFor = @()
    )

    $violations = [System.Collections.Generic.List[object]]::new()

    $groups = $Revision | Group-Object -Property {
        $app = if (Test-DmsProperty -InputObject $_ -Name 'Applicability') { $_.Applicability } else { '' }
        if ($app -is [array]) { $app = ($app | Sort-Object) -join '|' }
        '{0}::{1}' -f $_.DocumentId, $app
    }

    foreach ($g in $groups) {
        $current = @($g.Group | Where-Object { [bool]$_.CurrentEffective })
        if ($current.Count -gt 1) {
            $violations.Add([PSCustomObject]@{
                Context      = $g.Name
                DocumentId   = $g.Group[0].DocumentId
                Type         = 'DuplicateCurrentRevision'
                Severity     = 'High'
                IsBlocking   = $true
                Count        = $current.Count
                Revisions    = @($current | ForEach-Object { Get-DmsPropertyOrDefault -InputObject $_ -Name 'BusinessRevision' -Default '(unknown)' })
                Detail       = "More than one revision is flagged current effective. PRD F-013."
            }) | Out-Null
        }
    }

    foreach ($docId in $ExpectCurrentFor) {
        $docRevisions = @($Revision | Where-Object { $_.DocumentId -eq $docId })
        $current = @($docRevisions | Where-Object { [bool]$_.CurrentEffective })
        if ($current.Count -eq 0) {
            $violations.Add([PSCustomObject]@{
                Context      = $docId
                DocumentId   = $docId
                Type         = 'MissingCurrentRevision'
                Severity     = 'High'
                IsBlocking   = $true
                Count        = 0
                Revisions    = @()
                Detail       = "The register expects a current effective revision but none exists. PRD F-013 recovery behaviour."
            }) | Out-Null
        }
    }

    return [PSCustomObject]@{
        IsValid        = ($violations.Count -eq 0)
        ViolationCount = $violations.Count
        Violations     = $violations.ToArray()
    }
}
