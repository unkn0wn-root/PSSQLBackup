<#
.SYNOPSIS
    Backup SQL Databases
.DESCRIPTION
    This function will backup all SQL databases. It accepts multiple databases to backup.
.EXAMPLE
    PS C:\> New-SQLBackup -Path '\\filesrv1\SQLBackup\' -Database DB01
    This command will backup DB01 database to \\filesrv01\SQLBackup path
.EXAMPLE
    PS C:\> New-SQLBackup -Path '\\filesrv1\SQLBackup\' -Database DB01,DB02,DB03
    This command will backup all three databases to \\filesrv01\SQLBackup path
.NOTES
    Author: David0 
    GitHub: unkn0wn-root
    Twitter: david0_shell
#>
#requires -RunAsAdministrator
#requires -Version 5

using module .\Classes\PSSQLBackupClass.ps1
using module .\Classes\LoggerClass.ps1
using namespace System.Collections.Generic
using namespace System.Net.Mail
using namespace System.IO

function New-PSSQLBackup {
    [CmdletBinding()]
    param (
        # Define SQLServer connection
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('ComputerName')]
        [string]$SQLServer = 'localhost',

        # Databases to backup
        [Parameter(
        Mandatory = $true, 
        Position = 1, 
        ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('SqlDB')]
        [string[]]$Database,

        # Backup Path
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_ -PathType 'Container'})]
        [string]$Path = (Get-Location)
    )
    
    begin {
    # This is the body formating for mail message in multi-line string with interpolation.
    # You can edit it as you want. It's just prettier when receiving mail.
    $Head = @"
    <style>
    TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
    TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #FF0000;}
    TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
    </style>
"@
    # Get configuration from json file
    $null = Get-PSSQLConfig
    $BackupResults = [List[psobject]]::new()
    [string]$timestamp = Get-Date -format yyyy-MM-dd-HHmmss
    # Check if backup log file exist, if not - create it
    [DirectoryInfo]$LogPath = "$env:SystemDrive\Temp\SQLDBBackup_log.txt"
        if (-not([Directory]::Exists($LogPath))){
            $Log = [Logger]::new()
            [void]($Log.Create($LogPath.Parent.FullName,$LogPath.BaseName))
        }

        try {
            if (!(Get-Module -Name SQLServer -ListAvailable)) {
                Write-Warning "[Warning] SQLServer Module not installed. Installing now..."
                [void](Install-Module -Name SqlServer -AllowClobber)
            }
            else {
                Write-Host -ForegroundColor White -BackgroundColor DarkGreen "[INFO] SQLServer Module installed. Importing...."
                [void](Import-Module -Name SqlServer -Global)
            }
        }
        catch {
            throw "[WARNING] Couldn't import/install SQLModule. Checking if required assembly are available..."
            [Logger]::Add($LogPath,$_.Exception.Message)
            Continue
        }

        try {
            # We need those assembly to be able to connect to SQL and take buckup
            # Abort if we can't imports it. 
            [void]([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO"))
            [void]([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended"))
        }
        catch {
            Throw "[ERROR] Couldn't load Microsoft.SqlServer Asssembly. SQLServer module must be installed! Aborting..."
            [Logger]::Add($LogPath,$_.Exception.Message)
            exit
        }
    }
    
    process {
        foreach ($db in $Database){
            Write-Host -ForegroundColor Black -BackgroundColor White "[INFO] Starter Backup-SQL-Database $TimeStarted"
            Write-Host -ForegroundColor Black -BackgroundColor White "[INFO] Database: $db"
            Write-Host -ForegroundColor Black -BackgroundColor White "[INFO] SQLBackup destination: $Path"
            #SQL Backup initial config
            $SQLBackup = [Microsoft.SqlServer.Management.Smo.Server]::new($SqlServer)
            $backupFile = $Path + '\' + $db + '_' + $timestamp + '.bak'
            $backupName = Split-Path $backupFile -leaf

            try { 
                $smoBackup = [Microsoft.SqlServer.Management.Smo.Backup]::new()
                $smoBackup.Action = "Database"
                $smoBackup.BackupSetDescription = "Full backup of $($db)"
                $smoBackup.BackupSetName = "$($db) Backup"
                $smoBackup.Database = $db
                $smoBackup.MediaDescription = "Disk"
                $smoBackup.PercentCompleteNotification = "10"
                $percentEventHandler = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] { Write-Host "[INFO] Executing $($_.Percent)%" }
                $completedEventHandler = [Microsoft.SqlServer.Management.Common.ServerMessageEventHandler] { Write-Host "[INFO] Database backup of $db to $backupFile is DONE" }
                $smoBackup.add_PercentComplete($percentEventHandler)
                $smoBackup.add_Complete($completedEventHandler)
                $smoBackup.Devices.AddDevice($backupFile,"File")
            }
    
            catch {
                Throw "Something went wrong. Check Log! Building backup of $db - FAILED"
                [Logger]::Add($LogPath,$_.Exception.Message)
                exit
            }
    
            try {
                Write-Host -ForegroundColor White -BackgroundColor DarkRed "Starting backup of $db"
                # Starting SQL Backup here
                $smoBackup.SqlBackup($SQLBackup)

                Write-Host -ForegroundColor White -BackgroundColor DarkGreen "[DONE] Backup Done on :: $(Get-Date)"

                # If sucessfull - building object and for each Database
                $BackupFileInfo = [FileInfo]::new($Path)
                $SQLBackupOutput = [PSSQLBackup]::new($db, $backupName, $BackupFileInfo.LastWriteTime, $BackupFileInfo.FullName, $BackupFileInfo.Length, 'DONE')
                $SQLBackupOutput | Add-Member -NotePropertyMembers @{ServerName = $SQLServer}
                $BackupResults.Add($SQLBackupOutput)
            }
            catch {
                Throw "[ERROR] Something went wrong."
                Throw "[ERROR] Backup of $db - Status: FAILED"
                
                #If failed - building object for each Database
                $SQLBackupOutput = [PSSQLBackup]::new()
                $SQLBackupOutput.Database = $db
                $SQLBackupOutput.BackupName = $backupName
                $SQLBackupOutput.BackupStatus = 'FAILED!'
                $SQLBackupOutput | Add-Member -NotePropertyMembers @{ServerName = $SQLServer}
                $BackupResults.Add($SQLBackupOutput)
                # Put errors in log file
                [Logger]::Add($LogPath,$_.Exception.Message)
                Continue
            }
        }
    }
    
    end {
        try{
            [void]($BackupResults | ConvertTo-Html -Property BackupDB, BackupName, Status -Head $Head | 
            Out-File "$env:SystemDrive\Temp\SQLBackupStatus.html" -Force -ErrorAction Stop)
            $SQLStatusFile = Get-Content -Path "$env:SystemDrive\Temp\SQLBackupStatus.html" -ea Stop
            #Building mail parameters and values
            $MailParams = @{
                To = $Configuration.To
                From = $Configuration.From
                SMTPServer = $Configuration.MailServer
                Subject = "SQLBackup Status - DONE "
                Body = $SQLStatusFile
                BodyAsHtml = $true
            }

            Send-MailMessage @MailParams
        }
        catch {
            Throw "[ERROR] Couldn't find SQLBackupStatus.html. Aborting sending mail message..."
            [Logger]::Add($LogPath,$_.Exception.Message)
            exit
        }
    }
}