# Login-AzureRmAccount

Write-Host "AdminUser"
$admincredentials = Get-Credential


$recreate=$false
$resourceGroupName = "AutomatedLab"
$octopusDscScript = "OctopusServerConfiguration.ps1"
$teamcityDscScript = "TeamCityServerConfiguration.ps1"

$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName
if($recreate){
    Write-Host "Removing Resource Group $resourceGroupName..."
    Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
    Write-Host "Creating Resource Group"
    New-AzureRmResourceGroup -Name $resourceGroupName -Location WestEurope
}

Write-Host "Deploying Core..."
$coreOutput = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
-TemplateFile .\ARM\coreDeploy.json `
-TemplateParameterObject @{"resourceName" = $resourceGroupName }
Write-Host "Done"

Write-Host "Publishing DscConfiguration..."
$octopusDscPath = Publish-AzureRmVMDscConfiguration -ConfigurationPath ".\DSC\$octopusDscScript" `
-ResourceGroupName $resourceGroupName -StorageAccountName `
$coreOutput.Outputs["storageAccountName"].Value -force

$teamcityDscPath = Publish-AzureRmVMDscConfiguration -ConfigurationPath ".\DSC\$teamcityDscScript" `
-ResourceGroupName $resourceGroupName -StorageAccountName `
$coreOutput.Outputs["storageAccountName"].Value -force
Write-Host "Done"

Write-Host "Creating storage token..."
$storageAccountContext = New-AzureStorageContext -StorageAccountName $coreOutput.Outputs["storageAccountName"].Value -StorageAccountKey $coreOutput.Outputs["storageAccountKey"].Value
# Create a SAS token for the storage container - this gives temporary read-only access to the container (defaults to 1 hour).
# $ArtifactsLocationSasToken = New-AzureStorageAccountSASToken -Service Blob -ResourceType Container -Permission r -Context $storageAccountContext
$ArtifactsLocationSasToken = New-AzureStorageContainerSASToken -Name "windows-powershell-dsc" -Permission r -Context $storageAccountContext
$ArtifactsLocationSasToken = ConvertTo-SecureString $ArtifactsLocationSasToken.ToString() -AsPlainText -Force
Write-Host "Done"

Write-Host "Deploying Databases..."
$dbOutput = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
-TemplateFile .\ARM\databaseDeploy.json `
-TemplateParameterObject @{"resourceName" = $resourceGroupName; "adminUsername" = $admincredentials.UserName; "adminPassword" = $admincredentials.Password}
Write-Host "Done"

Write-Host "Deploying Octopus..."
$templateParameter = @{"resourceName" = $resourceGroupName; "adminUsername" = $admincredentials.UserName;`
"storageAccountName" = $coreOutput.Outputs["storageAccountName"].Value;`
"diagnoseStorageAccountName" = $coreOutput.Outputs["diagnoseStorageAccountName"].Value;`
"virtualNetworkName" = $coreOutput.Outputs["virtualNetworkName"].Value;`
"networkSecurityGroupName" = $coreOutput.Outputs["networkSecurityGroupName"].Value;`
"octopusDscPath" = "$octopusDscPath";`
"octopusDscScript" = $octopusDscScript; `
"databaseServer" = $dbOutput.Outputs["databaseObject"].Value.fullyQualifiedDomainName;`
"octopusDatabase" = "octopus"`
}

$templateParameter.Add("sasToken", $ArtifactsLocationSasToken)
$templateParameter.Add("adminPassword", $admincredentials.Password)
$octopusOutput = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
    -TemplateFile .\ARM\octopusDeploy.json `
    -TemplateParameterObject $templateParameter
Write-Host "Done"

Write-Host "Deploying Teamcity..."
$teamcityTemplateParameter = @{"resourceName" = $resourceGroupName; "adminUsername" = $admincredentials.UserName;`
"storageAccountName" = $coreOutput.Outputs["storageAccountName"].Value;`
"diagnoseStorageAccountName" = $coreOutput.Outputs["diagnoseStorageAccountName"].Value;`
"virtualNetworkName" = $coreOutput.Outputs["virtualNetworkName"].Value;`
"networkSecurityGroupName" = $coreOutput.Outputs["networkSecurityGroupName"].Value;`
"teamcityDscPath" = "$teamcityDscPath";`
"teamcityDscScript" = $teamcityDscScript; `
}

$teamcityTemplateParameter.Add("sasToken", $ArtifactsLocationSasToken)
$teamcityTemplateParameter.Add("adminPassword", $admincredentials.Password)
$teamcityOutput = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
    -TemplateFile .\ARM\teamcityDeploy.json `
    -TemplateParameterObject $teamcityTemplateParameter
Write-Host "Done"


