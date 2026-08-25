Set-StrictMode -Version Latest

function Test-DmsProductionGuard {
<#
.SYNOPSIS
    Evaluates whether a deployment is permitted to change the target environment.
.DESCRIPTION
    Implements the production-protection controls. A production Apply is permitted only when EVERY
    condition holds:
      * the operator explicitly authorised production deployment,
      * the environment's allowProductionChanges flag is true,
      * tenant and site URLs are confirmed (no discovery placeholders remain),
      * a successful development or test deployment record exists,
      * pre-deployment validation passed,
      * a rollback plan is documented,
      * the proposed change has been displayed for review.

    The default is deny. The function returns every failed condition rather than the first, so an
    operator sees the complete gap in one pass.

    Non-production Apply is permitted without these gates, but placeholder values are still refused
    because they would silently target the wrong tenant.
.PARAMETER Environment
    Environment key.
.PARAMETER EnvironmentConfig
    The environment node from config/environments.json.
.PARAMETER TenantConfig
    The tenant node from config/environments.json.
.PARAMETER Mode
    Plan or Apply.
.PARAMETER ProductionChangeAuthorised
    Set when the operator explicitly authorised a production change for this run.
.PARAMETER PriorSuccessfulDeploymentEnvironment
    Environment names with a recorded successful deployment.
.PARAMETER PreDeploymentTestsPassed
    Whether validation passed.
.PARAMETER RollbackPlanReference
    Reference to the documented rollback plan.
.PARAMETER ChangeDisplayed
    Whether the plan was rendered for the operator before applying.
.OUTPUTS
    PSCustomObject with IsPermitted and Blocker detail.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][ValidateSet('dev','test','prod')][string]$Environment,
        [Parameter(Mandatory)]$EnvironmentConfig,
        [Parameter(Mandatory)]$TenantConfig,
        [Parameter(Mandatory)][ValidateSet('Plan','Apply')][string]$Mode,
        [Parameter()][switch]$ProductionChangeAuthorised,
        [Parameter()][string[]]$PriorSuccessfulDeploymentEnvironment = @(),
        [Parameter()][bool]$PreDeploymentTestsPassed = $false,
        [Parameter()][AllowEmptyString()][string]$RollbackPlanReference = '',
        [Parameter()][bool]$ChangeDisplayed = $false
    )

    $blockers = [System.Collections.Generic.List[string]]::new()

    # Placeholders must never be applied against a live tenant, in any environment.
    $placeholders = @()
    foreach ($n in @('tenantName','tenantId','sharePointAdminUrl','contentTypeHubUrl')) {
        $v = Get-DmsPropertyOrDefault -InputObject $TenantConfig -Name $n -Default ''
        if ("$v" -like '*REQUIRES_*') { $placeholders += "tenant.$n" }
    }
    $siteUrl = Get-DmsPropertyOrDefault -InputObject $EnvironmentConfig -Name 'dmsSiteUrl' -Default ''
    if ("$siteUrl" -like '*REQUIRES_*') { $placeholders += "environments.$Environment.dmsSiteUrl" }

    if ($Mode -eq 'Apply' -and $placeholders.Count -gt 0) {
        $blockers.Add("Unresolved configuration placeholders would target an unknown tenant: $($placeholders -join ', '). Complete discovery and update config/environments.json.") | Out-Null
    }

    if ($Environment -eq 'prod' -and $Mode -eq 'Apply') {
        if (-not $ProductionChangeAuthorised) {
            $blockers.Add('Production deployment was not explicitly authorised for this run. Re-run with -ConfirmProductionChange.') | Out-Null
        }
        $allow = [bool](Get-DmsPropertyOrDefault -InputObject $EnvironmentConfig -Name 'allowProductionChanges' -Default $false)
        if (-not $allow) {
            $blockers.Add('environments.prod.allowProductionChanges is false. It defaults to false and must be set deliberately.') | Out-Null
        }
        if (-not (@('dev','test') | Where-Object { $_ -in $PriorSuccessfulDeploymentEnvironment })) {
            $blockers.Add('No successful development or test deployment is recorded. Production must never be the first environment to receive a change.') | Out-Null
        }
        if (-not $PreDeploymentTestsPassed) {
            $blockers.Add('Pre-deployment validation did not pass.') | Out-Null
        }
        if ([string]::IsNullOrWhiteSpace($RollbackPlanReference)) {
            $blockers.Add('No rollback or recovery plan reference was supplied. See docs/BACKUP_RECOVERY_PLAN.md.') | Out-Null
        }
        if (-not $ChangeDisplayed) {
            $blockers.Add('The proposed production change was not displayed before execution.') | Out-Null
        }
    }

    return [PSCustomObject]@{
        Environment  = $Environment
        Mode         = $Mode
        IsPermitted  = ($blockers.Count -eq 0)
        BlockerCount = $blockers.Count
        Blockers     = $blockers.ToArray()
        Requirements = @('SEC-011','ADM-003','NFR-019')
    }
}

