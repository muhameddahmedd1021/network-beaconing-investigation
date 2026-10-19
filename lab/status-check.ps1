param(
    [ValidateSet('Fixed','Jitter')][string]$Mode = 'Fixed',
    [string]$Server = 'http://10.0.2.2:8766',
    [int]$Requests = 12
)
$ErrorActionPreference = 'Stop'
$out = 'C:\ProgramData\MohamedLab\Network'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$delays = @(3,7,4,8,3,6,4,7,3,5,8,4)
for ($i = 1; $i -le $Requests; $i++) {
    $utc = (Get-Date).ToUniversalTime().ToString('o')
    $response = Invoke-WebRequest "$Server/beacon/status?mode=$Mode&seq=$i" -UseBasicParsing -UserAgent 'MohamedLab-Status/1.0'
    [pscustomobject]@{utc=$utc;mode=$Mode;sequence=$i;pid=$PID;status_code=$response.StatusCode} |
        ConvertTo-Json -Compress | Add-Content "$out\$Mode.jsonl" -Encoding UTF8
    if ($i -lt $Requests) {
        $delay = if ($Mode -eq 'Fixed') { 4 } else { $delays[($i-1) % $delays.Count] }
        Start-Sleep -Seconds $delay
    }
}
