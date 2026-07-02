#Requires -Version 7.4
<#
.SYNOPSIS
    Generate PlatyPS-style per-cmdlet markdown reference under docs/ from PSGraphKit's
    comment-based help. Run after changing any public function's help so the docs never drift.

.DESCRIPTION
    Imports the module from src/ and renders one markdown file per exported cmdlet plus an
    index (docs/README.md). This is a lightweight stand-in for PlatyPS New-MarkdownHelp that
    needs no extra module install; the output shape (SYNOPSIS/SYNTAX/DESCRIPTION/EXAMPLES/
    PARAMETERS/INPUTS/OUTPUTS) matches PlatyPS closely enough to migrate later if wanted.

.EXAMPLE
    ./build/Build-GkDocs.ps1
#>
[CmdletBinding()]
param(
    [string] $ModulePath = (Join-Path $PSScriptRoot '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1'),
    [string] $OutputDir  = (Join-Path $PSScriptRoot '..' 'docs')
)

# No Set-StrictMode here: Get-Help objects omit sections a command doesn't use (e.g. INPUTS),
# and strict mode would throw on those absent properties. Missing sections render as "None".
$ErrorActionPreference = 'Stop'

Import-Module $ModulePath -Force
$commands = Get-Command -Module PSGraphKit | Sort-Object Name

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

$commonParameters = @(
    'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ProgressAction',
    'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer',
    'PipelineVariable', 'WhatIf', 'Confirm'
)

function Get-HelpText {
    param([AllowNull()] $Block)
    if ($null -eq $Block) { return '' }
    (($Block | ForEach-Object { $_.Text }) -join "`n").Trim()
}

foreach ($cmd in $commands) {
    $name = $cmd.Name
    $help = Get-Help $name -Full

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# $name").AppendLine()

    # SYNOPSIS
    $null = $sb.AppendLine('## SYNOPSIS').AppendLine($help.Synopsis.Trim()).AppendLine()

    # SYNTAX
    $syntax = (Get-Command $name -Syntax).Trim()
    $null = $sb.AppendLine('## SYNTAX').AppendLine('```').AppendLine($syntax).AppendLine('```').AppendLine()

    # DESCRIPTION
    $desc = Get-HelpText $help.description
    $null = $sb.AppendLine('## DESCRIPTION').AppendLine($desc).AppendLine()

    # EXAMPLES
    $null = $sb.AppendLine('## EXAMPLES')
    $i = 0
    foreach ($ex in @($help.examples.example)) {
        $i++
        $rawTitle = ($ex.title -replace '-', '').Trim()
        if (-not $rawTitle -or $rawTitle -match '^(?i)example\s*\d+$') { $title = "Example $i" }
        else { $title = "Example $i`: $rawTitle" }
        $code = ($ex.code | Out-String).Trim()
        $remarks = Get-HelpText $ex.remarks
        $null = $sb.AppendLine().AppendLine("### $title").AppendLine('```powershell').AppendLine($code).AppendLine('```')
        if ($remarks) { $null = $sb.AppendLine($remarks) }
    }
    $null = $sb.AppendLine()

    # PARAMETERS
    $null = $sb.AppendLine('## PARAMETERS')
    foreach ($p in @($help.parameters.parameter)) {
        if ($commonParameters -contains $p.name) { continue }
        $pDesc = Get-HelpText $p.description
        $type = if ($p.type -and $p.type.name) { $p.type.name } else { '' }
        $default = if ($p.PSObject.Properties['defaultValue'] -and $p.defaultValue) { $p.defaultValue } else { 'None' }
        $null = $sb.AppendLine().AppendLine("### -$($p.name)").AppendLine($pDesc).AppendLine()
        $null = $sb.AppendLine('```yaml')
        $null = $sb.AppendLine("Type: $type")
        $null = $sb.AppendLine("Required: $($p.required)")
        $null = $sb.AppendLine("Position: $($p.position)")
        $null = $sb.AppendLine("Default value: $default")
        $null = $sb.AppendLine("Accept pipeline input: $($p.pipelineInput)")
        $null = $sb.AppendLine('```')
    }
    $null = $sb.AppendLine().AppendLine('### CommonParameters').AppendLine(
        'This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, ' +
        '-WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. ' +
        'For more information, see about_CommonParameters.').AppendLine()

    # INPUTS / OUTPUTS
    $null = $sb.AppendLine('## INPUTS')
    $inputs = @($help.inputTypes.inputType | ForEach-Object { $_.type.name } | Where-Object { $_ })
    if ($inputs) { foreach ($it in $inputs) { $null = $sb.AppendLine("### $($it.Trim())") } }
    else { $null = $sb.AppendLine('### None') }
    $null = $sb.AppendLine()

    $null = $sb.AppendLine('## OUTPUTS')
    $outputs = @($help.returnValues.returnValue | ForEach-Object { $_.type.name } | Where-Object { $_ })
    if ($outputs) { foreach ($ot in $outputs) { $null = $sb.AppendLine("### $($ot.Trim())") } }
    else { $null = $sb.AppendLine('### None') }
    $null = $sb.AppendLine()

    $file = Join-Path $OutputDir "$name.md"
    Set-Content -Path $file -Value $sb.ToString().TrimEnd() -Encoding utf8NoBOM
    Write-Verbose "Wrote $file"
}

# Index
$idx = [System.Text.StringBuilder]::new()
$null = $idx.AppendLine('# PSGraphKit cmdlet reference').AppendLine()
$null = $idx.AppendLine('Auto-generated from each cmdlet''s comment-based help by ``build/Build-GkDocs.ps1``.').AppendLine(
    'Do not edit these files by hand — edit the function help and regenerate.').AppendLine()
$null = $idx.AppendLine('| Cmdlet | Synopsis |').AppendLine('|--------|----------|')
foreach ($cmd in $commands) {
    $syn = (Get-Help $cmd.Name).Synopsis.Trim() -replace '\r?\n', ' '
    $null = $idx.AppendLine("| [$($cmd.Name)]($($cmd.Name).md) | $syn |")
}
Set-Content -Path (Join-Path $OutputDir 'README.md') -Value $idx.ToString().TrimEnd() -Encoding utf8NoBOM

Write-Information "Generated docs for $($commands.Count) cmdlets in $OutputDir" -InformationAction Continue
