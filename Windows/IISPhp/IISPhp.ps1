# Usage:
# webConfiguration -WebsitePackageUri https://example.com/app.php.zip
# Start-DSConfiguraion -Path .\WebConfiguration\

configuration WebConfiguration
{
    param
    (
        [Parameter(Mandatory = $True)]
        [String]$WebsitePackageUri
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    # Import-DscResource -ModuleName WebAdministration

    Node 'localhost'
    {
        # Install IIS features
        WindowsFeature WebServerRole
        {
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

        Script Install-VcRedist
        {
            GetScript = {
                return @{
                    Result = Get-AppPackage | Where-Object { $_.Name -Like "*Visual C++*2019*" } | Select Name
                }
            }

            TestScript = {
                $HasVcRedistModule = Get-Module -ListAvailable VcRedist
                $VcRedistInstalled = Get-AppPackage | Where-Object { $_.Name -Like "*Visual C++*2019*" }

                return ($HasVcRedistModule -and $VcRedistInstalled)
            }

            SetScript = {
                Install-PackageProvider `
                    -Name NuGet `
                    -MinimumVersion 2.8.5.201 `
                    -Force
                Install-Module -Name VcRedist -Force
                Import-Module -Name VcRedist
                Write-Verbose -Message "VcRedist module loaded"

                $VcRedistInstallablesPath = "C:\Temp\Redist"
                if (-not (Test-Path -Path $VcRedistInstallablesPath)) {
                    Write-Verbose -Message "Creating directory $VcRedistInstallablesPath"
                    New-Item `
                        -Path $VcRedistInstallablesPath `
                        -ItemType Directory
                }

                $VcList = Get-VcList -Release 2019 -Architecture x86
                Write-Verbose -Message "Saving VcRedist 2019 x86"
                Save-VcRedist -VcList $VcList -Path $VcRedistInstallablesPath

                Write-Verbose -Message "Installing VcRedist 2019 x86"
                Install-VcRedist `
                    -VcList $VcList `
                    -Path $VcRedistInstallablesPath `
                    -Silent `
                    -Force

                Write-Verbose -Message "Done!"
            }
        }

        Script InstallPhp
        {
            GetScript = {
                return @{
                    Result = [String](php -v)
                }
            }

            TestScript = {
                return (Test-Path -Path "C:\PHP" -and php -v)
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
                    -Architecture x86 `
                    -ThreadSafe 0 `
                    -Path C:\PHP `
                    -TimeZone UTC `
                    -AddToPath System
            }

            DependsOn = "[Script]Install-VcRedist"
        }
    }
}
