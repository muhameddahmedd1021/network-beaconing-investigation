param([string]$Server = 'http://10.0.2.2:8766',[int]$Requests = 12)
$ErrorActionPreference = 'Stop'
$out = 'C:\ProgramData\MohamedLab\Network'
New-Item -ItemType Directory -Path $out -Force | Out-Null
for ($i = 1; $i -le $Requests; $i++) {
    $utc = (Get-Date).ToUniversalTime().ToString('o')
    $response = Invoke-WebRequest "$Server/health/check?seq=$i" -UseBasicParsing -UserAgent 'MohamedLab-Health/1.0'
    [pscustomobject]@{utc=$utc;sequence=$i;pid=$PID;status_code=$response.StatusCode} |
        ConvertTo-Json -Compress | Add-Content "$out\Health.jsonl" -Encoding UTF8
    if ($i -lt $Requests) { Start-Sleep -Seconds 4 }
}
