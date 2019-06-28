function ExtractData ($jsonObject)
{
    #this function expects the json object to follow the OCR schema

    #loop thru the collection of boxes and words to assign distance from top left corner
    #$array = @()

    #foreach ($item in $jsonObject.regions.lines.words) 
    #{
    #    $distance = GetDistance($item.boundingBox)
    #    $array += New-Object PSCustomObject -Property @{
    #        distance=$distance;
    #        boundingBox=$item.boundingBox;
    #        text=$item.text
    #    }
    #}

    #sort by distance
    #$array = $array | sort distance
    
    #usually the first text detected is the manufacturer
    $manufacturer = $jsonObject.regions.lines.words.text[0]

    #usually the model number is the next text detected after the keyword MIN
    #we'll search using the given order wich already is from top/left to bottom/right
    for ($i = 0; $i -lt $jsonObject.regions.lines.words.Count; $i++) 
    {       
        if ($jsonObject.regions.lines.words[$i].text -like "*M?N*" -or 
            $jsonObject.regions.lines.words[$i].text -like "*MOD*" ) 
        {
            $modelNumber = $jsonObject.regions.lines.words[$i+1].text
            break;
        }
    }

    #same for serial number
    for ($j = 0; $j -lt $jsonObject.regions.lines.words.Count; $j++) 
    {       
        if ($jsonObject.regions.lines.words[$j].text -like "*S?N*" -or 
            $jsonObject.regions.lines.words[$i].text -like "*SER*") 
        {
            $serialNumber = $jsonObject.regions.lines.words[$j+1].text
            break;
        }
    }
    
    New-Object -TypeName PSCustomObject -Property @{
        manufacturer = $manufacturer;
        modelNumber = $modelNumber;
        serialNumber = $serialNumber;
    }
}

Function RecognizeText($baseUrl, $imgUrl)
{
    $apiSuffix = "vision/v2.0/recognizeText"
    $apiOptions = "?mode=Printed"

    #web request parameters
    $headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey";
                    "Content-Type"="application/json"
    }
    $body = "{""url"":""$imgUrl""}"
    $url = $baseUrl + $apiSuffix + $apiOptions

    $response = Invoke-WebRequest -Uri $url -Headers $headers -Body $body -Method Post
    $response.Headers["Operation-location"]
}

function GetRecognizeTextOperationResult ($operationLocation) 
{
    do 
    {
        Start-Sleep -Seconds 3
        $headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey"                        
        }
        $responseRaw = (Invoke-WebRequest -Uri $operationLocation -Headers $headers -Method Get).Content
        $response = $responseRaw | ConvertFrom-Json        
    } while ($response.status -in ("Running", "NotStarted"))

    if ($response.status -eq "Succeeded") 
    {
        return $responseRaw
    }
    else 
    {
        return $null
    }
}

#cognitive services info
$subscriptionKey = "13513c354a7740d3ad5c3f29f6c12f00"
$baseUrl = "https://southcentralus.api.cognitive.microsoft.com/"

#storage account info. Storage that contains the images to be analyzed
$storageAccountName = "cbreimgrepo"
$sasToken = "sv=2018-03-28&ss=bfqt&srt=sco&sp=rwdlacup&st=2019-06-21T19%3A48%3A13Z&se=2019-08-22T19%3A48%3A00Z&sig=Do8Kk8JTOmn3oSc3ykodz6gNpZQo9T3e3QHAIro9IEg%3D"
$sasQueryString = "?$sasToken"
$blobContainerUrl = "https://cbreimgrepo.blob.core.windows.net/imgs/"
#$blobName = "3a27326a3678439b9a92712438efefb2.jpg"
#$blobFullUrl = $blobContainerUrl + $blobName + $sasQueryString

#loop thru all folders and analyze all images
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken

#$outputTableName = "ocrresult"
#$outputTable = (Get-AzStorageTable -Name $outputTableName -Context $storageContext).CloudTable

#$summaryFile = "C:\work\cbre\textapi_summary.txt"
#"" > $summaryFile

 foreach ($blob in Get-AzStorageBlob -Context $storageContext -Container "imgs" -Prefix "nameplate-york") 
 {    
     $blobFullUrl = $blobContainerUrl + $blob.Name + $sasQueryString     
     $blobName = $blob.Name.Replace("/","-")
 
     Write-Output "Analyzing img $blobName ..."

     $operationLocation = RecognizeText $baseUrl $blobFullUrl

     $response = GetRecognizeTextOperationResult $operationLocation          
     
     $response >> "C:\work\cbre\results\$($blobName).json"
     $response = $response | ConvertFrom-Json

     Write-Output "Analysis complete for $blobName"
#     #extract manufacturer, serial number and model number

#     $data = ExtractData($response)

#     $msg = "Detected: MN=$($data.ModelNumber); SN=$($data.SerialNumber); CO=$($data.Manufacturer) for $rowkey"
#     Write-Output $msg
#     $msg >> $summaryFile

#     #also write to file
#     $responseRaw > "D:\work\cbre\ai\ocr\results\$($rowKey).json"
 } 

