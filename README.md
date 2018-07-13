Thurston County Stormwater Utility Telemetry
============================================

Purpose
-------
This repository contains all the Powershell scripts necessary to run the Thurston County water telemetry system.

Organization
------------
The repo is basically divided into two parts.  The thurston_telemetry subdirectory is a Powershell module, with all of the reusable function for downloading data from FTP, parsing data in proprietary formats, and uploading to the GData SQL Server.  There are (or will be; as of now there is just one) directories for each of the sites to be uploaded.  Those subdirectories each contain a Powershell script to do the uploading, a config.json file with all the sensitive info (usernames, passwords, directories), a temporary scratch directory for files downloaded from FTP, and an archive.zip that contains all the files downloaded thus far (if there is no archive.zip, the script will create it the first time it runs).

Creating a New Telemetry Site
-----------------------------
For sites with equipment that is identical (and identically configured) to existing site equipment, just do the following:

1. Copy an existing site subdirectory.
2. Delete the archive.zip file.
3. Modify the config.json file to point to the right location.
4. Modify the telemetry Powershell script to upload the data you want.
5. Update the SQL Server job by adding a new task to run the Powershell script.

For sites with equipment that differs (or is differently configured) from existing site equipment, you'll need to do 1-5 above, but you'll ALSO need to write custom parsing functions in the thurston_telemetry module to read the data.  See the In-Situ.ps1 file for an example of how to do that.