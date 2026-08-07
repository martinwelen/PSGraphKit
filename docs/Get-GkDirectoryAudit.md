# Get-GkDirectoryAudit

## SYNOPSIS
Report directory audit events (who changed what) over a recent window.

## SYNTAX
```
Get-GkDirectoryAudit [[-Days] <int>] [[-First] <int>] [[-InitiatedBy] <string>] [[-Category] <string>] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /auditLogs/directoryAudits filtered to the last -Days. Returns the activity, who
initiated it, the result, and the target(s). Optionally narrow to a single initiator.

Requires the AuditLog.Read.All scope. Retention is ~7 days (free) / ~30 days (P1/P2).

## EXAMPLES

### Example 1
```powershell
Get-GkDirectoryAudit -Days 3 -Category RoleManagement
```
Role-management changes in the last 3 days.

### Example 2
```powershell
Get-GkDirectoryAudit -InitiatedBy ada@contoso.com | Select-Object -First 20
```
Recent changes made by one admin.

### Example 3
```powershell
Get-GkDirectoryAudit -AsReport | Export-Csv .\directory-audit.csv -NoTypeInformation
```

## PARAMETERS

### -Days
Look-back window in days (default 7).

```yaml
Type: Int32
Required: false
Position: 1
Default value: 7
Accept pipeline input: false
```

### -First
Return only the N most-recent audit events in the window (Graph returns them newest-first),
stopping pagination early. Applied before the -InitiatedBy refinement. Use for a fast, bounded
look at a high-volume tenant.

```yaml
Type: Int32
Required: false
Position: 2
Default value: 0
Accept pipeline input: false
```

### -InitiatedBy
Filter to events initiated by a user (userPrincipalName).

```yaml
Type: String
Required: false
Position: 3
Default value: None
Accept pipeline input: false
```

### -Category
Filter to an audit category (e.g. UserManagement, RoleManagement, ApplicationManagement).

```yaml
Type: String
Required: false
Position: 4
Default value: None
Accept pipeline input: false
```

### -AsReport
Add a ReportGeneratedUtc column.

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
### PSGraphKit.DirectoryAudit
