# Get-GkAuthStrengthPolicy

## SYNOPSIS
Report authentication strength policies (built-in and custom) and their allowed method
combinations.

## SYNTAX
```
Get-GkAuthStrengthPolicy [-CustomOnly] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /policies/authenticationStrengthPolicies, which back the "require authentication
strength" grant control in Conditional Access. Shows each policy's type and the method
combinations it accepts (e.g. fido2, x509CertificateMultiFactor) — useful for confirming a
phishing-resistant option is defined for privileged access.

Requires Policy.Read.AuthenticationMethod (or Policy.Read.All).

## EXAMPLES

### Example 1
```powershell
Get-GkAuthStrengthPolicy
```
All authentication strength policies with their allowed combinations.

### Example 2
```powershell
Get-GkAuthStrengthPolicy -CustomOnly
```
Only custom strengths the tenant has defined.

### Example 3
```powershell
Get-GkAuthStrengthPolicy -AsReport | Export-Csv .\auth-strengths.csv -NoTypeInformation
```

## PARAMETERS

### -CustomOnly
Return only custom (tenant-defined) policies.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Flatten AllowedCombinations to a '; '-joined string and add ReportGeneratedUtc.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### CommonParameters
This cmdlet supports the common parameters: -Verbose, -Debug, -ErrorAction, -ErrorVariable, -WarningAction, -WarningVariable, -OutVariable, -OutBuffer, and -PipelineVariable. For more information, see about_CommonParameters.

## INPUTS
### None

## OUTPUTS
### PSGraphKit.AuthStrengthPolicy
