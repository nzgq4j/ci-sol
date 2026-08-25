#Requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Dot-source Private then Public. Public functions are exported by the manifest, not by wildcard,
# so the exported surface is an explicit contract (PRD coding standards).
foreach ($scope in @('Private','Public')) {
    $dir = Join-Path $PSScriptRoot $scope
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
            . $_.FullName
        }
    }
}
