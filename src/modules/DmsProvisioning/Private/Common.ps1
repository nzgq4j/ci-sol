Set-StrictMode -Version Latest

# Normalises an object that may be a single value, $null, or an array into an array.
function ConvertTo-DmsArray {
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(ValueFromPipeline)][AllowNull()]$InputObject)
    process {
        if ($null -eq $InputObject) { return ,@() }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            return ,@($InputObject)
        }
        return ,@($InputObject)
    }
}
