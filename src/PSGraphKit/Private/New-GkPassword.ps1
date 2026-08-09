function New-GkPassword {
    <#
    .SYNOPSIS
        Generate a random password that satisfies the default Entra complexity policy.
    .DESCRIPTION
        Uses the cryptographic RNG, not Get-Random, because Get-Random is seeded from a predictable
        source and is not fit for credential material.

        Guarantees at least one character from each of the four classes Entra requires, then fills
        the remainder from the combined alphabet and shuffles, so the guaranteed characters do not
        always land in the same positions.

        Ambiguous glyphs (O/0, l/1/I) are excluded: these passwords get read aloud and typed by
        hand, and a reset that fails because someone read a zero as an O is a support call.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateRange(12, 128)]
        [int] $Length = 20
    )

    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'      # no I, O
    $lower = 'abcdefghijkmnpqrstuvwxyz'      # no l, o
    $digit = '23456789'                      # no 0, 1
    $symbol = '!#%&*+-=?@_'                  # shell- and CSV-safe

    $classes = @($upper, $lower, $digit, $symbol)
    $all = -join $classes

    # One from each class first, so complexity is guaranteed rather than probable.
    $chars = [System.Collections.Generic.List[char]]::new()
    foreach ($c in $classes) { $chars.Add((Get-GkRandomChar -Alphabet $c)) }
    while ($chars.Count -lt $Length) { $chars.Add((Get-GkRandomChar -Alphabet $all)) }

    # Fisher-Yates with crypto-random indices, so the guaranteed characters are not always first.
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $j = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(0, $i + 1)
        $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
    }

    return (-join $chars)
}

function Get-GkRandomChar {
    <#
    .SYNOPSIS
        Pick one character from an alphabet using the cryptographic RNG.
    #>
    [CmdletBinding()]
    [OutputType([char])]
    param(
        [Parameter(Mandatory)] [string] $Alphabet
    )
    return $Alphabet[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32(0, $Alphabet.Length)]
}
