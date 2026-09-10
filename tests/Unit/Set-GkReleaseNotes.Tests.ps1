BeforeAll {
    $script:Script = Join-Path $PSScriptRoot '..' '..' 'build' 'Set-GkReleaseNotes.ps1'

    # Build a throwaway manifest + changelog pair per test. The real ones must never be touched:
    # this script rewrites the manifest in place, and a test that leaves ReleaseNotes populated
    # would put a whole changelog section into everyone's next commit.
    function New-TestPair {
        param([string] $Version = '9.9.9', [string[]] $ChangelogBody)

        $dir = Join-Path ([System.IO.Path]::GetTempPath()) "gknotes-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null

        $manifest = Join-Path $dir 'Fake.psd1'
        New-ModuleManifest -Path $manifest -ModuleVersion $Version -RootModule 'Fake.psm1' `
            -Description 'Fake module for testing' -ReleaseNotes 'See CHANGELOG.md'
        Set-Content (Join-Path $dir 'Fake.psm1') '' -Encoding utf8

        $changelog = Join-Path $dir 'CHANGELOG.md'
        Set-Content $changelog $ChangelogBody -Encoding utf8

        [pscustomobject]@{ Dir = $dir; Manifest = $manifest; Changelog = $changelog }
    }
}

Describe 'Set-GkReleaseNotes' {

    It 'copies the matching section into ReleaseNotes' {
        $p = New-TestPair -ChangelogBody @(
            '# Changelog', ''
            '## [9.9.9] - 2026-01-01', ''
            'Headline for the version under test.', ''
            '### Fixed', '- something specific', ''
            '## [9.9.8] - 2025-12-01', ''
            'Older notes that must not leak in.'
        )
        try {
            & $script:Script -ManifestPath $p.Manifest -ChangelogPath $p.Changelog -InformationAction SilentlyContinue
            $notes = (Import-PowerShellDataFile $p.Manifest).PrivateData.PSData.ReleaseNotes
            $notes | Should -Match 'Headline for the version under test'
            $notes | Should -Match 'something specific'
            $notes | Should -Not -Match 'Older notes'
            $notes | Should -Not -Match '## \[9\.9\.8\]'
        }
        finally { Remove-Item $p.Dir -Recurse -Force }
    }

    It 'anchors on the version heading rather than the first section' {
        # Building an older tag must not pick up notes written for a newer release.
        $p = New-TestPair -Version '9.9.8' -ChangelogBody @(
            '# Changelog', ''
            '## [9.9.9] - 2026-01-01', 'Newer release.', ''
            '## [9.9.8] - 2025-12-01', 'The one we want.'
        )
        try {
            & $script:Script -ManifestPath $p.Manifest -ChangelogPath $p.Changelog -InformationAction SilentlyContinue
            $notes = (Import-PowerShellDataFile $p.Manifest).PrivateData.PSData.ReleaseNotes
            $notes | Should -Match 'The one we want'
            $notes | Should -Not -Match 'Newer release'
        }
        finally { Remove-Item $p.Dir -Recurse -Force }
    }

    It 'throws when the version has no section' {
        $p = New-TestPair -ChangelogBody @('# Changelog', '', '## [1.0.0] - 2020-01-01', 'Unrelated.')
        try {
            { & $script:Script -ManifestPath $p.Manifest -ChangelogPath $p.Changelog } |
                Should -Throw -ExpectedMessage '*no *9.9.9* section*'
        }
        finally { Remove-Item $p.Dir -Recurse -Force }
    }

    It 'throws when the section is empty' {
        $p = New-TestPair -ChangelogBody @('# Changelog', '', '## [9.9.9] - 2026-01-01', '', '## [9.9.8] - 2025-01-01', 'x')
        try {
            { & $script:Script -ManifestPath $p.Manifest -ChangelogPath $p.Changelog } |
                Should -Throw -ExpectedMessage '*is empty*'
        }
        finally { Remove-Item $p.Dir -Recurse -Force }
    }

    It "refuses a section containing a line starting with '@" {
        # That sequence would close the here-string early and corrupt the manifest, so the script
        # must fail loudly rather than write something that no longer parses.
        $p = New-TestPair -ChangelogBody @('# Changelog', '', '## [9.9.9] - 2026-01-01', 'Fine line.', "'@ then trouble")
        try {
            { & $script:Script -ManifestPath $p.Manifest -ChangelogPath $p.Changelog } |
                Should -Throw -ExpectedMessage "*cannot go in a here-string*"
        }
        finally { Remove-Item $p.Dir -Recurse -Force }
    }

    It 'truncates beyond -MaxLength and says so' {
        $long = 1..400 | ForEach-Object { "Line $_ of a very long changelog section." }
        $p = New-TestPair -ChangelogBody (@('# Changelog', '', '## [9.9.9] - 2026-01-01') + $long)
        try {
            & $script:Script -ManifestPath $p.Manifest -ChangelogPath $p.Changelog -MaxLength 500 -InformationAction SilentlyContinue
            $notes = (Import-PowerShellDataFile $p.Manifest).PrivateData.PSData.ReleaseNotes
            $notes.Length | Should -BeLessThan 700
            $notes | Should -Match 'truncated'
        }
        finally { Remove-Item $p.Dir -Recurse -Force }
    }

    It 'leaves the manifest UTF-8 with a BOM' {
        # The manifest is signed, and a BOM-less file gets a code-page-dependent hash.
        $p = New-TestPair -ChangelogBody @('# Changelog', '', '## [9.9.9] - 2026-01-01', 'Notes.')
        try {
            & $script:Script -ManifestPath $p.Manifest -ChangelogPath $p.Changelog -InformationAction SilentlyContinue
            $bytes = [System.IO.File]::ReadAllBytes($p.Manifest)
            $bytes[0] | Should -Be 0xEF
            $bytes[1] | Should -Be 0xBB
            $bytes[2] | Should -Be 0xBF
        }
        finally { Remove-Item $p.Dir -Recurse -Force }
    }

    It 'changes nothing under -WhatIf' {
        $p = New-TestPair -ChangelogBody @('# Changelog', '', '## [9.9.9] - 2026-01-01', 'Notes.')
        try {
            $before = Get-Content $p.Manifest -Raw
            & $script:Script -ManifestPath $p.Manifest -ChangelogPath $p.Changelog -WhatIf -InformationAction SilentlyContinue
            Get-Content $p.Manifest -Raw | Should -Be $before
        }
        finally { Remove-Item $p.Dir -Recurse -Force }
    }
}
