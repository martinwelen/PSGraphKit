#Requires -Version 7.4
<#
.SYNOPSIS
    Copy the CHANGELOG section for the manifest's current version into the manifest's ReleaseNotes.

.DESCRIPTION
    PSData.ReleaseNotes is what the PowerShell Gallery shows on a package page, and it is frozen at
    publish time — a version cannot be edited afterwards. Shipping the literal string
    'See CHANGELOG.md' therefore gives every visitor a pointer instead of an answer, permanently.

    This lifts the matching '## [x.y.z]' section out of CHANGELOG.md and writes it into the manifest
    as a single-quoted here-string, which needs no escaping: the only sequence that could terminate
    it is a line beginning with '@, and that is rejected rather than silently mangled.

    RUN IT BEFORE SIGNING. It modifies the manifest, and an Authenticode signature covers file bytes,
    so signing first would produce a module that looks signed and fails verification.

.PARAMETER ManifestPath
    The module manifest to update. Defaults to the repo's own.

.PARAMETER ChangelogPath
    The changelog to read. Defaults to the repo's own.

.PARAMETER MaxLength
    Truncate beyond this many characters. The Gallery accepts long release notes, but an unbounded
    field is a way to accidentally ship an entire file.

.PARAMETER PassThru
    Emit the notes that were written.

.EXAMPLE
    ./build/Set-GkReleaseNotes.ps1

.EXAMPLE
    ./build/Set-GkReleaseNotes.ps1 -PassThru
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $ManifestPath = (Join-Path $PSScriptRoot '..' 'src' 'PSGraphKit' 'PSGraphKit.psd1'),
    [string] $ChangelogPath = (Join-Path $PSScriptRoot '..' 'CHANGELOG.md'),
    [int] $MaxLength = 8000,
    [switch] $PassThru
)

$ErrorActionPreference = 'Stop'

$version = (Test-ModuleManifest -Path $ManifestPath).Version.ToString()

# Take everything from this version's heading up to the next one. Anchored on the heading rather
# than 'the first section', so building an older tag does not silently pick up newer notes.
$lines = Get-Content $ChangelogPath
$start = -1
$end = $lines.Count
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($start -lt 0) {
        if ($lines[$i] -match "^##\s+\[$([regex]::Escape($version))\]") { $start = $i + 1 }
    }
    elseif ($lines[$i] -match '^##\s+\[') { $end = $i; break }
}

if ($start -lt 0) {
    throw "CHANGELOG.md has no '## [$version]' section. Add one before releasing $version."
}

$notes = ($lines[$start..($end - 1)] -join "`n").Trim()
if ([string]::IsNullOrWhiteSpace($notes)) {
    throw "The '## [$version]' section in CHANGELOG.md is empty."
}

# A line starting with '@ would close the here-string early and corrupt the manifest. Refuse rather
# than mangle: this has never happened, and if it ever does the answer is to reword the changelog.
if ($notes -split "`n" | Where-Object { $_ -match "^'@" }) {
    throw "The '## [$version]' section contains a line starting with '@, which cannot go in a here-string."
}

if ($notes.Length -gt $MaxLength) {
    $notes = $notes.Substring(0, $MaxLength).TrimEnd() + "`n`n(truncated — see CHANGELOG.md)"
}

$text = Get-Content $ManifestPath -Raw
$pattern = "ReleaseNotes(\s*)=\s*(?:'[^']*'|@'[\s\S]*?'@)"
if ($text -notmatch $pattern) {
    throw "Could not find a ReleaseNotes entry in $ManifestPath."
}

$replacement = "ReleaseNotes`$1= @'`n$notes`n'@"
$updated = [regex]::Replace($text, $pattern, { param($m) $replacement -replace '\$1', $m.Groups[1].Value }, 1)

if ($PSCmdlet.ShouldProcess($ManifestPath, "Write ReleaseNotes for $version ($($notes.Length) chars)")) {
    # Manifests ship UTF-8 with a BOM so their signatures do not depend on the signing machine's
    # code page. Writing without one here would undo that for the one file most likely to be read.
    [System.IO.File]::WriteAllText($ManifestPath, $updated, (New-Object System.Text.UTF8Encoding $true))

    $check = (Test-ModuleManifest -Path $ManifestPath).PrivateData.PSData.ReleaseNotes
    if ($check -notlike "*$(($notes -split "`n")[0])*") {
        throw "The manifest no longer reports the notes that were written; check $ManifestPath."
    }
    Write-Information "ReleaseNotes for $version written: $($notes.Length) characters." -InformationAction Continue
}

if ($PassThru) { $notes }
