Configuration OctopusServer
{
    param (
        [Parameter(Mandatory = $true)]
        [pscredential] $OctopusAdminCredentials,

        [Parameter(Mandatory = $true)]
        [string] $octopusDatabase,

        [Parameter(Mandatory = $true)]
        [string] $databaseServer
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xComputerManagement
    Import-DscResource -Module xSQLServer
    Import-DscResource -Module OctopusDSC

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
        
        cOctopusServer OctopusServer
        {
            Ensure = "Present"
            State = "Started"

            # Server instance name. Leave it as 'OctopusServer' unless you have more
            # than one instance
            Name = "OctopusServer"

            # The url that Octopus will listen on
            WebListenPrefix = "http://$($databaseServer):81"
            
            SqlDbConnectionString = "Data Source=tcp:$databaseServer,1433;Database=$octopusDatabase;User Id=$($OctopusAdminCredentials.UserName)@$databaseServer;Password=$($OctopusAdminCredentials.GetNetworkCredential().Password);Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
            # The admin user to create
            OctopusAdminUsername = $OctopusAdminCredentials.UserName
            OctopusAdminPassword = $($OctopusAdminCredentials.GetNetworkCredential().Password)

            # optional parameters
            AllowUpgradeCheck = $true
            AllowCollectionOfAnonymousUsageStatistics = $false
            ForceSSL = $false
            ListenPort = 10943
            DownloadUrl = "https://octopus.com/downloads/latest/WindowsX64/OctopusServer"   

            HomeDirectory = "C:\Octopus"
        }
        
        cOctopusServerUsernamePasswordAuthentication "Enable Username/Password Auth"
        {
            InstanceName = "OctopusServer"
            Enabled = $true
        }
    }
}

