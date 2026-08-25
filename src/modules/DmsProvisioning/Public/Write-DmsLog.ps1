Set-StrictMode -Version Latest

function Write-DmsLog {
<#
.SYNOPSIS
    Emits a structured DMS log record.
.DESCRIPTION
    Every log record carries timestamp, environment, action, target, result and correlation ID, as
    required by the PRD coding standards. Message text is passed through secret redaction so that
    access tokens, secrets and connection strings can never reach a log or an Exception Register
    entry (PRD SEC-004 and section 17.3).

    Records are written to the PowerShell information/verbose/warning/error streams according to
    Level, and optionally appended to a JSON Lines file for pipeline capture.
.PARAMETER Action
    The operation being performed, e.g. 'EnsureSiteColumn'.
.PARAMETER Target
    The resource acted upon, e.g. 'DmsDocumentId'.
.PARAMETER Result
    Outcome classification.
.PARAMETER Environment
    Environment key (dev/test/prod).
.PARAMETER CorrelationId
    Correlation ID joining all records for one deployment or workflow instance.
.PARAMETER Message
    Human-readable detail. Redacted before emission.
.PARAMETER Level
    Severity for stream routing.
.PARAMETER LogPath
    Optional JSON Lines file to append to.
.EXAMPLE
    Write-DmsLog -Action 'EnsureList' -Target 'Approval Evidence' -Result Created -Environment dev -CorrelationId $cid
.OUTPUTS
    PSCustomObject representing the structured record.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Action,
        [Parameter()][AllowEmptyString()][string]$Target = '',
        [Parameter()][ValidateSet('Planned','Created','Updated','Skipped','Compliant','Blocked','Failed','Info')][string]$Result = 'Info',
        [Parameter()][AllowEmptyString()][string]$Environment = '',
        [Parameter()][AllowEmptyString()][string]$CorrelationId = '',
        [Parameter()][AllowEmptyString()][string]$Message = '',
        [Parameter()][ValidateSet('Verbose','Information','Warning','Error')][string]$Level = 'Information',
        [Parameter()][AllowEmptyString()][string]$LogPath = ''
    )

    $record = [PSCustomObject]@{
        timestampUtc  = (Get-Date).ToUniversalTime().ToString('o')
        environment   = $Environment
        action        = $Action
        target        = $Target
        result        = $Result
        correlationId = $CorrelationId
        level         = $Level
        message       = (Protect-DmsSensitiveText -Text $Message)
    }

    $line = '[{0}] {1,-9} {2,-28} {3,-40} {4}' -f `
        $record.timestampUtc, $record.result, $record.action, $record.target, $record.message

    switch ($Level) {
        'Verbose'     { Write-Verbose $line }
        'Warning'     { Write-Warning $line }
        'Error'       { Write-Error   $line -ErrorAction Continue }
        default       { Write-Information $line -InformationAction Continue }
    }

    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $dir = Split-Path -Parent $LogPath
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        ($record | ConvertTo-Json -Compress -Depth 5) | Add-Content -LiteralPath $LogPath -Encoding utf8
    }

    return $record
}
