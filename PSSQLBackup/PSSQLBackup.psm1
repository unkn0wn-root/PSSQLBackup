# namespaces used in Functions
using namespace System.Collections.Generic
using namespace System.Net.Mail
using namespace System.IO

# pre launch requirements
#requires -RunAsAdministrator
#requires -Version 5

# PSSQLBackupClass initialization. Needs to be loaded before functions
class PSSQLBackup {
    hidden[string]$SQLServer = 'localhost'
    [string]$Database
    [string]$BackupName
    hidden[string]$FullName
    [datetime]$BackupDate
    [int]$SizeInMB
    [string]$BackupStatus

        PSSQLBackup() {
            $this.SQLServer
            $this.Database
            $this.BackupName
            $this.BackupDate
            $this.SizeInMB
            $this.FullName
        }
        # Class constructor - 
        PSSQLBackup([string]$Database, [string]$BackupName, [datetime]$BackupDate, [string]$Path, [int]$SizeInMB, [string]$Status) {
                $this.Database = $Database
                $this.BackupName = $BackupName
                $this.BackupDate = $BackupDate
                $this.FullName = $Path
                $this.SizeInMB = ([math]::Round($SizeInMB /1MB, 2))
                $this.BackupStatus = $Status
    }

        # Methods
        [psobject]Show([string]$Path) {
            $item = [System.IO.FileInfo]::new($Path)
            if ($item.Name -match '_') {
                $Name = ($item.Name).Substring(0,$item.Name.IndexOf('_'))
                $FileStatus = 'DONE'
            }
            else {
                $Name = 'N/A'
                $FileStatus = 'UNCONFIRMED'
            }
            # Building actual object
            $Objects = [PSSQLBackup]::new()
            $Objects.Database = $Name
            $Objects.BackupName = $item.name
            $Objects.BackupDate = $item.LastWriteTime
            $Objects.FullName = $item.FullName
            $Objects.SizeInMB = ([math]::Round($item.Length /1MB, 2)) 
            $Objects.BackupStatus = $FileStatus
            # return object
            return $Objects
    }

    static [void]Remove([string]$File){
        try {
            if ((Get-Item -Path $File).GetType().FullName -eq 'System.IO.FileInfo'){
                [System.IO.File]::Delete($File)
            }
            elseif ((Get-Item -Path $File).GetType().FullName -eq 'System.IO.DirectoryInfo') {
                [System.IO.Directory]::Delete($File, $True)
            }
        }
        catch {
            Throw "Couldn't remove $File"
        }
    } 
}

<#
.SYNOPSIS
    Get all SQL backup files
.DESCRIPTION
    This function will output all backup files with status. Backup files will be done with datetime in name
    so it will try to go through all files in path and try to find those files which matches pattern
.EXAMPLE
    PS C:\> Get-SQLBackup -Path '\\filesrv1\SQLBackup\'
    Loop through ALL files in UNC/local path and try to find backup files
.EXAMPLE
    PS C:\> Get-SQLBackup -Path '\\filesrv1\SQLBackup\' -FromDate '01.01.2019'
    Loop through ALL files in UNC/local path and try to find backup files from that day until today
.EXAMPLE
    PS C:\> Get-SQLBackup -Path '\\filesrv1\SQLBackup\' -FromDate '01.01.2019' -toDate 08.08.2019
    Loop through ALL files in UNC/local path and try to find backup files from that day until date 08.08.2019
.EXAMPLE
    PS C:\> Get-SQLBackup -Path '\\filesrv1\SQLBackup\' -Day 7
    Loop through ALL files in UNC/local path and try to find backup files from today minus seven days
.EXAMPLE
    PS C:\> Get-SQLBackup -Path '\\filesrv1\SQLBackup\' -Name DB0
    Search for file til the name DB0
.EXAMPLE
    PS C:\> Get-SQLBackup -Path '\\filesrv1\SQLBackup\' -Name DB*
    Wildcard support
.NOTES
    Author: David0 
    GitHub: unkn0wn-root
    Twitter: david0_shell
#>

