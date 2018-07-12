
# Functions specific to In-Situ instruments.

function ConvertFrom-InSituToCSV {
    <# 
    .SYNOPSIS
    Take a string of content read from an In-Situ text file, and
    return a string of the data in .csv format.

    .DESCRIPTION
    In-Situ uses a non-standard format in their telemetry files, 
    with metadata embedded at the beginning and end of the file 
    and a CSV formatted table sandwiched in between.  This function
    strips the metadata and returns just the CSV portion.
    #>
    [CmdletBinding()]
    
    Param([string]$FileContent)
    
    $EndIdx = $FileContent.IndexOf("---")
    $CSVInterim = $FileContent.Substring(0, $EndIdx)
    
    $StartIdx = $FileContent.IndexOf("Record n,")
    $CSV = $CSVInterim.Substring($StartIdx)
    
    return $CSV
}

function ConvertFrom-InSituCSVToTable {
    <#
    .SYNOPSIS
    Convert In-Situ formatted CSV input into GData-formatted table output.

    .DESCRIPTION
    Once the csv data have been extracted with ConvertInSituToCSV, this 
    function reads a .csv file (NOT CSV formatted text) and reformats
    it into DataTables with columns that more closely match the corresponding
    GData tables.

    Uploading to GData still requires the use of an appropriate mapping; see
    the New-InSituMap function.
    #>
    [CmdletBinding()]

    Param([string]$csvfile, [string]$gid)

    $csvdelimiter = ","
    $firstRowColumns = $true
 
    # Do it
    $ds = New-Object System.Data.DataSet
    $dt = New-Object System.Data.Datatable
    $reader = New-Object System.IO.StreamReader $csvfile
    $columnString = Get-Content $csvfile -First 1
    
    # Kind hacky, but In-Situ reuses a column title, and CSV parsers can't handle 
    # that (because it's dumb)
    [regex]$pattern = 'Sensor n'
    $columnStringFixed = $pattern.replace($columnString, 'Sensor a', 1)

    $columns = $columnStringFixed.Split($csvdelimiter)
 
    foreach ($column in $columns) {
        if ($firstRowColumns -eq $true) { 
            [void]$dt.Columns.Add($column)
        } else { [void]$dt.Columns.Add() }
    }

    # Read in the data, line by line
    $reader.ReadLine()
    while (($line = $reader.ReadLine()) -ne $null)  {
        if ($line.length -gt 0) {[void]$dt.Rows.Add($line.Split($csvdelimiter))}
    }
    
    $reader.Close()
    
    ###########
    # Transform
    ###########
    
    # Reshape the csv to match the SQL Server table
    $dt.Columns.Add('G_ID', [string]).SetOrdinal(0)
    $dt.Columns.Add('DateTime', [datetime]).SetOrdinal(1)
    $dt.Columns.Add('UTC_Offset', [int]).SetOrdinal(2)
    $dt.Columns.Add('Est', [int]).SetOrdinal(5)
    $dt.Columns.Add('Lock', [int]).SetOrdinal(6)
    $dt.Columns.Add('Warning', [int]).SetOrdinal(7)
    $dt.Columns.Add('Provisional', [int]).SetOrdinal(8)


    foreach ($r in $dt.Rows) {
        $datetime = ([datetime]::ParseExact(($r['Date'] + $r['Time']), 'dd/MM/yyyyHH:mm', $null))
        $r['DateTime'] = $datetime.AddHours(8)
        $r['G_ID'] = $gid
        $r['UTC_Offset'] = 8
        $r['Est'] = 0
        $r['Lock'] = 0
        $r['Warning'] = 0
        $r['Provisional'] = 1
    }
    
    $columnsToRemove = @("Record n", "Sensor a", "Sensor n", "Pressure(PSI)[2:17]", "Date", "Time")
    foreach ($col in $columnsToRemove) {
        if ($dt.Columns.IndexOf($col) -gt -1) { 
            $dt.Columns.Remove($col) 
        }
    }
    
    return ,$dt
}

function New-InSituMap {
    <#
    .SYNOPSIS
    Given the correct parameter, returns the In-Situ datatable mapping
    as a hash table.

    .DESCRIPTION
    The hashtable created by this function can be used to create a mapping
    between an origin table (a table of data from an In-Situ logger) and
    a destination table in GData.  The same input may need to be mapped
    to different output tables to load different parameters into GData.
    #>
    [CmdletBinding()]

    Param([string]$param)

    $mapping = @{}

    if ($param -eq 'stage') {
        $mapping = @{
            G_ID = 'G_ID'
            D_TimeDate = 'DateTime'
            D_UTCOffset = 'UTC_Offset'
            D_Value = 'Surface Elevation(ft)[5:38]'
            D_Stage = 'Surface Elevation(ft)[5:38]'
            D_Est = 'Est'
            D_Lock = 'Lock'
            D_Warning = 'Warning'
            D_Provisional = 'Provisional'
        }
    } elseif ($param -eq 'temperature') {
        $mapping = @{
            G_ID = 'G_ID'
            W_TimeDate = 'DateTime'
            W_UTCOffset = 'UTC_Offset'
            W_Value = 'Temperature(°C)[1:1]'
            W_ValueCorrected = 'Temperature(°C)[1:1]'
            W_Est = 'Est'
            W_Ice = 'Est' # Basically, assign "ice" to 0
            W_Lock = 'Lock'
            W_Warning = 'Warning'
            W_Provisional = 'Provisional'
        }
    } elseif ($param -eq 'pressure') {
        $mapping = @{
            G_ID = 'G_ID'
            B_TimeDate = 'DateTime'
            B_UTCOffset = 'UTC_Offset'
            B_Value = 'Pressure(mBar)[2:21]' # GData takes millibar units
            B_Est = 'Est'
            B_Lock = 'Lock'
            B_Warning = 'Warning'
            B_Provisional = 'Provisional'
        }
    } else {
        Throw 'Bad -param value supplied to Create-InSituMap' 
    }

    return $mapping
}
