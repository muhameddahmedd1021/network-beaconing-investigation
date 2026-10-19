param([string]$StartUtc,[string]$EndUtc,[string]$Output)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $Output -Force | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$json = New-Object IO.StreamWriter("$Output\events.jsonl",$false,$utf8)
$raw = New-Object IO.StreamWriter("$Output\events.xml",$false,$utf8)
$raw.WriteLine('<Events>')
try {
    foreach($channel in @('Microsoft-Windows-Sysmon/Operational','Microsoft-Windows-PowerShell/Operational','Security')) {
        $filter = @{LogName=$channel;StartTime=[datetime]::Parse($StartUtc);EndTime=[datetime]::Parse($EndUtc)}
        if($channel -eq 'Security') { $filter.Id = @(4688) }
        elseif($channel -like '*Sysmon*') { $filter.Id = @(1,3,11) }
        else { $filter.Id = @(4104) }
        $events = @(Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue)
        foreach($event in $events | Sort-Object TimeCreated,RecordId) {
            $text = $event.ToXml();[xml]$x = $text
            $fields = [ordered]@{}
            foreach($d in $x.Event.EventData.Data) {
                if([string]$d.Name) { $fields[[string]$d.Name] = [string]$d.'#text' }
            }
            $row = [ordered]@{utc=$event.TimeCreated.ToUniversalTime().ToString('o');event_id=$event.Id;provider=$event.ProviderName;channel=$channel;computer=$event.MachineName;record_id=$event.RecordId;event_process_id=[string]$x.Event.System.Execution.ProcessID;event_user_sid=[string]$x.Event.System.Security.UserID;data=$fields}
            $json.WriteLine(($row | ConvertTo-Json -Depth 12 -Compress));$raw.WriteLine($text)
        }
    }
} finally { $raw.WriteLine('</Events>');$raw.Dispose();$json.Dispose() }
Compress-Archive -LiteralPath "$Output\events.jsonl","$Output\events.xml" -DestinationPath "$Output\events.zip" -Force
