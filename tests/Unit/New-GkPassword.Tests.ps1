Import-Module (Join-Path $PSScriptRoot '..' '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1') -Force

InModuleScope PSGraphKit {

    Describe 'New-GkPassword' {

        It 'honours the requested length' {
            (New-GkPassword).Length | Should -Be 20
            (New-GkPassword -Length 32).Length | Should -Be 32
        }

        It 'rejects a length below the tenant-policy floor' {
            { New-GkPassword -Length 8 } | Should -Throw
        }

        It 'always includes all four character classes' {
            # Guaranteed by construction, not by chance — check enough samples to catch a regression
            # that made a class merely probable.
            1..50 | ForEach-Object {
                $p = New-GkPassword -Length 12
                $p | Should -Match '[A-Z]'
                $p | Should -Match '[a-z]'
                $p | Should -Match '[0-9]'
                $p | Should -Match '[!#%&*+\-=?@_]'
            }
        }

        It 'excludes glyphs that are misread when a password is dictated' {
            # -CMatch, not -Match: PowerShell's default matching is case-insensitive, which would
            # flag the perfectly legible capital L as if it were a lowercase l.
            $joined = -join (1..50 | ForEach-Object { New-GkPassword })
            $joined | Should -Not -CMatch '[OIl01]'
        }

        It 'does not place the guaranteed characters in fixed positions' {
            # Without the shuffle the first character would always be upper-case.
            $firsts = 1..60 | ForEach-Object { (New-GkPassword)[0] }
            @($firsts | Where-Object { $_ -cmatch '[a-z]' }).Count | Should -BeGreaterThan 0
        }

        It 'produces a different password every call' {
            $set = 1..50 | ForEach-Object { New-GkPassword }
            ($set | Select-Object -Unique).Count | Should -Be 50
        }
    }
}
