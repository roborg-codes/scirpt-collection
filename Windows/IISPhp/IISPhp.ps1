# https://gist.github.com/BernieWhite/23522e76765d8fa88db7abb5f03086ce#file-azure-web-vm-configuration-ps1

configuration webConfiguration
{
    param (
        [Parameter(Mandatory = $True)]
        [String]$websitePackageUri
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    # Import-DscResource -ModuleName WebAdministration

    Node 'localhost'
    {
        # Install IIS features
        WindowsFeature WebServerRole {
            Name   = "Web-Server"
            Ensure = "Present"
        }

        # WindowsFeature WebManagementService {
        #     Name   = "Web-Mgmt-Service"
        #     Ensure = "Present"
        # }

        # WindowsFeature ASPNet45 {
        #     Name   = "Web-Asp-Net45"
        #     Ensure = "Present"
        # }

        # WindowsFeature HTTPRedirection {
        #     Name   = "Web-Http-Redirect"
        #     Ensure = "Present"
        # }

        # WindowsFeature CustomLogging {
        #     Name   = "Web-Custom-Logging"
        #     Ensure = "Present"
        # }

        # WindowsFeature LogginTools {
        #     Name   = "Web-Log-Libraries"
        #     Ensure = "Present"
        # }

        # WindowsFeature RequestMonitor {
        #     Name   = "Web-Request-Monitor"
        #     Ensure = "Present"
        # }

        # WindowsFeature Tracing {
        #     Name   = "Web-Http-Tracing"
        #     Ensure = "Present"
        # }

        # WindowsFeature BasicAuthentication {
        #     Name   = "Web-Basic-Auth"
        #     Ensure = "Present"
        # }

        # WindowsFeature WindowsAuthentication {
        #     Name   = "Web-Windows-Auth"
        #     Ensure = "Present"
        # }

        # WindowsFeature ApplicationInitialization {
        #     Name   = "Web-AppInit"
        #     Ensure = "Present"
        # }

        Script InstallVcRedist {
            GetScript = {
                $HasVcRedistModule = (Get-Module -ListAvailable VcRedist)
                $VcRedistInstalled = (Get-AppxPackage –Name *vcredist*)
                $Result = ($HasVcRedistModule -and $VcRedistInstalled)

                return @{Result = "$Result"}
            }

            SetScript = {
                Install-Module -Name VcRedist -Force
                Import-Module -Name VcRedist

                $VcRedistInstallablesPath = "C:\Temp\Redist"
                if (!Test-Path -Path $VcRedistInstallablesPath) {
                    New-Item `
                        -Path $VcRedistInstallablesPath `
                        -ItemType Directory
                }

                $VcList = Get-VcList -Release 2019 -Architecture x86
                Save-VcRedist -VcList $VcList -Path $VcRedistInstallablesPath
                Install-VcRedist `
                    -VcList $VcList `
                    -Path $VcRedistInstallablesPath `
                    -Silent -Force

                return "OK"
            }

            TestScript = {
                $hasVcRedistModule = (Get-Module -ListAvailable VcRedist)
                $vcRedistInstalled = (Get-AppxPackage –Name *vcredist*)

                return ($hasVcRedistModule -and $vcRedistInstalled)
            }

        }

        Script InstallPhp {
            GetScript = {
                $Result = (Test-Path -Path "C:\PHP" -and php -v)
                @{
                    Result = "$Result"
                }
            }

            TestScript = {
                return Test-Path -Path "C:\PHP\"
            }

            SetScript = {
                Set-ExecutionPolicy `
                    -ExecutionPolicy RemoteSigned `
                    -Scope CurrentUser `
                    -Force

                Install-Module `
                    -Name PhpManager `
                    -Repository PSGallery `
                    -Force

                Install-Php `
                    -Version 8.1 `
                    -Architecture x64 `
                    -ThreadSafe 0 `
                    -Path C:\PHP `
                    -TimeZone UTC `
                    -AddToPath User
            }

        }
    }
}
