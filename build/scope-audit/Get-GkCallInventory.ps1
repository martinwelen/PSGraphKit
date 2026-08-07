# Extract every Graph call PSGraphKit makes, as (cmdlet, method, path).
# Resolves URIs assigned to a local variable and strips PowerShell backtick escapes, so cmdlets
# that build their URI before calling Invoke-GkGraphRequest are covered too.
param(
    [string] $Repo = 'C:\dev\PSGraphKit',
    [string] $OutFile = "$PSScriptRoot\call-inventory.csv"
)
$ErrorActionPreference = 'Stop'

function ConvertTo-GraphPath {
    param([string] $Uri)
    $u = $Uri -replace '`', ''          # PowerShell escape char: `? and `$ are literal ? and $
    $u = ($u -split '\?')[0]            # drop the query string
    # Collapse a subexpression that only escapes an id, e.g. $([uri]::EscapeDataString($x)).
    $u = $u -replace '\$\(\[uri\]::EscapeDataString\([^)]*\)\)', '{id}'
    # OData segments are literal path parts, not variables — protect them before substituting.
    $u = $u -replace '\$(ref|count|value)\b', '<<ODATA:$1>>'
    $u = $u -replace '\$\{[^}]+\}', '{id}'
    $u = $u -replace '\$\w+', '{id}'
    $u = $u -replace '<<ODATA:(\w+)>>', '$$$1'
    $u = $u -replace "\('?[^)]*'?\)", "({id})"
    $u = $u -replace '/+', '/'
    if ($u.Length -gt 1) { $u = $u.TrimEnd('/') }
    return $u
}

$rows = foreach ($file in Get-ChildItem "$Repo\src\PSGraphKit\Public" -Filter *.ps1) {
    $text = Get-Content $file.FullName -Raw
    $t = $null; $e = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$t, [ref]$e)

    # Index assignments in the file so a URI built before the call can still be resolved:
    #   $assign  : $name -> literal URI strings assigned to it
    #   $splat   : $name -> literal URI strings held in the hashtable's Uri key (for @splatting)
    $assign = @{}
    $splat = @{}
    foreach ($a in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        if ($a.Left -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
        $name = $a.Left.VariablePath.UserPath
        $rhs = $a.Right
        if ($rhs -is [System.Management.Automation.Language.CommandExpressionAst]) { $rhs = $rhs.Expression }

        if ($rhs -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
            $rhs -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
            # '+=' appends a query fragment ('?$filter=...'); only a real path segment is a URI.
            if ($rhs.Value -like '/*') {
                if (-not $assign.ContainsKey($name)) { $assign[$name] = @() }
                $assign[$name] += $rhs.Value
            }
        }
        elseif ($rhs -is [System.Management.Automation.Language.HashtableAst]) {
            foreach ($pair in $rhs.KeyValuePairs) {
                if ($pair.Item1.Extent.Text.Trim("'", '"') -ne 'Uri') { continue }
                $v = $pair.Item2
                if ($v -is [System.Management.Automation.Language.PipelineAst]) { $v = $v.PipelineElements[0] }
                if ($v -is [System.Management.Automation.Language.CommandExpressionAst]) { $v = $v.Expression }
                if ($v -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                    $v -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                    if (-not $splat.ContainsKey($name)) { $splat[$name] = @() }
                    $splat[$name] += $v.Value
                }
            }
        }
    }

    $cmds = $ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.CommandAst] -and
        $n.GetCommandName() -eq 'Invoke-GkGraphRequest'
    }, $true)

    foreach ($c in $cmds) {
        $method = 'GET'; $uriAst = $null; $splatName = $null
        $elems = $c.CommandElements
        for ($i = 0; $i -lt $elems.Count; $i++) {
            $el = $elems[$i]
            if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
                $val = if ($el.Argument) { $el.Argument } elseif ($i + 1 -lt $elems.Count) { $elems[$i + 1] } else { $null }
                if ($el.ParameterName -eq 'Method' -and $val) { $method = $val.Extent.Text.Trim("'", '"') }
                if ($el.ParameterName -eq 'Uri' -and $val) { $uriAst = $val }
            }
            elseif ($el -is [System.Management.Automation.Language.VariableExpressionAst] -and $el.Splatted) {
                $splatName = $el.VariablePath.UserPath
            }
        }

        # Literal URI, a variable resolving to one, or the Uri key of a splatted hashtable.
        $literals = @()
        $sourceText = ''
        if ($uriAst -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
            $uriAst -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
            $literals = @($uriAst.Value); $sourceText = $uriAst.Extent.Text
        }
        elseif ($uriAst -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $n = $uriAst.VariablePath.UserPath
            $sourceText = $uriAst.Extent.Text
            if ($assign.ContainsKey($n)) { $literals = @($assign[$n]) }
        }
        elseif ($splatName) {
            $sourceText = "@$splatName"
            if ($splat.ContainsKey($splatName)) { $literals = @($splat[$splatName]) }
        }
        else { continue }   # not a Graph call we can attribute a URI to

        if ($literals.Count -eq 0) {
            [pscustomobject]@{
                Cmdlet = $file.BaseName; Method = $method.ToUpper()
                Path = '<UNRESOLVED>'; Source = $sourceText
            }
            continue
        }
        foreach ($lit in $literals) {
            [pscustomobject]@{
                Cmdlet = $file.BaseName; Method = $method.ToUpper()
                Path = ConvertTo-GraphPath $lit; Source = $lit
            }
        }
    }
}

$rows = $rows | Sort-Object Cmdlet, Method, Path -Unique
$rows | Export-Csv $OutFile -NoTypeInformation -Encoding utf8

$unresolved = @($rows | Where-Object Path -eq '<UNRESOLVED>')
Write-Output "Calls: $($rows.Count)  across $(($rows.Cmdlet | Select-Object -Unique).Count) cmdlets"
Write-Output "Unresolved: $($unresolved.Count)"
if ($unresolved) { $unresolved | ForEach-Object { "  $($_.Cmdlet): $($_.Source)" } }
Write-Output ""
Write-Output "Distinct endpoints: $((@($rows | Where-Object Path -ne '<UNRESOLVED>') | ForEach-Object { "$($_.Method) $($_.Path)" } | Select-Object -Unique).Count)"