function Invoke-DmsWithRetry {
<#
.SYNOPSIS
    Executes a scriptblock with bounded exponential backoff and Retry-After support.
.DESCRIPTION
    Implements PRD NFR-015 and the coding standard requiring throttling to be handled with bounded
    exponential backoff, honouring Retry-After where the service supplies it.

    Only transient conditions are retried: HTTP 429 and 5xx, and recognised transient socket errors.
    A non-transient failure is rethrown immediately rather than retried, because retrying a
    permission or validation error wastes time and can mask a real defect.

    The scriptblock MUST be idempotent. PRD NFR-006 requires that replaying any critical action does
    not create duplicate effective revisions, decisions or assignments.
.PARAMETER ScriptBlock
    Operation to execute.
.PARAMETER MaxAttempt
    Maximum attempts including the first.
.PARAMETER InitialDelaySecond
    Base delay for backoff.
.PARAMETER MaxDelaySecond
    Upper bound on any single wait.
.PARAMETER OperationName
    Name used in log records.
.OUTPUTS
    Whatever the scriptblock returns.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [Parameter()][ValidateRange(1,10)][int]$MaxAttempt = 4,
        [Parameter()][ValidateRange(1,60)][int]$InitialDelaySecond = 2,
        [Parameter()][ValidateRange(1,600)][int]$MaxDelaySecond = 120,
        [Parameter()][string]$OperationName = 'operation'
    )

    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return & $ScriptBlock
        } catch {
            $ex = $_.Exception
            $statusCode = $null
            $retryAfter = $null

            $response = $null
            if ($ex.PSObject.Properties.Name -contains 'Response') { $response = $ex.Response }
            if ($null -ne $response) {
                if ($response.PSObject.Properties.Name -contains 'StatusCode') {
                    try { $statusCode = [int]$response.StatusCode } catch { $statusCode = $null }
                }
                if ($response.PSObject.Properties.Name -contains 'Headers') {
                    try {
                        $ra = $response.Headers['Retry-After']
                        if ($ra) { $retryAfter = [int]($ra | Select-Object -First 1) }
                    } catch { $retryAfter = $null }
                }
            }

            $message = "$($ex.Message)"
            $isTransient = ($statusCode -in @(429, 500, 502, 503, 504)) -or
                           ($message -match '(?i)throttl|too many requests|timed? ?out|temporarily unavailable|service unavailable|connection reset')

            if (-not $isTransient -or $attempt -ge $MaxAttempt) {
                # Do not swallow errors. Rethrow with context the operator can act on.
                throw "DMS $OperationName failed on attempt $attempt of $MaxAttempt$(if($statusCode){" (HTTP $statusCode)"}): $(Protect-DmsSensitiveText -Text $message)"
            }

            # Retry-After wins when supplied; otherwise exponential backoff with jitter.
            $delay = if ($retryAfter) {
                [Math]::Min($retryAfter, $MaxDelaySecond)
            } else {
                $backoff = $InitialDelaySecond * [Math]::Pow(2, $attempt - 1)
                $jitter  = (Get-Random -Minimum 0 -Maximum 1000) / 1000.0
                [Math]::Min([int]($backoff + $jitter), $MaxDelaySecond)
            }

            Write-DmsLog -Action 'Retry' -Target $OperationName -Result 'Skipped' -Level Warning `
                -Message "Transient failure on attempt $attempt$(if($statusCode){" (HTTP $statusCode)"}); retrying in ${delay}s." | Out-Null

            Start-Sleep -Seconds $delay
        }
    }
}
