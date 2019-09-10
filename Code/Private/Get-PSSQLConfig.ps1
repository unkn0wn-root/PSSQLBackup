function Get-PSSQLConfig {
    [CmdletBinding()]
    param (
        # Configuration file for PSSQLBackup
        [Parameter(Position=0)]
        [string]
        $ConfigurationFile = "$PSScriptRoot\Config\PSSQLConfig.json"
    )
    
    begin {}
    
    process {
        $Global:Configuration = Get-Content $ConfigurationFile | ConvertFrom-Json
        return $Configuration
    }

    end {}
} 