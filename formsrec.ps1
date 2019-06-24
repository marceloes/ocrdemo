function TrainModel($blobContainerUrl, $prefix)
{
    $ApiSuffix = "formrecognizer/v1.0-preview/custom/train"

    #web request parameters
    $headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey";
                    "Content-Type"="application/json"
    }
    $body = "{""source"":""$blobContainerUrl"",""sourceFilter"":{""prefix"":""$prefix"",""includeSubFolders"":true}"   
    $url = $baseUrl + $apiSuffix
    $response = (curl -Uri $url -Headers $headers -Body $body -Method Post).Content | ConvertFrom-Json

    #Return Model Id
    $response.modelId
}

function AnalyzeForm($modelId, $blobContainerUrl)
{
    $ApiSuffix = "formrecognizer/v1.0-preview/custom/models/$modelId/analyze"
    #web request parameters
    $headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey";
                    "Content-Type"="application/json"
    }
    $url = $baseUrl + $apiSuffix
    $response = (curl -Uri $url -Headers $headers -Method Post).Content | ConvertFrom-Json

    $status = $response.status

    #TBD
}
#cognitive services info
$subscriptionKey = "<enter sub key>"
$baseUrl = "https://southcentralus.api.cognitive.microsoft.com/"

#storage account info. Storage that contains the images to be analyzed
$storageAccountName = "cbreimgrepo"
$sasToken = "sv=2018-03-28&ss=bfqt&srt=sco&sp=rwdlacup&st=2019-06-21T19%3A48%3A13Z&se=2019-08-22T19%3A48%3A00Z&sig=Do8Kk8JTOmn3oSc3ykodz6gNpZQo9T3e3QHAIro9IEg%3D"
$sasQueryString = "?$sasToken"
$blobContainerUrl = "https://cbreimgrepo.blob.core.windows.net/imgs/"

#loop thru all folders and analyze all images
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
$outputTableName = "ocrresult"
#$outputTable = (Get-AzStorageTable -Name $outputTableName -Context $storageContext).CloudTable

"" > "D:\work\cbre\ai\ocr\summary.txt"

foreach ($blob in Get-AzStorageBlob -Context $storageContext -Container "imgs" -Prefix "nameplate-trane") 
{    
    $blobFullUrl = $blobContainerUrl + $blob.Name + $sasQueryString
    $body = "{""url"":""$blobFullUrl""}"
    $url = $baseUrl + $apiSuffix + $apiOptions
 
    $responseRaw = (curl -Uri $url -Headers $headers -Body $body -Method Post).Content
    $response = $responseRaw | ConvertFrom-Json

    #this one below needs module AzTable to be installed
    $rowKey = $blob.Name.Replace("/","-")
    $prop = @{"json"=$response}
    #Add-AzTableRow -Table $outputTable -PartitionKey "ptkey1" -RowKey $rowKey -property $prop -UpdateExisting

    #extract manufacturer, serial number and model number

    $data = ExtractData($response)

    $msg = "Detected: MN=$($data.ModelNumber); SN=$($data.SerialNumber); CO=$($data.Manufacturer) for $rowkey"
    Write-Output $msg
    $msg >> "D:\work\cbre\ai\ocr\summary_all.txt"

    #also write to file
    $responseRaw > "D:\work\cbre\ai\ocr\results\$($rowKey).json"
} 

