#Requires -Version 7.4
#Requires -Modules Microsoft.Graph.Authentication

# Root loader: dot-source Private (helpers) then Public (exported cmdlets).
# Only functions in Public/ are exported (the manifest's FunctionsToExport is authoritative).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$private = @( Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue )
$public  = @( Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -ErrorAction SilentlyContinue )

foreach ($file in @($private + $public)) {
    try {
        . $file.FullName
    }
    catch {
        throw "PSGraphKit failed to load '$($file.Name)': $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function $public.BaseName