function Get-PSSQLBackup {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        # Required parameter. Path will be vaildated. If not exist - this will be errored
        [Parameter(
        ParameterSetName = 'Default',
        Mandatory = $True,
        ValueFromPipeline,
        ValueFromPipelineByPropertyName,
        Position = 0)]
        [Parameter( 
        ParameterSetName = 'DayFilter',
        Mandatory = $True,
        ValueFromPipeline,
        ValueFromPipelineByPropertyName,
        Position = 0)]
        [ValidateScript({Test-Path $_ -PathType 'Container'})]
        [string]$Path,

        # Parameter help description
        [Parameter(ParameterSetName = 'Default',
        Mandatory = $false,
        ValueFromPipeline,
        ValueFromPipelineByPropertyName)]
        [Parameter(
        ParameterSetName = 'DayFilter',
        Mandatory = $false,
        ValueFromPipeline,
        ValueFromPipelineByPropertyName)]
        [string]$Name,

        # From which date you want to see backup files
        [Parameter(ParameterSetName = 'Default', Position = 1)]
        [Alias('From')]
        [datetime]$FromDate,

        # To which date you want to see backup files
        [Parameter(ParameterSetName = 'Default', Position = 2)]
        [Alias('To')]
        [datetime]$ToDate,

        # From day today - days you want to filter
        [Parameter(
        Mandatory = $True,
        ParameterSetName = 'DayFilter')]
        [int]$Days

    )
    
    begin {
        # Creating array for objects
        # Checking if logfile exist allready, if not - create new one
        # Creating list for Objects
        $Output = [List[psobject]]::new()
        [array]$FilePath = Get-ChildItem -Path $Path -File
        [string]$LogFile = "$env:SystemDrive\Temp\SQLDBBackup_log.txt"
            if (-not([Directory]::Exists($LogFile))){
                [void]([File]::Create($LogFile))
        }
    }
    
    process {
        # In proccess block we are checking which params has been choosen
        # based on this we can do some action like sort from date
        # or sort to date. You can also sort based on today - days so Today day minus 7 days
        if ($PSBoundParameters['Path']) {
            if ($PSBoundParameters['FromDate']){
                $Filter = $FilePath | Where-Object { $_.LastWriteTime -gt [datetime]$From }
            }
            elseif ($PSBoundParameters['ToDate']){
                $Filter = $FilePath | Where-Object { $_.LastAccessTime -lt [datetime]$To }
            }
            elseif ($PSBoundParameters['Days']) {
                $Filter = $FilePath | Where-Object { $_.LastAccessTime -lt ((Get-Date).AddDays(-[int]$Days)) }
            }
            else {
                $Filter = $FilePath
            }
            try {
                if ($PSBoundParameters['Name']){
                    # This will be used if you specified Name parameter
                    # Then it will search for specified Name and return object
                    # It supports Wildcard search
                    $FullPath = $Path + '\' + $Name
                    [array]$PathEx = (Get-Item -Path $FullPath | 
                    Where-Object {$_.PSIsContainer -eq $false}).FullName
                    foreach ($UNC in $PathEx) {
                        $Object = [PSSQLBackup]::New()
                        $CacheObject = $Object.Show($UNC)
                        $Output.Add($CacheObject)
                    }
                }
                else {
                    # Loop through collection and create new objects everytime you find match
                    # Note that 'show' is not static method so need to create new object 
                    # every time we go through in loop
                    foreach ($item in $Filter){
                        $Object = [PSSQLBackup]::New()
                        $CacheObject = $Object.Show($item.FullName)
                        $Output.Add($CacheObject)
                    }
                }
            }
            catch {
                # Catch error and place in LogFile but do not close the loop
                # We need to be able to find more backup files even if we don't find name file
                # then it will be just noted in log file but continue with next object
                Write-Warning "Couldn't find any item matching $item."
                "[$(Get-Date)] :: $($_.Exception.Message)" | Out-File $LogFile -Append
                Continue
            }
                # return list with objects we found
                return $Output
        }
    }
}

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
                Write-Warning "[Warning] SQLServer Module not installed. Installing now..."
                [void](Install-Module -Name SqlServer -AllowClobber)
            }
            else {
                Write-Output "[INFO] SQLServer Module installed. Importing..."
                [void](Import-Module -Name SqlServer -AllowClobber)
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
            Throw "[ERROR] Couldn't load Microsoft.SqlServer Asssembly. SQLServer module must be installed! Aborting..."
            "[$(Get-Date)] :: $($_.Exception.Message)" | Out-File $LogFile -Append
            exit
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
                exit
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
            exit
        }
    }
}

<#
.SYNOPSIS
    Remove database files in path
.DESCRIPTION
    This function will remove one or multiple databases and output results to current session
.EXAMPLE
    PS C:\> Remove-SQLBackup -Path \\filesrv01\SQLBackup\ -FileName DB01_20.10.2019.bak
    This command will remove DB01_20.201.2019.bak file in \\filesrv01\SQLBackup path
.EXAMPLE
    PS C:\> Remove-SQLBackup -Path '\\filesrv1\SQLBackup\' -FromDate '01.01.2019'
    Loop through ALL files in UNC/local path and try to remove backup files from that day until today
