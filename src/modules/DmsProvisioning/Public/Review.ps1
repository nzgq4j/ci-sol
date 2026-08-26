Set-StrictMode -Version Latest

function Get-DmsBusinessDayOffset {
<#
.SYNOPSIS
    Adds a number of business days to a date.
.DESCRIPTION
    Used for approval due dates and escalation thresholds. The business calendar is a PRD open
    question (OQ-18); until confirmed, Monday to Friday is assumed and a holiday list may be
    supplied explicitly. The assumption is stated rather than hidden.
.PARAMETER StartDate
    Starting date.
.PARAMETER BusinessDays
    Number of business days to add. May be zero. Negative counts backwards.
.PARAMETER Holiday
    Optional dates treated as non-working.
.OUTPUTS
    System.DateTime
#>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory)][datetime]$StartDate,
        [Parameter(Mandatory)][int]$BusinessDays,
        [Parameter()][datetime[]]$Holiday = @()
    )
    $holidaySet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($h in $Holiday) { [void]$holidaySet.Add($h.Date.ToString('yyyy-MM-dd')) }

    $step = if ($BusinessDays -lt 0) { -1 } else { 1 }
    $remaining = [Math]::Abs($BusinessDays)
    $cursor = $StartDate.Date

    while ($remaining -gt 0) {
        $cursor = $cursor.AddDays($step)
        $isWeekend = $cursor.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)
        $isHoliday = $holidaySet.Contains($cursor.ToString('yyyy-MM-dd'))
        if (-not $isWeekend -and -not $isHoliday) { $remaining-- }
    }
    return $cursor
}

function Get-DmsNextReviewDate {
<#
.SYNOPSIS
    Calculates the next periodic-review date.
.DESCRIPTION
    Implements PRD F-015. The critical control is that a review date may only move forward when an
    attributable review decision exists: "the date cannot roll forward without a recorded decision".

    Therefore this function REFUSES to produce a rolled-forward date when Basis is
    'PeriodicReviewDecision' and no decision reference is supplied. That refusal is the control; it
    is not a validation nicety.
.PARAMETER FromDate
    The anchor date. For a first calculation this is the effective date; for a renewal it is the
    date of the recorded review decision.
.PARAMETER FrequencyMonths
    Approved review interval in months.
.PARAMETER Basis
    InitialActivation for the first calculation after activation, or PeriodicReviewDecision for a
    renewal following a Continue Valid decision.
.PARAMETER DecisionReference
    Identifier of the recorded review decision. Mandatory in practice for PeriodicReviewDecision.
.EXAMPLE
    Get-DmsNextReviewDate -FromDate '2026-01-15' -FrequencyMonths 12 -Basis InitialActivation
.OUTPUTS
    PSCustomObject with NextReviewDate, IsPermitted and Reason.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][datetime]$FromDate,
        [Parameter(Mandatory)][ValidateRange(1,120)][int]$FrequencyMonths,
        [Parameter(Mandatory)][ValidateSet('InitialActivation','PeriodicReviewDecision')][string]$Basis,
        [Parameter()][AllowEmptyString()][string]$DecisionReference = ''
    )

    if ($Basis -eq 'PeriodicReviewDecision' -and [string]::IsNullOrWhiteSpace($DecisionReference)) {
        return [PSCustomObject]@{
            NextReviewDate = $null
            IsPermitted    = $false
            Basis          = $Basis
            Reason         = "The next review date cannot roll forward without an attributable review decision. PRD F-015 forbids silent roll-forward."
            Requirements   = @('F-015')
        }
    }

    return [PSCustomObject]@{
        NextReviewDate = $FromDate.Date.AddMonths($FrequencyMonths)
        IsPermitted    = $true
        Basis          = $Basis
        Reason         = "Calculated as $FrequencyMonths month(s) from $($FromDate.ToString('yyyy-MM-dd'))."
        Requirements   = @('F-015')
    }
}

function Get-DmsReviewReminderSchedule {
<#
.SYNOPSIS
    Produces the reminder and escalation schedule for a review due date.
.DESCRIPTION
    Implements PRD F-015: notify owners before the due date at approved intervals and escalate
    non-response. Reminder offsets and the escalation threshold come from the Review Frequencies
    configuration so they can be changed without editing flow logic (PRD F-028).
.PARAMETER NextReviewDate
    The due date.
.PARAMETER ReminderOffsetsDays
    Days before due at which to remind, e.g. 90, 30, 7.
.PARAMETER EscalateAfterDaysOverdue
    Days after due at which to escalate.
.OUTPUTS
    PSCustomObject[] of scheduled events.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][datetime]$NextReviewDate,
        [Parameter(Mandatory)][int[]]$ReminderOffsetsDays,
        [Parameter(Mandatory)][int]$EscalateAfterDaysOverdue
    )
    $events = [System.Collections.Generic.List[object]]::new()
    foreach ($offset in ($ReminderOffsetsDays | Sort-Object -Descending)) {
        $events.Add([PSCustomObject]@{
            Type      = 'Reminder'
            DueDate   = $NextReviewDate.Date
            FireDate  = $NextReviewDate.Date.AddDays(-1 * [Math]::Abs($offset))
            OffsetDays= $offset
            Recipient = 'DocumentOwner'
        }) | Out-Null
    }
    $events.Add([PSCustomObject]@{
        Type      = 'Escalation'
        DueDate   = $NextReviewDate.Date
        FireDate  = $NextReviewDate.Date.AddDays([Math]::Abs($EscalateAfterDaysOverdue))
        OffsetDays= -1 * [Math]::Abs($EscalateAfterDaysOverdue)
        Recipient = 'DocumentController'
    }) | Out-Null
    return $events.ToArray()
}
