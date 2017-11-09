Configuration TeamcityServer
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xComputerManagement
    Import-DscResource -Module cChoco

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
        
        cChocoInstaller installChoco
        {
            InstallDir = "c:\choco"
        }

        cChocoPackageInstaller JDKInstall
        {
           Ensure = 'Present'
           Name = "jdk8"
           DependsOn = "[cChocoInstaller]installChoco"
        }

        cChocoPackageInstaller TeamCity
        {
           Ensure = 'Present'
           Name = "teamcity"
           DependsOn = "[cChocoInstaller]installChoco"
        }
    }
}