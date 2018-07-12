
# SQL Server functions used in Thurston County water telemetry.

function Import-TableToSQL {
    <# 
    .SYNOPSIS
    Uploads a properly formatted DataTable to a SQL Server table.

    .DESCRIPTION
    Given a DataTable with a structure that matches a destination
    table in SQL Server, this function appends the data in the input DataTable
    to the SQL Server table.
    #>
    [CmdletBinding()]

    Param($InTable, [string]$ConnString, [string]$DestTable, $mapping)

    $bulkCopy = new-object ("Data.SqlClient.SqlBulkCopy") $ConnString
    foreach ($key in $mapping.keys) {
        $bulkCopy.ColumnMappings.Add($mapping[$key], $key) | Out-Null
    }

    $bulkCopy.DestinationTableName = $DestTable
    $bulkCopy.WriteToServer($InTable)

    $bulkCopy.Close()

}