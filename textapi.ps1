function ExtractManufacturer($array)
{
    $list = @("LENNOX","YORK","TRANE","ENGA","SDMO","ONON","CLEAVER","NRTL","MARATHON","GSW","MITSUBISHI","CARRIER","MCQUAY","WALCHEM","KOHLER","SIEMENS")
    foreach ($item in $list) 
    {
        if (($array.text -match $item).length -gt 0)
        {
            return $item
        }            
    }
    #take a guess using the first recognized text item
    return $array[0].text
}

function ExtractAnyManufacturerData ($array, $regEx, $cleanupRegexArray)
{
    $found = $false
    for ($i = 0; ($i -lt $array.Count) -and !($found); $i++) 
    {
        if ($array[$i].text -match $regEx -and ! $found)       
        {
            $found = $true
            $text = ($array[$i].text -replace $regEx,"").Trim()
            foreach ($regExItem in $cleanupRegexArray) 
            {
                $text = ($text -replace $regExItem,"").Trim()
            }

            #remove original ocurrence
            if ($text.length -gt 6)
            {
                return $text
            }
            else 
            {
                if ($array[$i+1].text.length -gt 8)
                {
                    return $array[$i+1].text
                }
                else 
                {
                    return $array[$i-1].text
                }
            }           
            $found = $true
        } 
    }  
}

function ExtractData ($jsonObject)
{
    #this function expects the json object to follow the OCR schema

    #loop thru the collection of boxes and words to assign distance from top left corner
    $array = @()

    foreach ($item in $jsonObject.recognitionResult.lines) 
    {
       $x = $item.boundingBox[0]
       $y = $item.boundingBox[1]

       $array += New-Object PSCustomObject -Property @{
           x=$x;
           y=$y;
           boundingBox=$item.boundingBox;
           text=$item.text.Trim()
       }
    }

    #sort by vertical distance then left-right
    $array = $array | Sort-Object y,x
    
    #usually the first text detected is the manufacturer
    $manufacturer = ExtractManufacturer $array

    # switch ($manufacturer)
    # {
    #     "LENNOX" {$data = ExtractLennoxData $array; break}
    #     "TRANE"  {$data = ExtractTraneData $array; break}
    #     "YORK"   {$data = ExtractYorkData $array; break}
    #     Default  {$data = ExtractOtherData $array; break}
    # }

    switch ($manufacturer)
    {
        "LENNOX" {
                    $modelNumber = ExtractAnyManufacturerData $array "M[I\/]?N" @("\:")  
                    $serialNumber = ExtractAnyManufacturerData $array "S[I\/]?N" @("\:") 
                    break
                 }
        "TRANE"  {
                    $modelNumber = ExtractAnyManufacturerData $array "MOD\.|MODEL" @("VOLTS","[0-9]{3}\/[0-9]{3}")  
                    $serialNumber = ExtractAnyManufacturerData $array "SERIAL" @() 
                    break
                 }
        "YORK"   {
                    $modelNumber = ExtractAnyManufacturerData $array "UNIT MODEL" @()  
                    $serialNumber = ExtractAnyManufacturerData $array "SERIAL NO\." @() 
                    break
                 }

        Default  {  $modelNumber = ExtractAnyManufacturerData $array "MODEL" @()  
                    $serialNumber = ExtractAnyManufacturerData $array "SERIAL" @() 
                    break
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
        Write-host "Waiting for API..."
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

#$resultsPath = "D:\Work\CBRE\AI\test-recog-results\lennox"

 foreach ($blob in Get-AzStorageBlob -Context $storageContext -Container "imgs" -Prefix "nameplate-lennox") 
 {    
     $blobFullUrl = $blobContainerUrl + $blob.Name + $sasQueryString     
     $blobName = $blob.Name.Replace("/","-")
 
     Write-Output "Analyzing img $blobName ..."

     $operationLocation = RecognizeText $baseUrl $blobFullUrl

     $response = GetRecognizeTextOperationResult $operationLocation          
     #$response
     $response = $response | ConvertFrom-Json    

     $data = ExtractData $response
     Write-output "File : $($blobName) - Data extracted: Manufacturer = $($data.manufacturer); Model = $($data.modelNumber); Serial = $($data.serialNumber)" 

     #$response >> "$resultsPath\$($blobName).json"
     #$response = $response | ConvertFrom-Json

     Write-Output "Analysis complete for $blobName"
#     #extract manufacturer, serial number and model number

#     $data = ExtractData($response)

#     $msg = "Detected: MN=$($data.ModelNumber); SN=$($data.SerialNumber); CO=$($data.Manufacturer) for $rowkey"
#     Write-Output $msg
#     $msg >> $summaryFile

#     #also write to file
#     $responseRaw > "D:\work\cbre\ai\ocr\results\$($rowKey).json"
 } 

