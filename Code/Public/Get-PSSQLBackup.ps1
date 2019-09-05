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
#requires -Modules SQLBackup
#requires -RunAsAdministrator
#requires -Version 5

using module .\Classes\PSSQLBackupClass.ps1
using namespace System.Collections.Generic
using namespace System.IO

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
                    [array]$PathEx = [Directory]::GetFiles($FullPath)
                    foreach ($UNC in $PathEx) {
                        $Object = [SQLBackupClass]::New()
                        $CacheObject = $Object.Show($UNC)
                        $Output.Add($CacheObject)
                    }
                }
                else {
                    # Loop through collection and create new objects everytime you find match
                    # Note that 'show' is not static method so need to create new object 
                    # every time we go through in loop
                    foreach ($item in $Filter){
                        $Object = [PSSQLBackupClass]::New()
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