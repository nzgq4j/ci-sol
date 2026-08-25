Set-StrictMode -Version Latest

function Get-DmsRepositoryRoot {
<#
.SYNOPSIS
    Returns the absolute path of the repository root.
.DESCRIPTION
    Resolved from the module location so scripts can locate config/, docs/ and tests/ without
    hard-coded or relative paths that break when the working directory changes (PRD ADM-005).
.EXAMPLE
    $configDir = Join-Path (Get-DmsRepositoryRoot) 'config'
.OUTPUTS
    System.String
#>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    return (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')).Path
}

function Protect-DmsSensitiveText {
<#
.SYNOPSIS
    Redacts credentials and tokens from text before it is logged or stored.
.DESCRIPTION
    PRD SEC-004 and section 17.3 require that secrets, access tokens and connection credentials never
    reach operational logs or Exception Register entries. Every log record and every exception
    description passes through this function.

    It redacts bearer tokens, JSON Web Tokens, and key/value pairs whose key names a credential.
.PARAMETER Text
    Text to redact. Null and empty are returned unchanged.
.EXAMPLE
    Protect-DmsSensitiveText -Text 'Authorization: Bearer eyJhbGciOi...'
.OUTPUTS
    System.String
#>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter()][AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $patterns = @(
        @{ Pattern = '(?i)(bearer\s+)[A-Za-z0-9\-\._~\+\/]+=*'          ; Replace = '$1[REDACTED]' },
        @{ Pattern = '(?i)(eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]*)' ; Replace = '[REDACTED-JWT]' },
        @{ Pattern = '(?i)((?:password|pwd|secret|clientsecret|apikey|api_key|token|connectionstring)\s*[:=]\s*)("?)[^\s",;]+' ; Replace = '$1[REDACTED]' }
    )
    $out = $Text
    foreach ($p in $patterns) { $out = [regex]::Replace($out, $p.Pattern, $p.Replace) }
    return $out
}

function Read-DmsJsonFile {
<#
.SYNOPSIS
    Reads and parses a JSON configuration file with actionable errors.
.DESCRIPTION
    Distinguishes missing, empty and malformed files so an operator sees which of the three occurred
    rather than a generic parse failure (PRD coding standards: provide actionable error messages).
.PARAMETER Path
    File to read.
.EXAMPLE
    $settings = Read-DmsJsonFile -Path ./config/lists.json
.OUTPUTS
    PSCustomObject
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Configuration file not found: $Path" }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "Configuration file is empty: $Path" }
    try { return ($raw | ConvertFrom-Json -Depth 40) }
    catch { throw "Configuration file is not valid JSON: $Path. $($_.Exception.Message)" }
}
