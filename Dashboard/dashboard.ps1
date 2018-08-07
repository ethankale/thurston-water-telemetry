
# Nat Kale | 2018-08-07
# Copies the entire dashboard site from RSH2O to tcinternet

$remoteServer = "\\tcinternet"
$remotePath = "\stormwater-levels"
$localPath = "D:\Web_Water-Monitoring"

$config = (Get-Content -Raw $PSScriptRoot\config.json) | ConvertFrom-Json
$usr = $config."remote-user"
$pwd = $config."remote-pass"

net use $remoteServer$remotePath /user:$usr $pwd
try {
    robocopy $localPath $remoteServer$remotePath /MIR
} catch [System.Exception] {
    Write-Error "Could not copy dashboard.  $_.Exception.Message"
} finally {
    NET USE $remoteServer$remotePath /delete
}
