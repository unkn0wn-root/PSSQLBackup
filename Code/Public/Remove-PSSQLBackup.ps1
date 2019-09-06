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
#requires -RunAsAdministrator
#requires -Version 5

using module .\Classes\PSSQLBackupClass.ps1
using namespace System.Collections.Generic
using namespace System.IO
function Remove-PSSQLBackup {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        # Path to backup store
        [Parameter(
        Mandatory = $true,
        ValueFromPipeline,
        ValueFromPipelineByPropertyName)]
        [string]$Path,

        [Parameter(
        Mandatory = $true, ValueFromPipeline)]
        [Alias('File')]
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
        [string]$LogFile = "$env:SystemDrive\Temp\SQLDBBackup_log.txt"
        if (-not([Directory]::Exists($LogFile))){
            [void]([File]::Create($LogFile))
        }
        $BackupFiles = Get-ChildItem -Path $Path -File -Force
        if ($Name) {
            $BackupPath = $BackupFiles | Where-Object {$_.Name -like $FileName}
        }
        else {
            $BackupPath = $BackupFiles
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
                    [PSSQLBackupClass]::Remove($BackupFile.FullName)    # Using SQLClass to remove backup file
                    Write-Output "$($BackupFile.Name) removed!"
                    $RMFiles = [PSSQLBackupClass]::new()
                    $RMFiles.BackupName = $BackupFile.Name
                    $RMFiles | Add-Member -NotePropertyMembers @{RemovedTime = (Get-Date)}
                    $RMFiles.BackupStatus = 'REMOVED'
                    $RemovedFiles.Add($RMFiles)
                }
            }
            catch {
                Throw "[ERROR] Couldn't remove $($BackupFile.Name)..."
                $Failed = [PSSQLBackupClass]::new()
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