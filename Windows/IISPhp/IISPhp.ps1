Configuration IISPhp
{
    param
    (
        [string]$NodeName="localhost",
        [string]$PhpProjectUrl
    )

    Import-DscResource -ModuleName PsDesiredStateConfiguration
    # Import-DscResource -ModuleName xWebAdministration
    # Import-DscResource -ModuleName xPhp

    Node $NodeName
    {
        WindowsFeature WebServerRole
        {
            Ensure = "Present"
            Name   = "Web-Server"
        }

        WindowsFeature WebManagementService {
            Name   = "Web-Mgmt-Service"
            Ensure = "Present"
        }

        File WebSite
        {
            Ensure            = "Present"
            DestinationPath   = "C:\inetpub\wwwroot"
            SourcePath        = $PhpProjectUrl
            DependsOn         = "[WindowsFeature]WebServerRole"
        }
    }
}
