Describe 'PSGraphKit module' {

    BeforeAll {
        $script:ManifestPath = Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1'
        Import-Module $script:ManifestPath -Force
    }

    It 'has a valid manifest' {
        Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'depends only on Microsoft.Graph.Authentication' {
        $manifest = Import-PowerShellDataFile -Path $script:ManifestPath
        $names = @($manifest.RequiredModules | ForEach-Object { if ($_ -is [hashtable]) { $_.ModuleName } else { $_ } })
        $names | Should -Be @('Microsoft.Graph.Authentication')
    }

    It 'exports Get-GkConnectionInfo' {
        (Get-Command -Module PSGraphKit).Name | Should -Contain 'Get-GkConnectionInfo'
    }

    It 'does not export private helpers' {
        $exported = (Get-Command -Module PSGraphKit).Name
        $exported | Should -Not -Contain 'Invoke-GkGraphRequest'
        $exported | Should -Not -Contain 'Test-GkConnection'
        $exported | Should -Not -Contain 'Invoke-GkRawGraphCall'
    }

    It 'exports exactly the Public/*.ps1 functions (manifest stays in sync)' {
        $publicRoot = Join-Path (Split-Path $script:ManifestPath) 'Public'
        $files    = @(Get-ChildItem -Path $publicRoot -Filter '*.ps1' | Select-Object -ExpandProperty BaseName | Sort-Object)
        $exported = @((Get-Command -Module PSGraphKit).Name | Sort-Object)
        $exported | Should -Be $files
    }

    It 'every public function has comment-based help with a synopsis and at least 3 examples' {
        foreach ($name in (Get-Command -Module PSGraphKit).Name) {
            $help = Get-Help $name -ErrorAction Stop
            $help.Synopsis            | Should -Not -BeNullOrEmpty -Because "$name needs a synopsis"
            @($help.Examples.Example).Count | Should -BeGreaterOrEqual 3 -Because "$name needs >= 3 examples"
        }
    }

    It 'has a docs page carrying the current synopsis for every exported cmdlet' {
        $docsDir = Join-Path $PSScriptRoot '..' '..' 'docs'
        foreach ($name in (Get-Command -Module PSGraphKit).Name) {
            $doc = Join-Path $docsDir "$name.md"
            Test-Path $doc | Should -BeTrue -Because "docs/$name.md should exist (run build/Build-GkDocs.ps1)"
            $firstLine = (((Get-Help $name).Synopsis.Trim()) -split "`n")[0].Trim()
            (Get-Content $doc -Raw) | Should -BeLike "*$firstLine*" -Because "docs/$name.md should carry the current synopsis"
        }
    }

    It 'every public function declares required scopes in the scope map' {
        $names = @((Get-Command -Module PSGraphKit).Name)   # exported functions only (outside module scope)
        InModuleScope PSGraphKit -Parameters @{ Names = $names } {
            param($Names)
            foreach ($name in $Names) {
                $script:GkScopeMap.ContainsKey($name) | Should -BeTrue -Because "$name must have a scope-map entry"
            }
        }
    }
}
