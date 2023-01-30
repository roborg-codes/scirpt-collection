# Usage:
# webConfiguration -WebsitePackageUri https://example.com/app.php.zip
# Start-DSConfiguraion -Path .\WebConfiguration\

# TODO:
# 1. fastcgi???
# 2. Fix path to unzip (archive creates single directory in target)

configuration WebConfiguration
{
    param
    (
        [Parameter(Mandatory = $True)]
        [String]$WebsitePackageUri
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node 'localhost'
    {
        # Install IIS features
        WindowsFeature WebServerRole
        {
            Name   = "Web-Server"
            Ensure = "Present"
        }

        # Install IIS management service
        WindowsFeature WebManagementService {
            Name   = "Web-Mgmt-Service"
            Ensure = "Present"
        }

        # Install IIS management scripts and tools(IISAdministration module)
        WindowsFeature WebManagementScripts {
            Name   = "Web-Scripting-Tools"
            Ensure = "Present"
        }

        # Install ASPNet45
        WindowsFeature ASPNet45 {
            Name   = "Web-Asp-Net45"
            Ensure = "Present"
        }

        # Create directory to store VcRedist installables
        File VcRedistDir
        {
            Type            = "Directory"
            DestinationPath = "C:\Temp\Redist"
            Ensure          = "Present"
        }

        # Create directory to download website to
        File WebSiteContentDest
        {
            Type            = "Directory"
            DestinationPath = "C:\Temp\WebApp"
            Ensure          = "Present"
        }

        # Delete default website contents and download website archive
        Script PrepareWebSiteContent
        {
            GetScript = {
                return @{
                    Result = Test-Path -PathType leaf -Path "C:\Temp\WebApp\Archive.zip"
                }
            }

            TestScript = {
                return Test-Path -PathType leaf -Path "C:\Temp\WebApp\Archive.zip"
            }

            SetScript = {
                # Remove default website files
                Get-ChildItem -Path "C:\inetpub\wwwroot" | ForEach {
                    Remove-Item -Recurse $_.FullName
                }

                # Download archive
                Invoke-WebRequest -URI $using:WebsitePackageUri -OutFile "C:\Temp\WebApp\Archive.zip"
            }

            DependsOn = @("[File]WebSiteContentDest", "[WindowsFeature]WebServerRole")
        }

        # Unzip website into wwwroot
        Archive UnzipWebSite
        {
            Path        = "C:\Temp\WebApp\Archive.zip"
            Destination = "C:\inetpub\wwwroot"
            Ensure      = "Present"
            DependsOn   = "[Script]PrepareWebSiteContent"
        }

        # Install vcredist (php dependency)
        Script InstallVcRedist
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

            DependsOn = "[File]VcRedistDir"
        }

        # Install php with PhpManager module
        Script InstallPhp
        {
            GetScript = {
                return @{
                    Result = [String](php -v)
                }
            }

            TestScript = {
                return (Test-Path -Path "C:\PHP") -and (php -v)
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
                    -Path "C:\PHP" `
                    -TimeZone UTC `
                    -AddToPath User
            }

            DependsOn = "[Script]InstallVcRedist"
        }

        # Delete default website from IIS and create a new one with our website
        Script ConfigureWebsite
        {
            GetScript = {
                return @{
                    Result = "N/A"
                }
            }

            TestScript = {
                Import-Module -Name IISAdministration
                return [Bool](Get-IISSite -Name "php-mysql-crud")
            }

            SetScript = {
                Import-Module -Name IISAdministration

                Start-IISCommitDelay
                Remove-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:80:"
                Remove-IISSite -Name "Default Web Site" -Verbose -Confirm:$false
                Stop-IISCommitDelay

                New-IISSite `
                    -Name "php-mysql-crud" `
                    -PhysicalPath "C:\inetpub\wwwroot\php-mysql-crud-master" `
                    -BindingInformation "*:80:" `
                    -Protocol HTTP
            }

            DependsOn = @("[WindowsFeature]WebManagementScripts", "[Script]InstallPhp", "[Archive]UnzipWebSite")
        }

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
    }
}
