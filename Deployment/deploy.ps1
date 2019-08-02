#param($rg, $location)
$rg = "cbreai-test-rg"
$location = "canadacentral"
$subscription = "MS - Microsoft Azure Internal Consumption"
$cogSvcName = "cbrecogtst1"
$storageAcctName = "cbrefunctstoragetst1"
$functionAppName = "nameplaterecognizerfunctionapp"

#Connect to Azure and proper subscription
az account set -s $subscription

#create resource group
az group create --name $rg --location $location

#create cognitive services instance
$cogSvc = az cognitiveservices account create --kind "cognitiveservices" `
                                    --location $location `
                                    --name $cogSvcName `
                                    --resource-group $rg `
                                    --sku "S0" `
                                    --yes

$cogSvcEndpoint = ($cogSvc | ConvertFrom-Json).endpoint

$cogSvcKey = (az cognitiveservices account keys list --name $cogSvcName -g $rg | ConvertFrom-Json).key1

#create storage for function app
$storageAcct = az storage account create --name $storageAcctName `
                          --resource-group $rg `
                          --location $location `
                          --sku "Standard_LRS" `
                          --kind "StorageV2"
$storageAcct = $storageAcct | ConvertFrom-Json

#create function using az cli
az functionapp create --name $functionAppName `
                      --storage-account $storageAcctName `
                      --consumption-plan-location $location `
                      --resource-group $rg 


#deploy function app
$pathToFunction = "D:\Work\CBRE\NamePlateViewer_Downloaded"
Push-Location $pathToFunction

func azure functionapp publish $functionAppName --force

#configure cognitive services connectivity settings
az functionapp config appsettings set --settings "COGNITIVE_SERVICES_BASE_URL=$cogSvcEndpoint" "COGNITIVE_SERVICES_SUBSCRIPTION_KEY=$cogSvcKey" `
                                      --name $functionAppName `
                                      --resource-group $rg

Pop-Location

#get function URL so the Flow can be updated to call it
func azure functionapp list-functions $functionAppName --show-keys
