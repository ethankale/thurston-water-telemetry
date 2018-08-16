
# Nat Kale | 2018-07-06

Import-Module "$(Split-Path $PSScriptRoot)\thurston_telemetry" -Force

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
$SQLServer = $config."sql-server"
$SQLDB = $config."sql-database"
$SQLConnString = "Data Source=$SQLServer; Database=$SQLDB; Trusted_Connection=True;"

# Local
$LocalDir = $PSScriptRoot + $config."temp-dir"
$gid = $config."gid"

#####################
# Connect to FTP site
#####################

$FilesToDownload = New-FTPFileList -User $Username -Pass $Password -Svr $Server -Dir $ServerDir

$webclient = New-Object System.Net.WebClient
$webclient.Credentials = New-Object System.Net.NetworkCredential($Username, $Password) 

######################
# Load data from files
######################

$MinDate = @()
$MaxDate = @()

foreach ($file in $FilesToDownload) {
    $RemoteFile = "$Server$ServerDir/$file"
    $LocalFile = "$LocalDir$file"

    Write-Verbose "Downloading $RemoteFile..."
    $contents = $webclient.DownloadString($RemoteFile)
    $contents >> $LocalFile
    $CSV = ConvertFrom-InSituToCSV($contents)
    
    $CsvFilePath = "$($LocalDir)csv_$file"
    $CSV >> $CsvFilePath

    # The In-Situ instrument records stage, temperature, and barometric
    # pressure, so we'll write to each of those tables in GData.
    $table = ConvertFrom-InSituCSVToTable -csvfile $CsvFilePath -gid $gid
    $mapStage = New-InSituMap -param 'stage'
    $mapTemp = New-InSituMap -param 'temperature'
    $mapPressure = New-InSituMap -param 'pressure'

    # First, record the minimum and maximum dates in the file
    $MinDate += $table[1].Compute("Min(DateTime)", "Provisional=1")
    $MaxDate += $table[1].Compute("Max(DateTime)", "Provisional=1")

    Write-Verbose "Uploading data to GData..."
    Import-TableToSQL -InTable $table[1] -ConnString $SQLConnString -DestTable "tblDischargeGauging" -mapping $mapStage
    Import-TableToSQL -InTable $table[1] -ConnString $SQLConnString -DestTable "tblWaterTempGauging" -mapping $mapTemp
    Import-TableToSQL -InTable $table[1] -ConnString $SQLConnString -DestTable "tblBarometerGauging" -mapping $mapPressure

    Write-Verbose "Deleting $RemoteFile..."
    Remove-FTPFile -User $Username -Pass $Password -Svr $Server -FilePath "$ServerDir/$file"

    Write-Verbose "Adding file to archive..."
    & "$(Split-Path $PSScriptRoot)\7z\7za.exe" a archive.zip $LocalFile
}

#########
# Cleanup
#########


if ($MinDate.Length -eq 0) {
    Write-Verbose "No files found on FTP site; nothing to do."
} else {

    $FirstDateTime = ($MinDate | Sort-Object)[0]
    $LastDateTime  = ($MaxDate | Sort-Object)[-1]

    $MinDate | Out-String | Write-Debug
    $MaxDate | Out-String | Write-Debug

    $queryParams = @{
        'SQLServer'  = $SQLServer;
        'SQLDB'      = $SQLDB;
        'table'      = 'tblDischargeDaily';
        'gid'        = $gid;
        'BeginDate'  = $FirstDateTime;
        'EndDate'    = $LastDateTime
    }

    $tables = 'tblDischargeDaily', 'tblTempDaily', 'tblBarometerDaily'

    Write-Verbose "Updating daily tables from $FirstDateTime to $LastDateTime..."
    foreach ($t in $tables) {
        $queryParams['table'] = $t
        Update-DailySQLTable @queryParams
    }

    Write-Verbose "Deleting local files from $LocalDir"
    Remove-Item "$($LocalDir)*.*"
}
