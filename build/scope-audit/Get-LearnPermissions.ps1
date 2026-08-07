# Build (METHOD, path) -> Learn permissions table, straight from the docs source markdown.
# Learn is the authority; the kibali permissions.json snapshot is known to lag it.
param(
    [string] $DocsRoot = "$PSScriptRoot\graph-docs\api-reference",
    [string] $Inventory = "$PSScriptRoot\call-inventory-final.csv",
    [string] $OutFile = "$PSScriptRoot\learn-permissions.csv"
)
$ErrorActionPreference = 'Stop'

function ConvertTo-DocPath {
    param([string] $P)
    $p = $P.Trim()
    $p = ($p -split '\?')[0]
    $p = $p -replace '\{[^}]*\}', '{id}'          # {user-id}, {id | userPrincipalName} -> {id}
    $p = $p -replace "\('?[^)]*'?\)", "({id})"    # (appId='x') -> ({id})
    $p = $p -replace '/+', '/'
    if ($p.Length -gt 1) { $p = $p.TrimEnd('/') }
    return $p
}

# ---------- index every doc file by the calls it documents ----------
$index = @{}
foreach ($channel in 'v1.0', 'beta') {
    $dir = Join-Path $DocsRoot "$channel\api"
    if (-not (Test-Path $dir)) { continue }
    foreach ($f in Get-ChildItem $dir -Filter *.md) {
        $text = [IO.File]::ReadAllText($f.FullName)
        # The '## HTTP request' section holds one or more "VERB /path" lines in a code fence.
        $m = [regex]::Match($text, '(?ms)^##\s+HTTP request\s*(.+?)^##\s')
        if (-not $m.Success) { continue }
        foreach ($line in ($m.Groups[1].Value -split "`n")) {
            # Capture the whole path: it can contain spaces, e.g. "{id | userPrincipalName}".
            $lm = [regex]::Match($line.Trim(), '^(GET|POST|PATCH|PUT|DELETE)\s+(/.*)$')
            if (-not $lm.Success) { continue }
            $key = "$channel|$($lm.Groups[1].Value) $(ConvertTo-DocPath $lm.Groups[2].Value)"
            if (-not $index.ContainsKey($key)) { $index[$key] = @() }
            if ($index[$key] -notcontains $f.FullName) { $index[$key] += $f.FullName }
        }
    }
}
Write-Output "Indexed $($index.Count) documented (channel, method, path) keys."

