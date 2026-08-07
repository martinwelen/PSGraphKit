# Get-GkServiceMessage

## SYNOPSIS
Report Microsoft 365 message center posts — the change announcements that need action.

## SYNTAX
```
Get-GkServiceMessage [[-Service] <string>] [[-Category] <string>] [[-ByDays] <int>] [[-First] <int>] [-ActionRequiredOnly] [-IncludeBody] [-AsReport] [<CommonParameters>]
```

## DESCRIPTION
Reads GET /admin/serviceAnnouncement/messages and surfaces the message center in a form you
can filter and export. The value is in -ActionRequiredOnly combined with -ByDays: the posts
with a deadline are the ones that turn into an incident if nobody reads them.

The message body is long HTML, so it is omitted by default; pass -IncludeBody to keep it.
Requires the ServiceMessage.Read.All scope, which is the only permission Graph accepts here.

## EXAMPLES

### Example 1
```powershell
Get-GkServiceMessage -ActionRequiredOnly -ByDays 30
```
Everything with an admin deadline inside a month.

### Example 2
```powershell
Get-GkServiceMessage -Category planForChange -Service Exchange
```
Upcoming Exchange changes.

### Example 3
```powershell
Get-GkServiceMessage -ActionRequiredOnly -AsReport | Export-Csv .\message-center.csv -NoTypeInformation
```

## PARAMETERS

### -Service
Only return messages for services whose name contains this text (case-insensitive).

```yaml
Type: String
Required: false
Position: 1
Default value: None
Accept pipeline input: false
```

### -Category
Only return messages in this category.

```yaml
Type: String
Required: false
Position: 2
Default value: None
Accept pipeline input: false
```

### -ActionRequiredOnly
Only return messages flagged as requiring admin action by a deadline.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
Accept pipeline input: false
```

### -ByDays
Only return messages whose action deadline falls within this many days.

```yaml
Type: Int32
Required: false
Position: 3
Default value: 0
Accept pipeline input: false
```

### -First
Return at most this many messages.

```yaml
Type: Int32
Required: false
Position: 4
Default value: 0
Accept pipeline input: false
```

### -IncludeBody
Keep the message body. It is long HTML — useful for export, noisy on screen.

```yaml
Type: SwitchParameter
Required: false
Position: named
Default value: False
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
### PSGraphKit.ServiceMessage