.EXAMPLE
    PS C:\> Remove-SQLBackup -Path '\\filesrv1\SQLBackup\' -FromDate '01.01.2019' -toDate 08.08.2019
    Loop through ALL files in UNC/local path and try to remove backup files from that day until date 08.08.2019
.EXAMPLE
    PS C:\> Remove-SQLBackup -Path '\\filesrv1\SQLBackup\' -Day 7
    Loop through ALL files in UNC/local path and try to remove backup files from today minus seven days
.EXAMPLE
    PS C:\> Remove-SQLBackup -Path '\\filesrv1\SQLBackup\' -Name DB01
    Search for file with name DB01 and remove it
.EXAMPLE
    PS C:\> Get-SQLBackup -Path '\\filesrv1\SQLBackup\' -Name DB*
    Wildcard support for removing all that starts with DB name
.NOTES
    Author: David0 
    GitHub: unkn0wn-root
    Twitter: david0_shell
#>
function Remove-PSSQLBackup {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        # Path to backup store
        [Parameter(
        Mandatory = $true,
        ValueFromPipeline,
        ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(
        Mandatory = $true, ValueFromPipeline)]
        [Alias('File')]
        [ValidateNotNullOrEmpty()]
        [string[]]$FileName,

        # Filter param 
        [Parameter()]
        [Alias('From')]
        [datetime]$FromDate,

        # Filter param
        [Parameter()]
        [Alias('To')]
        [datetime]$ToDate,

        # Filter Param
        [Parameter()]
        [datetime]$Days,

        # Force param
        [Parameter()]
        [Alias('F')]
        [switch]$Force
        
    )
    
    begin {
        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
        [array]$FilesArray = Get-ChildItem -Path $Path -File -Force
        [string]$LogFile = "$env:SystemDrive\Temp\SQLDBBackup_log.txt"
        if (-not([Directory]::Exists($LogFile))){
            [void]([File]::Create($LogFile))
        }
        if ($FileName) {
            $BackupPath = $FilesArray | Where-Object {$_.Name -like $FileName}
        }
        else {
            $BackupPath = $FilesArray
        }
    }
    
    process {
        if ($PSBoundParameters['FromDate']){
            $PathFilter = $BackupPath | Where-Object { $_.LastWriteTime -gt [datetime]$From }
        }
        elseif ($PSBoundParameters['ToDate']){
            $PathFilter = $BackupPath | Where-Object { $_.LastAccessTime -lt [datetime]$To }
        }
        elseif ($PSBoundParameters['Days']) {
            $PathFilter = $BackupPath | Where-Object { $_.LastAccessTime -lt ((Get-Date).AddDays(-[int]$Days)) }
        }
        else {
            $PathFilter = $BackupPath
        }
        $RemovedFiles = [List[psobject]]::new()
        foreach ($BackupFile in $PathFilter) {
            try{
                if ($Force -or $PSCmdlet.ShouldProcess("Removing $($Backupfile.Name) from $($BackupFile.DirectoryName)")) {
                    Write-Output "[INFO]Removing $($BackupFile.Name)..."
                    [PSSQLBackup]::Remove($BackupFile.FullName)    # Using SQLClass to remove backup file
                    Write-Output "$($BackupFile.Name) removed!"
                    $RMFiles = [PSSQLBackup]::new()
                    $RMFiles.BackupName = $BackupFile.Name
                    $RMFiles | Add-Member -NotePropertyMembers @{RemovedTime = (Get-Date)}
                    $RMFiles.BackupStatus = 'REMOVED'
                    $RemovedFiles.Add($RMFiles)
                }
            }
            catch {
                Throw "[ERROR] Couldn't remove $($BackupFile.Name)..."
                $Failed = [PSSQLBackup]::new()
                $Failed.BackupName = $BackupFile.Name
                $Failed | Add-Member -NotePropertyMembers @{FailedTime = (Get-Date)}
                $Failed.BackupStatus = 'FAILED!'
                $RemovedFiles.Add($Failed)
                "[$(Get-Date)] :: $($_.Exception.Message)" | Out-File $LogFile -Append
                Continue
            }
        }
            
    }
    
    end {
        # Show removed and failed files
        return $RemovedFiles
    }
}

#Private Function to clean-up variables
Function Remove-Variables {
    Get-Variable | Where-Object { $StartUpVariables -NotContains $_.Name } |
    ForEach-Object {
        $vararg = @{
            Name = "$($_.Name)"
            Force = $true
            Scope = 'global'
            ErrorAction = 'SilentlyContinue'
            WarningAction = 'SilentlyContinue'
        }
        Try { 
            Remove-Variable @vararg
        }
        Catch {
        }
    }
}