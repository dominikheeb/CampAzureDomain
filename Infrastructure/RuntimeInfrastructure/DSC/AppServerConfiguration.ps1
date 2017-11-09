Configuration AppServer
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $octopusServer,

        [Parameter(Mandatory = $true)]
        [securestring] $apiKey,

        [Parameter(Mandatory = $true)]
        [string] $sitename,

        [Parameter(Mandatory = $true)]
        [string] $sitepath
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xComputerManagement
    Import-DscResource -Module xWebAdministration

    Node "localhost"
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        xPowerPlan SetPlanHighPerformance
        {
            IsSingleInstance = 'Yes'
            Name             = 'High performance'
        }

        WindowsFeature IIS
        {
            Ensure = 'Present'
            Name   = "Web-Server"
        }

        xWebsite DefaultSite
        {
            Ensure          = "Absent"
            Name            = "Default Web Site"
            State           = "Stopped"
            PhysicalPath    = "C:\inetpub\wwwroot"
            DependsOn       = "[WindowsFeature]IIS"
        }

        xWebsite NewWebsite
        {
            Ensure          = "Present"
            Name            = $sitename
            State           = "Started"
            PhysicalPath    = $sitepath
            DependsOn       = "[xWebsite]DefaultSite"
            BindingInfo     = MSFT_xWebBindingInformation
            {
                Protocol              = 'http'
                Port                  = '80'
                HostName              = "localhost"
                IPAddress             = '*'
            }
        }
    }
}