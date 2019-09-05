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
#requires -Modules SQLBackup
#requires -RunAsAdministrator
#requires -Version 5

using module .\Classes\PSSQLBackupClass.ps1
using namespace System.Collections.Generic
using namespace System.Net.Mail
using namespace System.IO

function New-PSSQLBackup {
    [CmdletBinding()]
    param (
        # Define SQLServer connection
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Server')]
        [string]$SQLServer = 'localhost',

        # Databases to backup
        [Parameter(
        Mandatory = $true, 
        Position = 1, 
        ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('DB')]
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

    $BackupResults = [List[psobject]]::new()
    [datetime]$timestamp = Get-Date -format yyyy-MM-dd-HHmmss
    # Mail Server Configuration variables
    [string]$MailServer = 'EX01.mail.com'
    [string]$To = 'systemadmin@mail.com'
    [string]$From = 'SQLBackup@mail.com'
    [string]$Subject = "SQLBackup Status - DONE "
    # Check if backup log file exist, if not - create it
    [string]$LogFile = "$env:SystemDrive\Temp\SQLDBBackup_log.txt"
        if (-not([Directory]::Exists($LogFile))){
            [void]([File]::Create($LogFile))
        }
        try {
            if (!(Get-Module -Name SQLServer -ListAvailable)) {
                Install-Module -Name SqlServer -AllowClobber
            }
            else {
                Import-Module -Name SqlServer -AllowClobber
            }
        }
        catch {
            throw "[WARNING] Couldn't import/install SQLModule. Checking if required assembly are available..."
            "[$(Get-Date)] :: $($_.Exception.Message)" | Out-File $LogFile -Append
            Continue
        }
        try {
            # We need those assembly to be able to connect to SQL and take buckup
            # Abort if we can't imports it. 
            [void]([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO"))
            [void]([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended"))
        }
        catch {
            Throw "[ERROR] Couldn't load Microsoft.SqlServer Asssembly. Aborting"
            "[$(Get-Date)] :: $($_.Exception.Message)" | Out-File $LogFile -Append
            return
        }
    }
    
    process {
        foreach ($db in $SqlDatabase | Where-Object { $_.IsSystemObject -eq $False}){
            Write-Output "[INFO] Starter Backup-SQL-Database $TimeStarted"
            Write-Output "[INFO] Database: $db"
            Write-Output "[INFO] SQLBackup destination: $Path"
            #SQL Backup initial config
            $SQLBackup = [Microsoft.SqlServer.Management.Smo.Server]::new($SqlServer)
            $backupFile = $Path + '\' + $db + '_' + $timestamp + '.bak'
            $backupName = Split-Path $backupFile -leaf

            try { 
                $smoBackup = [Microsoft.SqlServer.Management.Smo.Backup]::new()
                $smoBackup.Action = "Database"
                $smoBackup.BackupSetDescription = "Full backup of $($db)"
                $smoBackup.BackupSetName = "$($SqlDatabase) Backup"
                $smoBackup.Database = $SqlDatabase
                $smoBackup.MediaDescription = "Disk"
                $smoBackup.PercentCompleteNotification = "10"
                $percentEventHandler = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] { Write-Output "[INFO] Executing $($_.Percent)%" }
                $completedEventHandler = [Microsoft.SqlServer.Management.Common.ServerMessageEventHandler] { Write-Output "[INFO] Database backup of $db to $backupFile is DONE" }
                $smoBackup.add_PercentComplete($percentEventHandler)
                $smoBackup.add_Complete($completedEventHandler)
                $smoBackup.Devices.AddDevice($backupFile,"File")
            }
    
            catch {
                Throw "Something went wrong. Check Log! Building backup of $db - FAILED"
                "[$(Get-Date)] :: $($_.Exception.Message)" | Out-File $LogFile -Append
                return
            }
    
            try {
                # Starting SQL Server backup after building all neccessery args.
                Write-Output "[INFO]"
                Write-Output "Starting backup of $db"
                $smoBackup.SqlBackup($SQLBackup)
                
                Write-Output "[INFO] Backup Done on :: $(Get-Date)"
                Write-Output "[DONE]"
                Write-Output ""

                # If sucessfull - building object and for each Database
                $BackupFileInfo = Get-Item -Path $backupFile
                $SQLBackupOutput = [PSSQLBackupClass]::new($db, $backupName, $BackupFileInfo.LastWriteTime, $BackupFileInfo.Length, 'DONE')
                $SQLBackupOutput | Add-Member -NotePropertyMembers @{ServerName = $SQLServer}
                $BackupResults.Add($SQLBackupOutput)
            }
            catch {
                Throw "[ERROR] Something went wrong."
                Throw "[ERROR] Backup of $db - Status: FAILED"
                
                #If failed - building object for each Database
                $SQLBackupOutput = [PSSQLBackupClass]::new()
                $SQLBackupOutput.Database = $db
                $SQLBackupOutput.BackupName = $backupName
                $SQLBackupOutput.BackupStatus = 'FAILED!'
                $SQLBackupOutput | Add-Member -NotePropertyMembers @{ServerName = $SQLServer}
                $BackupResults.Add($SQLBackupOutput)
                # Put errors in log file
                "[$(Get-Date)] :: $($_.Exception.Message)" | Out-File $LogFile -Append
                Continue
            }
        }
    }
    
    end {
        try{
            [void]($BackupResults | ConvertTo-Html -Property BackupDB, BackupName, Status -Head $Head | 
            Out-File "$env:SystemDrive\Temp\SQLBackupStatus.html" -Force -ErrorAction Stop)
            $SQLStatusFile = Get-Content -Path "$env:SystemDrive\Temp\SQLBackupStatus.html" -ea Stop
            $Message = [MailMessage]::new($From,$To) 
            $Message.Subject = $Subject
            $Message.IsBodyHtml = $true
            $Message.Body = $SQLStatusFile
            # Sends mail message with all objects and status
            $SMTP = [SmtpClient]::new($MailServer)
            $SMTP.Send($Message)
        }
        catch {
            Throw "[ERROR] Couldn't find SQLBackupStatus.html. Aborting sending mail message..."
            "[$(Get-Date)] :: $($_.Exception.Message)" | Out-File $LogFile -Append
            return
        }
    }
}