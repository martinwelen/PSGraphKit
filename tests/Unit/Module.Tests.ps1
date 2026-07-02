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
}
