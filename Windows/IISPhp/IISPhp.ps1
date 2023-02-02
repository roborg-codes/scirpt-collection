# Usage:
# webConfiguration -WebsitePackageUri https://example.com/app.php.zip -DBServerName myownmysqlserver
# Start-DSConfiguraion -Path .\WebConfiguration\

# TODO:
# 1. Debug IWR error handling in test-script

configuration WebConfiguration
{
    param
    (
        [Parameter(Mandatory)]
        [String]
        $WebsitePackageUri,

        [Parameter(Mandatory)]
        [String]
        $DBServerName,


        [Parameter(Mandatory)]
        [PSCredential]
        $StorageAccount,
        # | username = name of storage account
        # | password = account key

        [Parameter(Mandatory)]
        [String]
        $FileShareName
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

        # Instll FastCGI
        WindowsFeature WebCGI
        {
            Name   = "Web-CGI"
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
                return $False
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

                $VcRedistInstallablesPath = "C:\Temp\Redist"
                $VcList = Get-VcList -Release 2019 -Architecture x86

                Save-VcRedist -VcList $VcList -Path $VcRedistInstallablesPath

                Install-VcRedist `
                    -VcList $VcList `
                    -Path $VcRedistInstallablesPath `
                    -Silent `
                    -Force
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
                    -AddToPath User `
                    -Force

                Enable-PhpExtension mysqli "C:\PHP"
                Enable-PhpExtension openssl "C:\PHP"
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
                try {
                    $StatusCode = Invoke-WebRequest `
                        -Uri "http://127.0.0.1:80/index.php" `
                        -UseBasicParsing | Select-Object -Expand StatusCode
                } catch {
                    $StatusCode = $_.Exception.Response.StatusCode
                }
                return ([int]$StatusCode -eq 200)
            }

            SetScript = {
                Import-Module -Name IISAdministration
                Import-Module -Name WebAdministration

                Remove-IISSiteBinding `
                    -Name "Default Web Site" `
                    -BindingInformation "*:80:" `
                    -ErrorAction SilentlyContinue

                Remove-IISSite `
                    -Name "Default Web Site" `
                    -Verbose -Confirm:$false `
                    -ErrorAction SilentlyContinue

                New-IISSite `
                    -Name "php-mysql-crud" `
                    -PhysicalPath "C:\inetpub\wwwroot\php-mysql-crud-master" `
                    -BindingInformation "*:80:" `
                    -Protocol HTTP `
                    -ErrorAction SilentlyContinue

                Add-WebConfiguration `
                    //defaultDocument/files `
                    "IIS:\Sites\php-mysql-crud" `
                    -AtIndex 0 `
                    -Value @{value="index.php"} `
                    -ErrorAction SilentlyContinue

                $HasCgiHandler = Get-WebHandler `
                    -PSPath "IIS:\Sites\php-mysql-crud" `
                    -Name PHP_FastCgi
                if ($HasCgiHandler) {
                    Set-WebHandler `
                        -PSPath "IIS:\Sites\php-mysql-crud" `
                        -Name "PHP_FastCgi" `
                        -Path "*.php" `
                        -Verb "*" `
                        -Modules "FastCgiModule" `
                        -ScriptProcessor "C:\PHP\php-cgi.exe"
                } else {
                    New-WebHandler `
                        -PSPath "IIS:\Sites\php-mysql-crud" `
                        -Name "PHP_FastCgi" `
                        -Path "*.php" `
                        -Verb "*" `
                        -Modules "FastCgiModule" `
                        -ScriptProcessor "C:\PHP\php-cgi.exe"
                }

                Add-WebConfiguration "System.WebServer/FastCgi" -Value @{
                    FullPath = "C:\PHP\php-cgi.exe"
                } -Force -ErrorAction SilentlyContinue

            }

            DependsOn = @(
                "[WindowsFeature]WebServerRole",
                "[WindowsFeature]WebCGI",
                "[WindowsFeature]WebManagementScripts",
                "[Script]InstallPhp",
                "[Archive]UnzipWebSite"
            )
        }

        # Download ssl certificate and set connection details
        Script SetupMySQLConnector
        {
            GetScript = {
                return @{
                    Result = "N/A"
                }
            }
            TestScript = {
                return $False
            }
            SetScript = {
                $MySQLCertUrl = "https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem"
                Invoke-WebRequest `
                    -URI $MySQLCertUrl `
                    -OutFile "C:\inetpub\wwwroot\php-mysql-crud-master\DigiCertGlobalRootCA.crt.pem"

                $ConnectionModulePath = "C:\inetpub\wwwroot\php-mysql-crud-master\db.php"
                Write-Output @"
<?php
    session_start();

    `$conn = mysqli_init();
    mysqli_ssl_set(`$conn, NULL, NULL, '.\DigiCertGlobalRootCA.crt.pem', NULL, NULL);
    mysqli_real_connect(`$conn, '$using:DBServerName.mysql.database.azure.com', 'main', 'Changemeplease!', 'php_mysql_crud', 3306, MYSQLI_CLIENT_SSL);

    if (mysqli_connect_errno()) {
        die('Failed to connect to MySQL: '.mysqli_connect_error());
    }
?>
"@ | Set-Content -Path $ConnectionModulePath

            }
            DependsOn = @(
                "[Script]ConfigureWebsite"
            )
        }

        Script MountFileShare
        {
            GetScript = {
                return @{
                    Result = [String](Get-PSDrive "X" -PSProvider "Filesystem")
                }
            }
            TestScript = {
                return [Bool](Get-PSDrive "X" -PSProvider "FileSystem")
            }
            SetScript = {
                $StorageAccountName = $using:StorageAccount.UserName
                $StorageAccountKey = $using:StorageAccount.Password | ConvertFrom-SecureString
                $FileShareUNCPath = "\\$StorageAccountName.file.core.windows.net\$FileShareName"

                $ConnectTestResult = Test-NetConnection `
                    -ComputerName $StorageAccountName.file.core.windows.net `
                    -Port 445

                if (-not $ConnectTestResult.TcpTestSucceeded) {
                    Write-Error -Message "Unable to reach the Azure storage account via port 445."
                    return
                }

                # Save the password so the drive will persist on reboot
                cmd.exe /C "cmdkey /add:`"$FileShareUNCPath`" /user:`"localhost\$StorageAccountName`" /pass:`"$StorageAccountKey`""

                # Mount the drive
                New-PSDrive `
                    -Persist `
                    -Name "X" `
                    -PSProvider "FileSystem" `
                    -Root $FileShareUNCPath
            }
        }

    }
}