# ---------- pull the permissions table out of a doc ----------
function Get-PermissionTable {
    param([string] $Path)
    $text = [IO.File]::ReadAllText($Path)
    $sec = [regex]::Match($text, '(?ms)^##\s+Permissions\s*(.+?)^##\s')
    if (-not $sec.Success) { return $null }
    $body = $sec.Groups[1].Value

    # RBAC docs carry one table per role-management provider (directory, entitlement management,
    # Cloud PC, device management...). PSGraphKit only ever addresses /roleManagement/directory,
    # so narrow to that provider's section before parsing, otherwise the last table on the page wins.
    $prov = [regex]::Match($body, '(?ms)^###\s+For the directory[^\r\n]*\r?\n(.+?)(?=^###\s|\z)')
    if ($prov.Success) { $body = $prov.Groups[1].Value }

    # Graph docs keep the permission table in a per-channel include; follow it.
    $inc = [regex]::Match($body, '\[!INCLUDE\s*\[[^\]]*\]\((\.\./includes/permissions/[^)]+)\)\]')
    if ($inc.Success) {
        $incPath = Join-Path (Split-Path $Path -Parent) $inc.Groups[1].Value
        $incPath = [IO.Path]::GetFullPath($incPath)
        if (Test-Path $incPath) { $body = [IO.File]::ReadAllText($incPath) }
    }

    $out = [ordered]@{ DelegatedLeast = ''; DelegatedHigher = ''; AppLeast = ''; AppHigher = ''; Format = '' }
    foreach ($line in ($body -split "`n")) {
        if ($line -notmatch '^\s*\|') { continue }
        $cells = @($line.Trim().Trim('|') -split '\|' | ForEach-Object { ($_ -replace '\*', '').Trim() })
        if ($cells.Count -lt 2) { continue }
        $type = $cells[0]
        if ($type -notmatch '^(Delegated \(work or school|Application)') { continue }

        if ($cells.Count -ge 3) {
            # Current format: | type | least privileged | higher privileged |
            $least = $cells[1]; $higher = $cells[2]; $fmt = 'least/higher'
        }
        else {
            # Older format: | type | permissions from least to most privileged |
            $all = @($cells[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $least = @($all)[0]; $higher = (@($all) | Select-Object -Skip 1) -join ', '; $fmt = 'least-to-most'
        }
        if ($type -match '^Delegated \(work or school') { $out.DelegatedLeast = $least; $out.DelegatedHigher = $higher }
        else                                            { $out.AppLeast = $least;      $out.AppHigher = $higher }
        if (-not $out.Format) { $out.Format = $fmt }
    }
    return $out
}

# ---------- resolve each endpoint we call ----------
$calls = Import-Csv $Inventory
$endpoints = $calls | ForEach-Object { "$($_.Method) $($_.Path)" } | Sort-Object -Unique

# The two report endpoints have no v1.0 equivalent; everything else is v1.0.
$betaOnly = @('GET /reports/servicePrincipalSignInActivities', 'GET /reports/appCredentialSignInActivities')

$rows = foreach ($ep in $endpoints) {
    $channel = if ($betaOnly -contains $ep) { 'beta' } else { 'v1.0' }
    $key = "$channel|$ep"
    $files = $index[$key]
    if (-not $files -and $channel -eq 'v1.0') { $files = $index["beta|$ep"]; if ($files) { $channel = 'beta(fallback)' } }

    if (-not $files) {
        [pscustomobject]@{ Endpoint = $ep; Channel = $channel; Doc = ''; DelegatedLeast = ''; DelegatedHigher = ''; AppLeast = ''; AppHigher = ''; Note = 'NO-DOC-MATCH' }
        continue
    }
    # Prefer the list/get doc when several files document the same call.
    $file = @($files | Sort-Object { (Get-Item $_).Name.Length })[0]
    $t = Get-PermissionTable $file
    if (-not $t) {
        [pscustomobject]@{ Endpoint = $ep; Channel = $channel; Doc = (Split-Path $file -Leaf); DelegatedLeast = ''; DelegatedHigher = ''; AppLeast = ''; AppHigher = ''; Note = 'NO-PERMISSION-TABLE' }
        continue
    }
    [pscustomobject]@{
        Endpoint = $ep; Channel = $channel; Doc = (Split-Path $file -Leaf)
        DelegatedLeast = $t.DelegatedLeast; DelegatedHigher = $t.DelegatedHigher
        AppLeast = $t.AppLeast; AppHigher = $t.AppHigher
        Format = $t.Format
        Note = if ($files.Count -gt 1) { "multi-doc($($files.Count))" } else { '' }
    }
}

$rows | Export-Csv $OutFile -NoTypeInformation -Encoding utf8
Write-Output ""
Write-Output "=== resolution ==="
"matched          : $(@($rows | Where-Object { $_.DelegatedLeast -or $_.AppLeast }).Count) / $($rows.Count)"
"no doc match     : $(@($rows | Where-Object Note -eq 'NO-DOC-MATCH').Count)"
"no perm table    : $(@($rows | Where-Object Note -eq 'NO-PERMISSION-TABLE').Count)"
Write-Output ""
Write-Output "=== unmatched endpoints ==="
$rows | Where-Object { $_.Note -eq 'NO-DOC-MATCH' -or $_.Note -eq 'NO-PERMISSION-TABLE' } | ForEach-Object { "  $($_.Endpoint)   [$($_.Note)]" }
