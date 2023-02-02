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
    $Cred = New-Object System.Management.Automation.PSCredential(
            $using:StorageAccountName,
            $using:StorageAccountKey)

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
                New-PSDrive `
                    -Persist `
                    -Scope Global `
                    -Name "X" `
                    -PSProvider "FileSystem" `
                    -Root $using:FileShareUNCPath `
                    -Credential $using:Cred
            }
        }
    }
}
