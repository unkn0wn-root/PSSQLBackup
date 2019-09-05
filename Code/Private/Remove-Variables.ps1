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