param(
    [string]$Dest,
    [string]$File
)

Invoke-Command {
    Invoke-WebRequest `
        -Uri $Dest `
        -Method POST `
        -Body (((Get-Content $File) -join "`n") + "`n")
}
