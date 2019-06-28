function GetDistance ($boundingBoxText)
{
    #create X,Y coordinates out of the top/left of detected bounding boxes    
    $numberArray = $boundingBoxText -split ","
    $x = [int] $numberArray[0]
    $y = [int] $numberArray[1]

    #calculate distance and return it
    #assumes origin is 0,0    
    [math]::Sqrt([math]::Pow($x, 2) + [math]::Pow($y, 2))
}

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
    for ($i = 0; $i -lt $jsonObject.regions.lines.Count; $i++) 
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

#cognitive services info
$subscriptionKey = "13513c354a7740d3ad5c3f29f6c12f00"
$baseUrl = "https://southcentralus.api.cognitive.microsoft.com/"
$apiSuffix = "vision/v2.0/ocr"
$apiOptions = "?language=en&detectOrientation=true"

#storage account info. Storage that contains the images to be analyzed
$storageAccountName = "cbreimgrepo"
$sasToken = "sv=2018-03-28&ss=bfqt&srt=sco&sp=rwdlacup&st=2019-06-21T19%3A48%3A13Z&se=2019-08-22T19%3A48%3A00Z&sig=Do8Kk8JTOmn3oSc3ykodz6gNpZQo9T3e3QHAIro9IEg%3D"
$sasQueryString = "?$sasToken"
$blobContainerUrl = "https://cbreimgrepo.blob.core.windows.net/imgs/"
#$blobName = "740618.jpg"
#$blobFullUrl = $blobContainerUrl + $blobName + $sasQueryString

#web request parameters
$headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey";
                "Content-Type"="application/json"
}

#loop thru all folders and analyze all images
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
$outputTableName = "ocrresult"
#$outputTable = (Get-AzStorageTable -Name $outputTableName -Context $storageContext).CloudTable

#"" > "D:\work\cbre\ai\ocr\summary.txt"

foreach ($blob in Get-AzStorageBlob -Context $storageContext -Container "imgs" -Prefix "nameplate-other") 
{
    Write-Output "Analyzing $($blob.Name) ..."    
    
    $blobFullUrl = $blobContainerUrl + $blob.Name + $sasQueryString
    $body = "{""url"":""$blobFullUrl""}"
    $url = $baseUrl + $apiSuffix + $apiOptions
 
    $responseRaw = (curl -Uri $url -Headers $headers -Body $body -Method Post).Content
    $response = $responseRaw | ConvertFrom-Json

    $rowKey = $blob.Name.Replace("/","-")

    #extract manufacturer, serial number and model number
    #$data = ExtractData($response)

    #$msg = "Detected: MN=$($data.ModelNumber); SN=$($data.SerialNumber); CO=$($data.Manufacturer) for $rowkey"
    #Write-Output $msg
    #$msg >> "D:\work\cbre\ai\ocr\summary_all.txt"

    #also write to file
    $responseRaw > "D:\work\cbre\ai\ocr\results\$($rowKey).json"
} 

