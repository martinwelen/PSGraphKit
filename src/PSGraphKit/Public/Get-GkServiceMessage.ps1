function Get-GkServiceMessage {
    <#
    .SYNOPSIS
        Report Microsoft 365 message center posts — the change announcements that need action.

    .DESCRIPTION
        Reads GET /admin/serviceAnnouncement/messages and surfaces the message center in a form you
        can filter and export. The value is in -ActionRequiredOnly combined with -ByDays: the posts
        with a deadline are the ones that turn into an incident if nobody reads them.

        The message body is long HTML, so it is omitted by default; pass -IncludeBody to keep it.
        Requires the ServiceMessage.Read.All scope, which is the only permission Graph accepts here.

    .PARAMETER Service
        Only return messages for services whose name contains this text (case-insensitive).

    .PARAMETER Category
        Only return messages in this category.

    .PARAMETER ActionRequiredOnly
        Only return messages flagged as requiring admin action by a deadline.

    .PARAMETER ByDays
        Only return messages whose action deadline falls within this many days.

    .PARAMETER First
        Return at most this many messages.

    .PARAMETER IncludeBody
        Keep the message body. It is long HTML — useful for export, noisy on screen.

    .PARAMETER AsReport
        Add a ReportGeneratedUtc column.

    .EXAMPLE
        Get-GkServiceMessage -ActionRequiredOnly -ByDays 30

        Everything with an admin deadline inside a month.

    .EXAMPLE
        Get-GkServiceMessage -Category planForChange -Service Exchange

        Upcoming Exchange changes.

    .EXAMPLE
        Get-GkServiceMessage -ActionRequiredOnly -AsReport | Export-Csv .\message-center.csv -NoTypeInformation

    .OUTPUTS
        PSGraphKit.ServiceMessage
    #>
    [CmdletBinding()]
    [OutputType('PSGraphKit.ServiceMessage')]
    param(
        [string] $Service,

        [ValidateSet('preventOrFixIssue', 'planForChange', 'stayInformed', 'unknownFutureValue')]
        [string] $Category,

        [switch] $ActionRequiredOnly,

        [int] $ByDays,

        [int] $First,

        [switch] $IncludeBody,

        [switch] $AsReport
    )

    begin {
        Test-GkConnection -FunctionName 'Get-GkServiceMessage' -Caller $PSCmdlet | Out-Null
        $now = [datetime]::UtcNow
    }

    process {
        # category filters server-side; the rest is client-side (Graph does not support them here).
        $uri = '/admin/serviceAnnouncement/messages'
        if ($Category) { $uri += "?`$filter=category eq '$Category'" }

        $params = @{ Uri = $uri; CallerFunction = 'Get-GkServiceMessage' }
        if ($PSBoundParameters.ContainsKey('First')) { $params['MaxResult'] = $First }

        $messages = Invoke-GkGraphRequest @params

        foreach ($m in $messages) {
            $svc = [string](Get-GkDictValue $m 'services')
            if (-not $svc) { $svc = (@(Get-GkDictValue $m 'services') -join ', ') }
            $actionBy = ConvertTo-GkDateTime (Get-GkDictValue $m 'actionRequiredByDateTime')
            $isAction = ($null -ne $actionBy)

            if ($Service -and $svc -notlike "*$Service*") { continue }
            if ($ActionRequiredOnly -and -not $isAction) { continue }
            if ($PSBoundParameters.ContainsKey('ByDays')) {
                if ($null -eq $actionBy) { continue }
                if (($actionBy - $now).TotalDays -gt $ByDays) { continue }
            }

            $daysLeft = if ($null -ne $actionBy) { [int][math]::Floor(($actionBy - $now).TotalDays) } else { $null }

            $obj = [ordered]@{
                PSTypeName       = 'PSGraphKit.ServiceMessage'
                Id               = [string](Get-GkDictValue $m 'id')
                Title            = [string](Get-GkDictValue $m 'title')
                Services         = $svc
                Category         = [string](Get-GkDictValue $m 'category')
                Severity         = [string](Get-GkDictValue $m 'severity')
                IsMajorChange    = Get-GkDictValue $m 'isMajorChange'
                ActionRequiredBy = $actionBy
                DaysUntilAction  = $daysLeft
                LastModified     = ConvertTo-GkDateTime (Get-GkDictValue $m 'lastModifiedDateTime')
            }
            if ($IncludeBody) {
                $body = Get-GkDictValue $m 'body'
                $obj['Body'] = [string](Get-GkDictValue $body 'content')
            }
            if ($AsReport) { $obj['ReportGeneratedUtc'] = $now }
            [pscustomobject]$obj
        }
    }
}
