#param($rg, $location)
$rg = "cbreai-test-rg"
$location = "canadacentral"
$subscription = "MS - Microsoft Azure Internal Consumption"
$cogSvcName = "cbrecogtst1"
$storageAcctName = "cbrefunctstoragetst1"
$app = "nameplaterecognizer"
$functionAppName = $app + "functionapp"
$appServicePlanSku = "EP1"
$appServicePlanName = $app + "svcplan" + $appServicePlanSku

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

#create premium app service plan with pre-warmed instances
az functionapp plan create --name $appServicePlanName `
                           --resource-group $rg `
                           --location $location `
                           --sku $appServicePlanSku `
                           --min-instances 1 `
                           --max-burst 10                           
                        
#create function using az cli
az functionapp create --name $functionAppName `
                      --storage-account $storageAcctName `
                      --plan $appServicePlanName `
                      --os-type Windows `
                      --resource-group $rg 

#deploy function app
$pathToFunction = "./NameplateRecognizerFunction"
Push-Location $pathToFunction

func azure functionapp publish $functionAppName --force

#configure cognitive services connectivity settings
az functionapp config appsettings set --settings "COGNITIVE_SERVICES_BASE_URL=$cogSvcEndpoint" "COGNITIVE_SERVICES_SUBSCRIPTION_KEY=$cogSvcKey" `
                                      --name $functionAppName `
                                      --resource-group $rg

Pop-Location

#get function URL so the Flow can be updated to call it
func azure functionapp list-functions $functionAppName --show-keys

#set pre-warmed instance count to 1
az resource update --resource-group $rg `
                   --name "$functionAppName/config/web" `
                   --set properties.preWarmedInstanceCount=2 `
                   --resource-type Microsoft.Web/sites --debug
                   
