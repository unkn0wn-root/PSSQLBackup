class PSSQLBackupClass {
    [string]$Database
    [string]$BackupName
    [datetime]$BackupDate
    [int]$SizeInMB
    [string]$BackupStatus
    hidden[string]$SQLServer = 'localhost'

        PSSQLBackupClass() {
            $this.SQLServer
            $this.Database
            $this.BackupName
            $this.BackupDate
            $this.SizeInMB
        }

        PSSQLBackupClass([string]$Database, [string]$BackupName, [datetime]$BackupDate, [int]$SizeInMB, [string]$Status) {
                $this.Database = $Database
                $this.BackupName = $BackupName
                $this.BackupDate = $BackupDate
                $this.SizeInMB = ([math]::Round($SizeInMB /1MB, 2))
                $this.BackupStatus = $Status
    }

    # Methods
        [psobject]Show([string]$Path) {
            $item = Get-Item -Path $Path
            if ($item.Name -match '_') {
                $Name = ($item.Name).Substring(0,$item.Name.IndexOf('_'))
                $FileStatus = 'DONE'
            }
            else {
                $Name = 'N/A'
                $FileStatus = 'UNCONFIRMED'
            }
            $Objects = [PSSQLBackupClass]::new($Name, $item.name, $item.LastWriteTime, $item.Length, $FileStatus)
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