configuration FileShareConfiguration
{
    param
    (
        [Parameter(Mandatory)]
        [String]
        $StorageAccountName,

        [Parameter(Mandatory)]
        [SecureString]
        $StorageAccountKey,

        [Parameter(Mandatory)]
        [String]
        $FileShareName
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    $FileShareUNCPath = "\\$using:StorageAccountName.file.core.windows.net\$using:FileShareName"

    Node 'localhost'
    {
        Script MountFileShare
        {
            GetScript = {
                return @{
                    Result = Get-PSDrive "X" -PSProvider "FileSystem" | Write-String
                }
            }
            TestScript = {
                return [Bool](Get-PSDrive "X" -PSProvider "FileSystem")
            }
            SetScript = {
                $ConnectTestResult = Test-NetConnection `
                    -ComputerName $using:StorageAccountName.file.core.windows.net `
                    -Port 445

                if (-not $ConnectTestResult.TcpTestSucceeded) {
                    Write-Error -Message "Unable to reach the Azure storage account via port 445."
                    return
                }

                # Save the password so the drive will persist on reboot
                cmd.exe /C "cmdkey /add:`"$using:FileShareUNCPath`" /user:`"localhost\$using:$StorageAccountName`" /pass:`"$using:StorageAccountKey`""

                # Mount the drive
                New-PSDrive `
                    -Persist `
                    -Name "X" `
                    -PSProvider "FileSystem" `
                    -Root $using:FileShareUNCPath
            }
        }
    }
}
