function CleanupModels
{
    #Retrieve all models
    $ApiSuffix = "formrecognizer/v1.0-preview/custom/models"
    $headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey";
                    "Content-Type"="application/json"
    }
    $url = $baseUrl + $apiSuffix
    $response = (Invoke-WebRequest -Uri $url -Headers $headers -Method Get).Content | ConvertFrom-Json

    #Delete each model    
    foreach ($model in $response.models) 
    {
        Write-Output "Deleting model $($model.modelId)"
        $ApiSuffix = "formrecognizer/v1.0-preview/custom/models/$($model.modelId)"
        $url = $baseUrl + $apiSuffix
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Delete
    }
}
function TrainModel($blobContainerUrl, $prefix)
{
    Write-host "Training model for $blobContainerUrl"
    $ApiSuffix = "formrecognizer/v1.0-preview/custom/train"
    $headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey";
                    "Content-Type"="application/json"
    }
    $body = "{""source"":""$blobContainerUrl"",""sourceFilter"":{""prefix"":""$prefix"",""includeSubFolders"":true}}"   
    $url = $baseUrl + $apiSuffix
    $response = (Invoke-WebRequest -Uri $url -Headers $headers -Body $body -Method Post).Content

    $response > "D:\Work\CBRE\AI\test-forms-results\$manufacturerInput\TRAIN-MODEL-RESPONSE.json"

    $response = $response | ConvertFrom-Json

    #Return Model Id
    write-host "Model id = " + $response.modelId
    $response.modelId
}

function AnalyzeForm($modelId, $fileName, $contentType)
{
    $ApiSuffix = "formrecognizer/v1.0-preview/custom/models/$modelId/analyze"
    #web request parameters
    $headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey";
                    "Content-Type"="multipart/form-data"
    }
    $url = $baseUrl + $apiSuffix
    $response = (Invoke-WebRequest -Uri $url -Headers $headers -Method Post -InFile $fileName -ContentType $contentType).Content
    $response
}

function ExtractDataFromModel ($jsonObject)
{
    #this function expects the json object to follow the Forms Recognizer schema    

    #The model number is the next text detected after the keyword M/N
    foreach ($item in $jsonObject.pages[0].keyvaluepairs) 
    {
        if ($item.key.text -eq "M/N:") 
        {
            $modelNumber = $item.value.text
            break
        }
    }

    #The serial number is the next text detected after the keyword S/N
    foreach ($item in $jsonObject.pages[0].keyvaluepairs) 
    {
        if ($item.key.text -eq "S/N:") 
        {
            $serialNumber = $item.value.text
            break
        }
    }
   
    New-Object -TypeName PSCustomObject -Property @{        
        modelNumber = $modelNumber;
        serialNumber = $serialNumber;
    }
}

function GetModelKeys ($modelId)
{
    $ApiSuffix = "formrecognizer/v1.0-preview/custom/models/$modelId/keys"
    #web request parameters
    $headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey"
    }
    $url = $baseUrl + $apiSuffix
    $response = (Invoke-WebRequest -Uri $url -Headers $headers -Method Get).Content    
    $response
}

#cognitive services info
$subscriptionKey = "325c43ac82164028a440ed12e7ecdd96"
$baseUrl = "https://westus2.api.cognitive.microsoft.com/"

#storage account info. Storage that contains the images to be analyzed
$storageAccountName = "cbreimgrepo"
$sasToken = "sv=2018-03-28&ss=bfqt&srt=sco&sp=rwdlacup&st=2019-06-21T19%3A48%3A13Z&se=2019-08-22T19%3A48%3A00Z&sig=Do8Kk8JTOmn3oSc3ykodz6gNpZQo9T3e3QHAIro9IEg%3D"
$sasQueryString = "?$sasToken"

#loop thru all folders and analyze all images
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
#$outputTableName = "ocrresult"
#$outputTable = (Get-AzStorageTable -Name $outputTableName -Context $storageContext).CloudTable

$manufacturerInput = "york"
$prefix = "$manufacturerInput-train"
$blobContainerUrl = "https://cbreimgrepo.blob.core.windows.net/imgs/$sasQueryString"

#Clean up model if needed
CleanupModels

#Train model with 17 images
$modelId = TrainModel $blobContainerUrl $prefix
#$modelIdLennox = "6b2ccb3a-8470-487d-8c5c-b28f006a199e"

GetModelKeys $modelId

#test model
#$modelIdLennox = "b7322cf3-f81d-45ab-9a76-c2f97d40d095"

foreach ($item in (Get-ChildItem -Path "D:\Work\CBRE\AI\testimgs\nameplate-$manufacturerInput")) 
{
    Write-Output "Analyzing $($item.Name) ..."

    if ($item.Name -match "jpg")
    {
        $imageType = "image/jpeg"
    }
    else 
    {
        $imageType = "image/png"
    }
    $result = AnalyzeForm $modelId $item.FullName $imageType
    $result > "D:\Work\CBRE\AI\test-forms-results\$manufacturerInput\$($item.Name).json"
}

#ExtractDataFromModel $result


