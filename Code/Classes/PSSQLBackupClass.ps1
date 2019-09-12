# PSSQLBackupClass initialization. Needs to be loaded before functions
# This class is used to create PSSQLBackup objects
class PSSQLBackup {
    hidden [string]$SQLServer = 'localhost'
    [string]$Database
    [string]$BackupName
    hidden [string]$FullName
    hidden [string]$Path
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
            $this.Path
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
            $Objects.Path = $item.Directory
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