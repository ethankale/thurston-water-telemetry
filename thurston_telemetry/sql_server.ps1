
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

function Update-DailySQLTable {
    <#
    .SYNOPSIS
    Run an update query on a daily summary table in GData.

    .DESCRIPTION
    In addition to the *gauging tables, GData has *daily tables, which store
    summaries of the raw data by day.  Each parameter (flow, rain, etc.) has 
    a unique table.

    This function runs an update query on the selected daily table for the
    date span and monitoring site specified.
    #>
    [CmdletBinding()]

    Param([string]$SQLServer, [string]$SQLDB, [string]$table, [string]$gid, [DateTime]$BeginDate, [DateTime]$EndDate)

    $LakeQuery = "
    MERGE INTO tblLakeLevelDaily as l
    USING (
        SELECT G_ID, 
            convert(date, DATEADD([minute], - (L_UTCOffset*60), L_TimeDate)) as Date_Time,
            AVG(L_Level) AS Mean, 
            MIN(L_Level) AS Minimum, 
            MAX(L_Level) AS Maximum, 
            MAX(CONVERT(int, L_Est)) AS Estimate, 
            MAX(L_TimeDate) AS DTStamp, 
            MAX(CONVERT(int, L_Warning)) AS Warning, 
            COUNT(L_TimeDate) AS RecCount, 
            MAX(CONVERT(int, L_Provisional)) AS Provisional
        FROM tblLakeLevelGauging
            WHERE (G_ID = $gid)
            AND L_TimeDate >= `"$BeginDate`"
            AND L_TimeDate <= `"$EndDate`"
        GROUP BY G_ID, 
            convert(date, DATEADD([minute], - (L_UTCOffset*60), L_TimeDate))) as g
    ON g.G_ID = l.G_ID AND g.Date_Time = l.L_Date
    WHEN MATCHED
        THEN UPDATE SET L_MeanLevel = Mean,
            L_MinLevel = Minimum,
            L_MaxLevel = Maximum,
            L_Estimate = Estimate,
            AutoDTStamp = DTStamp,
            L_Warning = Warning,
            L_RecCount = RecCount,
            L_Provisional = Provisional
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (G_ID, L_Date, L_MeanLevel, L_MinLevel, L_MaxLevel,
            L_Estimate, AutoDTStamp, L_Warning, L_RecCount, L_Provisional)
        VALUES (G_ID, Date_Time, Mean, Minimum, Maximum, 
            Estimate, DTStamp, Warning, RecCount, Provisional);"

    $StageQuery = "
    MERGE INTO dbo.tblDischargeDaily as pd
    USING (
        SELECT G_ID, 
            convert(date, DATEADD([minute], - (D_UTCOffset*60), D_TimeDate)) as Date_Time,
            AVG(D_Stage) AS MeanStage, 
            MIN(D_Stage) AS MinimumStage, 
            MAX(D_Stage) AS MaximumStage, 
            MAX(CONVERT(int, D_Est)) AS Estimate, 
            MAX(D_TimeDate) AS DTStamp, 
            MAX(CONVERT(int, D_Warning)) AS Warning, 
            COUNT(D_TimeDate) AS RecCount, 
            MAX(CONVERT(int, D_Provisional)) AS Provisional
        FROM tblDischargeGauging
            WHERE (G_ID = $gid)
            AND D_TimeDate >= '$BeginDate'
            AND D_TimeDate <= '$EndDate'
        GROUP BY G_ID, 
            convert(date, DATEADD([minute], - (D_UTCOffset*60), D_TimeDate))) as g
    ON g.G_ID = pd.G_ID AND g.Date_Time = pd.D_Date
    WHEN MATCHED
        THEN UPDATE SET D_MeanStage = MeanStage,
            D_MinStage = MinimumStage,
            D_MaxStage = MaximumStage,
            D_Estimate = Estimate,
            AutoDTStamp = DTStamp,
            D_Warning = Warning,
            D_RecCount = RecCount,
            D_Provisional = Provisional
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (G_ID, D_Date, D_MeanStage, D_MinStage, D_MaxStage,
            D_Estimate, AutoDTStamp, D_Warning, D_RecCount, D_Provisional)
        VALUES (G_ID, Date_Time, MeanStage, MinimumStage, MaximumStage, 
            Estimate, DTStamp, Warning, RecCount, Provisional);"

    $TempQuery = "
    MERGE INTO tblWaterTempDaily as t
    USING (
        SELECT G_ID, 
            convert(date, DATEADD([minute], - (W_UTCOffset*60), W_TimeDate)) as Date_Time,
            AVG(W_ValueCorrected) AS Mean, 
            MIN(W_ValueCorrected) AS Minimum, 
            MAX(W_ValueCorrected) AS Maximum, 
            MAX(CONVERT(int, W_Est)) AS Estimate, 
            MAX(W_TimeDate) AS DTStamp, 
            MAX(CONVERT(int, W_Warning)) AS Warning, 
            COUNT(W_TimeDate) AS RecCount, 
            MAX(CONVERT(int, W_Provisional)) AS Provisional
        FROM tblWaterTempGauging
            WHERE (G_ID = $gid)
            AND W_TimeDate >= '$BeginDate'
            AND W_TimeDate <= '$EndDate'
        GROUP BY G_ID, 
            convert(date, DATEADD([minute], - (W_UTCOffset*60), W_TimeDate))) as g
    ON g.G_ID = t.G_ID AND g.Date_Time = t.W_Date
    WHEN MATCHED
        THEN UPDATE SET W_Mean = Mean,
            W_Min = Minimum,
            W_Max = Maximum,
            W_Estimate = Estimate,
            AutoDTStamp = DTStamp,
            W_Warning = Warning,
            W_RecCount = RecCount,
            W_Provisional = Provisional
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (G_ID, W_Date, W_Mean, W_Min, W_Max,
            W_Estimate, AutoDTStamp, W_Warning, W_RecCount, W_Provisional)
        VALUES (G_ID, Date_Time, Mean, Minimum, Maximum, 
            Estimate, DTStamp, Warning, RecCount, Provisional);"

    $PiezoQuery = "
    MERGE INTO dbo.tblPiezometerDaily as pd
    USING (
        SELECT G_ID, 
            convert(date, DATEADD([minute], - (P_UTCOffset*60), P_TimeDate)) as Date_Time,
            AVG(P_Level) AS Mean, 
            MIN(P_Level) AS Minimum, 
            MAX(P_Level) AS Maximum, 
            MAX(CONVERT(int, P_Est)) AS Estimate, 
            MAX(P_TimeDate) AS DTStamp, 
            MAX(CONVERT(int, P_Warning)) AS Warning, 
            COUNT(P_TimeDate) AS RecCount, 
            MAX(CONVERT(int, P_Provisional)) AS Provisional
        FROM tblPiezometerGauging
            WHERE (G_ID = $gid)
            AND P_TimeDate >= '$BeginDate'
            AND P_TimeDate <= '$EndDate'
        GROUP BY G_ID, 
            convert(date, DATEADD([minute], - (P_UTCOffset*60), P_TimeDate))) as g
    ON g.G_ID = pd.G_ID AND g.Date_Time = pd.P_Date
    WHEN MATCHED
        THEN UPDATE SET P_MeanLevel = Mean,
            P_MinLevel = Minimum,
            P_MaxLevel = Maximum,
            P_Estimate = Estimate,
            AutoDTStamp = DTStamp,
            P_Warning = Warning,
            P_RecCount = RecCount,
            P_Provisional = Provisional
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (G_ID, P_Date, P_MeanLevel, P_MinLevel, P_MaxLevel,
            P_Estimate, AutoDTStamp, P_Warning, P_RecCount, P_Provisional)
        VALUES (G_ID, Date_Time, Mean, Minimum, Maximum, 
            Estimate, DTStamp, Warning, RecCount, Provisional);"

    $BaroQuery = "
    MERGE INTO dbo.tblBarometerDaily as bd
    USING (
        SELECT G_ID, 
            convert(date, DATEADD([minute], - (B_UTCOffset*60), B_TimeDate)) as Date_Time,
            AVG(B_Value) AS Mean, 
            MIN(B_Value) AS Minimum, 
            MAX(B_Value) AS Maximum, 
            MAX(CONVERT(int, B_Est)) AS Estimate, 
            MAX(CONVERT(int, B_Lock)) AS Baro_Lock, 
            MAX(CONVERT(int, B_Warning)) AS Warning, 
            COUNT(B_TimeDate) AS RecCount, 
            MAX(CONVERT(int, B_Provisional)) AS Provisional
        FROM tblBarometerGauging
            WHERE (G_ID = $gid)
            AND B_TimeDate >= '$BeginDate'
            AND B_TimeDate <= '$EndDate'
        GROUP BY G_ID, 
            convert(date, DATEADD([minute], - (B_UTCOffset*60), B_TimeDate))) as g
    ON g.G_ID = bd.G_ID AND g.Date_Time = bd.B_Date
    WHEN MATCHED
        THEN UPDATE SET B_Mean = Mean,
            B_Min = Minimum,
            B_Max = Maximum,
            B_Estimate = Estimate,
            B_Lock = Baro_Lock,
            B_Warning = Warning,
            B_RecCount = RecCount,
            B_Provisional = Provisional
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (G_ID, B_Date, B_Mean, B_Min, B_Max,
            B_Estimate, B_Warning, B_RecCount, B_Provisional)
        VALUES (G_ID, Date_Time, Mean, Minimum, Maximum, 
            Estimate, Warning, RecCount, Provisional);"

    $query = switch($table) {
        'tblDischargeDaily'  { $StageQuery }
        'tblLakeLevelDaily'  { $LakeQuery }
        'tblTempDaily'       { $TempQuery }
        'tblPiezometerDaily' { $PiezoQuery }
        'tblBarometerDaily'  { $BaroQuery }
    }
    #return $query
    Invoke-Sqlcmd -Query $query -ServerInstance $SQLServer -Database $SQLDB
}
