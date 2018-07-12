
# Nat Kale | 2018-07-06

Import-Module ..\thurston_telemetry -Force

########
# Config
########

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

$config = (Get-Content -Raw $PSScriptRoot\config.json) | ConvertFrom-Json

# FTP
$Username = $config."ftp-user"
$Password = $config."ftp-pass"
$Server = $config."ftp-url"
$ServerDir = $config."ftp-dir"

# SQL
$SQLConnString = $config."sql-connStr"

# Local
$LocalDir = $config."temp-dir"

#####################
# Connect to FTP site
#####################

$FilesToDownload = New-FTPFileList -User $Username -Pass $Password -Svr $Server -Dir $ServerDir

$webclient = New-Object System.Net.WebClient
$webclient.Credentials = New-Object System.Net.NetworkCredential($Username, $Password) 

######################
# Load data from files
######################

foreach ($file in $FilesToDownload) {
    $RemoteFile = "$Server$ServerDir/$file"
    $LocalFile = "$LocalDir$file"

    Write-Verbose "Downloading $RemoteFile..."
    $contents = $webclient.DownloadString($RemoteFile)
    $contents >> $LocalFile
    $CSV = ConvertFrom-InSituToCSV($contents)
    
    $CsvFilePath = "$($LocalDir)csv_$file"
    $CSV >> $CsvFilePath

    $table = ConvertFrom-InSituCSVToTable -csvfile $CsvFilePath -gid 965
    $mapStage = New-InSituMap -param 'stage'
    $mapTemp = New-InSituMap -param 'temperature'
    $mapPressure = New-InSituMap -param 'pressure'

    Write-Verbose "Uploading data to GData..."
    Import-TableToSQL -InTable $table[1] -ConnString $SQLConnString -DestTable "tblDischargeGauging" -mapping $mapStage
    #Import-TableToSQL -InTable $table[1] -ConnString $SQLConnString -DestTable "tblWaterTempGauging" -mapping $mapTemp
    #Import-TableToSQL -InTable $table[1] -ConnString $SQLConnString -DestTable "tblBarometerGauging" -mapping $mapPressure

    Write-Verbose "Deleting $RemoteFile..."
    Remove-FTPFile -User $Username -Pass $Password -Svr $Server -FilePath "$ServerDir/$file"
}

#########
# Cleanup
#########

Write-Verbose "Deleting local files from $LocalDir"
Remove-Item "$($LocalDir)*.*"



