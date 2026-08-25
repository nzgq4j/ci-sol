Set-StrictMode -Version Latest

function Test-DmsProperty {
<#
.SYNOPSIS
    Tests whether an object exposes a named property.
.DESCRIPTION
    Configuration objects are deserialised JSON, so optional keys are simply absent rather than null.
    Under Set-StrictMode, touching an absent property throws. Every configuration read therefore goes
    through this test or Get-DmsPropertyOrDefault, which keeps strict mode enabled across the module
    instead of relaxing it to tolerate optional configuration.
.PARAMETER InputObject
    Object to inspect. May be null.
.PARAMETER Name
    Property name.
.EXAMPLE
    if (Test-DmsProperty -InputObject $library -Name 'provisionWhen') { ... }
.OUTPUTS
    System.Boolean
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][AllowNull()]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )
    if ($null -eq $InputObject) { return $false }
    return [bool]($InputObject.PSObject.Properties.Name -contains $Name)
}

function Get-DmsPropertyOrDefault {
<#
.SYNOPSIS
    Reads a property, returning a default when it is absent or null.
.DESCRIPTION
    The safe accessor for optional configuration values. Returning an explicit default keeps callers
    free of null checks and makes the intended fallback visible at the call site.
.PARAMETER InputObject
    Object to read from. May be null.
.PARAMETER Name
    Property name.
.PARAMETER Default
    Value returned when the property is absent or null.
.EXAMPLE
    $limit = Get-DmsPropertyOrDefault -InputObject $view -Name 'rowLimit' -Default 30
.OUTPUTS
    The property value or the supplied default.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()]$InputObject,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()]$Default = $null
    )
    if (Test-DmsProperty -InputObject $InputObject -Name $Name) {
        $v = $InputObject.$Name
        if ($null -eq $v) { return $Default }
        return $v
    }
    return $Default
}
