#param($rg, $location, $subscription, $cogSvcName, $storageAcctName, $functionAppName)
$rg = "apim-demo-rg"
$location = "southcentralus"
$subscription = "<your subcription name>"
$cogSvcName = "cogsvcdemo1"
$storageAcctName = "recogstgacct1"
$functionAppName = "nameplaterecognizerfunctionapp"

Write-host "Login to Azure and proper subscription"
az login

Write-host "Connect to Azure and proper subscription"
az account set -s $subscription

Write-host "create resource group"
az group create --name $rg --location $location

Write-host "create cognitive services instance"
$cogSvc = az cognitiveservices account create --kind "cognitiveservices" `
                                    --location $location `
                                    --name $cogSvcName `
                                    --resource-group $rg `
                                    --sku "S0" `
                                    --yes

if (! $cogSvc) {
    $cogSvc = az cognitiveservices account show --name $cogSvcName --resource-group $rg
}


$cogSvcEndpoint = ($cogSvc | ConvertFrom-Json).properties.endpoint

$cogSvcKey = (az cognitiveservices account keys list --name $cogSvcName -g $rg | ConvertFrom-Json).key1

Write-host "create storage for function app"
$storageAcct = az storage account create --name $storageAcctName `
                          --resource-group $rg `
                          --location $location `
                          --sku "Standard_LRS" `
                          --kind "StorageV2"
$storageAcct = $storageAcct | ConvertFrom-Json

Write-host "create function using az cli"
az functionapp create --name $functionAppName `
                      --storage-account $storageAcctName `
                      --consumption-plan-location $location `
                      --resource-group $rg 


Write-host "deploy function app"
$pathToFunction = "..\NameplateRecognizerFunction"
Push-Location $pathToFunction

func azure functionapp publish $functionAppName --force

Write-host "configure cognitive services connectivity settings"
az functionapp config appsettings set --settings "COGNITIVE_SERVICES_BASE_URL=$cogSvcEndpoint" "COGNITIVE_SERVICES_SUBSCRIPTION_KEY=$cogSvcKey" `
                                      --name $functionAppName `
                                      --resource-group $rg

Pop-Location

#get function URL so the Flow can be updated to call it
func azure functionapp list-functions $functionAppName --show-keys

# To get the organization URL from Power Platforms.
# 

# Navigate to Power Apps home page
# Click Settings menu
# Then click Session Details to open the Power Apps session details dialog box
# Click Copy Details button and paste it in notepad

# Make sure you're authenticated to Power Platforms
# pac auth create --url https://<your-org>.crm.dynamics.com

# pac solution export --path NameplatePowerAppSolution.zip --name NameplateSolution --managed false --incldue general
