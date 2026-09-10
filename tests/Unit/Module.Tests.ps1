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

    It 'ships every signable file as UTF-8 with a BOM' {
        # Not cosmetic — it is what makes the release signature portable. Authenticode for
        # PowerShell files goes through a Subject Interface Package that decodes a BOM-less file
        # using the SIGNING machine's ANSI code page before hashing it. The release runner is
        # en-US (1252), so a file containing an em dash hashes one way there and a different way
        # on a machine running 1251, 932, 936, 949 or the UTF-8 beta option — where the signature
        # then fails with HashMismatch and the module will not import under AllSigned.
        #
        # A BOM removes the ambiguity: the file is decoded as UTF-8 everywhere. The release
        # workflow cannot catch a regression here, because verification on the signing machine
        # always agrees with itself — so the check has to live where the files are edited.
        $moduleDir = Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit'
        $missing = foreach ($f in Get-ChildItem $moduleDir -Recurse -Include *.ps1, *.psm1, *.psd1, *.ps1xml) {
            $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
            $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            if (-not $hasBom) { $f.Name }
        }
        $missing | Should -BeNullOrEmpty -Because "these files would carry a code-page-dependent signature: $($missing -join ', ')"
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
