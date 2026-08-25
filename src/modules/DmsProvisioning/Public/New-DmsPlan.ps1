Set-StrictMode -Version Latest

function New-DmsPlan {
<#
.SYNOPSIS
    Creates an empty deployment plan.
.DESCRIPTION
    The plan is the separation between deciding what to change and actually changing it, which the
    PRD coding standards require. Plan mode builds and prints a plan; Apply mode executes the same
    plan. Nothing mutates a tenant during plan construction.
.PARAMETER Environment
    Target environment key.
.PARAMETER Mode
    Plan or Apply.
.EXAMPLE
    $plan = New-DmsPlan -Environment dev -Mode Plan
.OUTPUTS
    PSCustomObject plan container.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][ValidateSet('dev','test','prod')][string]$Environment,
        [Parameter(Mandatory)][ValidateSet('Plan','Apply')][string]$Mode
    )
    return [PSCustomObject]@{
        environment   = $Environment
        mode          = $Mode
        correlationId = (New-DmsCorrelationId)
        createdUtc    = (Get-Date).ToUniversalTime().ToString('o')
        actions       = [System.Collections.Generic.List[object]]::new()
    }
}

function Add-DmsPlanAction {
<#
.SYNOPSIS
    Adds an action to a deployment plan.
.DESCRIPTION
    Actions classify what the deployment intends to do with one resource. The Change classification
    drives Apply behaviour:
      Create    - resource is absent and will be created.
      Update    - resource exists and differs in a SAFE, mutable way.
      Compliant - resource exists and already matches; Apply skips it (idempotency, PRD NFR-006).
      Blocked   - resource differs in a way that cannot be changed safely, or a precondition failed.
                  Apply reports it and does NOT attempt the change.
.PARAMETER Plan
    Plan created by New-DmsPlan.
.PARAMETER ResourceType
    e.g. SiteColumn, ContentType, Library, List, View, PermissionLevel, RetentionLabel.
.PARAMETER Target
    Resource identity.
.PARAMETER Change
    Classification.
.PARAMETER Reason
    Why this classification was chosen. Shown in plan output.
.PARAMETER Requirements
    PRD requirement IDs this action implements, for traceability.
.PARAMETER ApplyScript
    Scriptblock executed only in Apply mode for Create and Update actions.
.PARAMETER Detail
    Optional structured difference detail for drift reporting.
.OUTPUTS
    PSCustomObject action record.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Plan,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ResourceType,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Target,
        [Parameter(Mandatory)][ValidateSet('Create','Update','Compliant','Blocked')][string]$Change,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Reason,
        [Parameter()][string[]]$Requirements = @(),
        [Parameter()][scriptblock]$ApplyScript = $null,
        [Parameter()]$Detail = $null
    )
    $action = [PSCustomObject]@{
        resourceType = $ResourceType
        target       = $Target
        change       = $Change
        reason       = $Reason
        requirements = $Requirements
        detail       = $Detail
        applyScript  = $ApplyScript
        executed     = $false
        outcome      = $null
    }
    $Plan.actions.Add($action) | Out-Null
    return $action
}

function Format-DmsPlan {
<#
.SYNOPSIS
    Renders a deployment plan as human-readable text plus a machine-readable summary.
.DESCRIPTION
    Plan mode must show intended changes without applying them. This renders the plan and returns a
    summary object whose counts drive the exit code of the deployment scripts.
.PARAMETER Plan
    Plan to render.
.PARAMETER AsJson
    Emit JSON instead of text.
.OUTPUTS
    PSCustomObject summary with counts.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Plan,
        [Parameter()][switch]$AsJson
    )
    $counts = [ordered]@{
        Create    = @($Plan.actions | Where-Object change -eq 'Create').Count
        Update    = @($Plan.actions | Where-Object change -eq 'Update').Count
        Compliant = @($Plan.actions | Where-Object change -eq 'Compliant').Count
        Blocked   = @($Plan.actions | Where-Object change -eq 'Blocked').Count
    }

    if ($AsJson) {
        $Plan.actions |
            Select-Object resourceType, target, change, reason, requirements |
            ConvertTo-Json -Depth 6
    } else {
        Write-Information ('' ) -InformationAction Continue
        Write-Information ("DMS deployment plan  environment={0}  mode={1}  correlation={2}" -f $Plan.environment, $Plan.mode, $Plan.correlationId) -InformationAction Continue
        Write-Information ('-' * 110) -InformationAction Continue
        foreach ($a in $Plan.actions) {
            $marker = switch ($a.change) {
                'Create'    { '+' }
                'Update'    { '~' }
                'Compliant' { '=' }
                'Blocked'   { '!' }
            }
            Write-Information ("{0} {1,-16} {2,-46} {3}" -f $marker, $a.resourceType, $a.target, $a.reason) -InformationAction Continue
        }
        Write-Information ('-' * 110) -InformationAction Continue
        Write-Information ("create={0}  update={1}  compliant={2}  blocked={3}" -f $counts.Create, $counts.Update, $counts.Compliant, $counts.Blocked) -InformationAction Continue
    }

    return [PSCustomObject]@{
        environment  = $Plan.environment
        mode         = $Plan.mode
        correlationId= $Plan.correlationId
        createCount  = $counts.Create
        updateCount  = $counts.Update
        compliantCount = $counts.Compliant
        blockedCount = $counts.Blocked
        totalCount   = $Plan.actions.Count
        hasBlocking  = ($counts.Blocked -gt 0)
        isDrifted    = (($counts.Create + $counts.Update) -gt 0)
    }
}
