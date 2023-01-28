Configuraion IISPhp
{
    param
    (
        [string]$NodeName="localhost",
        [Parameter(Mandatroy=$true)][string]$PhpProjectUrl
    )

    Import-DscResource -ModuleName PsDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration
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
            Ensure = "Present"
            Path   = "C:\inetpub\wwwroot"
            Source = $PhpProjectUrl
        }
    }
}
