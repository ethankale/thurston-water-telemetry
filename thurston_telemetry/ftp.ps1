
# FTP functions used in Thurston County water telemetry.

function New-FTPFileList {
    <#
    .SYNOPSIS
    Lists files in a specific directory on a given FTP server.
    
    .DESCRIPTION
    Given a user name, password, server, and directory, this function returns 
    just the top-level files in that directory.  It is NOT recursive, and it 
    is NOT designed to handle subdirectories.

    .PARAMETER User
    Username
    .PARAMETER Pass
    Password
    .PARAMETER Svr
    Server URI, including ftp:// and trailing backslash, 
    like ftp://ftp.co.thurston.wa.us/
    .PARAMETER Dir
    Directory, with no preceding or trailing backslash, 
    like directory/to/list

    #>
    [CmdletBinding()]
    
    Param([string]$User, [string]$Pass, [string]$Svr, [string]$Dir)
    
    $uri = "$Svr$Dir"
    
    $FTPRequest = [System.Net.FtpWebRequest]::Create("$uri")
    $FTPRequest.Credentials = New-Object System.Net.NetworkCredential($User,$Pass)
    $FTPRequest.Method = [System.Net.WebRequestMethods+FTP]::ListDirectoryDetails

    $FTPRequest.UseBinary = $False
    $FTPRequest.KeepAlive = $False

    $FTPResponse = $FTPRequest.GetResponse()
    $ResponseStream = $FTPResponse.GetResponseStream()

    $StreamReader = New-Object System.IO.Streamreader $ResponseStream
    $Files = New-Object System.Collections.ArrayList
    While ($file = $StreamReader.ReadLine())
     {
       $filename = $file.split()[-1]
       [void] $Files.add("$filename")
       #Write-Debug $file
    }
    $StreamReader.Close()
    $ResponseStream.Close()
    $FTPResponse.Close()
    
    Return $Files
}

function Remove-FTPFile {
    <#
    .SYNOPSIS
    Given the appropriate credentials & path, delete a file from FTP.
    #>
    [CmdletBinding()]

    Param([string]$User, [string]$Pass, [string]$Svr, [string]$FilePath)

    $request = [Net.WebRequest]::Create("$Svr$FilePath")
    $request.Credentials = New-Object System.Net.NetworkCredential($User,$Pass)
    $request.Method = [System.Net.WebRequestMethods+Ftp]::DeleteFile
    $request.GetResponse() | out-null

}

