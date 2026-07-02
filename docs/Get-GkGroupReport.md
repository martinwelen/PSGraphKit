# Get-GkGroupReport

## SYNOPSIS
Report groups with their type (Microsoft 365 / security / distribution / dynamic),
membership count, owners, and an ownerless flag.

## SYNTAX
```
Get-GkGroupReport [[-GroupType] <string>] [-OwnerlessOnly] [-SkipMemberCount] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /groups and classifies each group from groupTypes/securityEnabled/mailEnabled.
For each group it also fetches the membership count (GET /groups/{id}/members/$count, which
requires the ConsistencyLevel: eventual header) and the owners (GET /groups/{id}/owners),
flagging ownerless groups.

Caveat on ownerless detection: owners are not returned by Graph for groups created in
Exchange, distribution groups, or on-premises-synced groups, so IsOwnerless can be a false
positive for those. The GroupType column lets you account for that.

Membership counting is one call per group; use -SkipMemberCount to omit it on large tenants.

## EXAMPLES

### Example 1
```powershell
Get-GkGroupReport -OwnerlessOnly | Where-Object GroupType -eq 'Microsoft365'
```
Ownerless Microsoft 365 groups — a governance cleanup list.

### Example 2
```powershell
Get-GkGroupReport | Sort-Object MemberCount -Descending | Select-Object -First 20
```
The 20 largest groups by membership.

### Example 3
```powershell
Get-GkGroupReport -SkipMemberCount -AsReport | Export-Csv .\groups.csv -NoTypeInformation
```

## PARAMETERS

### -GroupType
Client-side filter: All (default), Microsoft365, Security, MailEnabledSecurity, or Distribution.

```yaml
Type: String
Required: false
Position: 1
Default value: All
Accept pipeline input: false
```

### -OwnerlessOnly
Return only groups with no owners (see the ownerless caveat above).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -SkipMemberCount
Do not fetch per-group membership counts (MemberCount will be $null).

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -AsReport
Flatten Owners to a '; '-joined string and add ReportGeneratedUtc.

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
### PSGraphKit.GroupReport
