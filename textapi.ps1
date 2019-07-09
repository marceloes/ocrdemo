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

function ExtractModelSerialData ($array, $regEx, $cleanupRegexArray)
{
    $found = $false
    $responses = @()
    for ($i = 0; ($i -lt $array.Count) -and !($found); $i++) 
    {
        if ($array[$i].text.ToUpper() -match $regEx -and ! $found)       
        {
            $found = $true
            $text = ($array[$i].text -replace $regEx,"").Trim().ToUpper()
            foreach ($regExItem in $cleanupRegexArray) 
            {
                $text = ($text -replace $regExItem,"").Trim()
            }
            
            if (($text.length -ge 6) -and ($text.length -lt 50))
            {
                #returned remaining characters as the response
                $responses += $text
            }
            else 
            {
                #return +1 and -1 text in the list as possible matches                
                $responses += $array[$i-1].text
                $responses += $array[$i+1].text
                $responses += $array[$i+2].text
            }           
            $found = $true
        } 
    }  
    return $responses
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
    #$array = $array | Sort-Object y,x
    
    #usually the first text detected is the manufacturer
    $manufacturer = ExtractManufacturer $array
    $modelNumber = @()
    $serialNumber = @()

    switch ($manufacturer)
    {
        "LENNOX" {
                    $modelNumber += ExtractModelSerialData $array "M[I\/]?N" @("\:")  
                    $serialNumber += ExtractModelSerialData $array "S[I\/]?N" @("\:") 
                    break
                 }
        "TRANE"  {
                    $modelNumber += ExtractModelSerialData $array "MOD\.|MODEL" @("VOLTS","[0-9]{3}\/[0-9]{3}","UNIT","NUMBER")  
                    $serialNumber += ExtractModelSerialData $array "SERIAL" @("UNIT","NUMBER") 
                    break
                 }
        "YORK"   {
                    $modelNumber += ExtractModelSerialData $array "UNIT MODEL" @()  
                    $serialNumber += ExtractModelSerialData $array "SERIAL NO\." @() 
                    break
                 }
        "ENGA"   {
                    $modelNumber += ExtractModelSerialData $array "MODELE" @()  
                    $serialNumber += ExtractModelSerialData $array "NUMERO DE SERIE" @() 
                    break
                 }
        "GSW"   {
                    $modelNumber += ExtractModelSerialData $array "MODELE" @("MODEL")  
                    $serialNumber += ExtractModelSerialData $array "NO. DE SERIE" @("SERIAL") 
                    break
                 }
        Default  {  $modelNumber += ExtractModelSerialData $array "MODEL|TYPE" @()  
                    $serialNumber += ExtractModelSerialData $array "SERIAL|NUMERO SERIE" @() 
                    break
                 }
    }

    $data = New-Object -TypeName PSCustomObject -Property @{
        manufacturer = $manufacturer;
        modelNumber = $modelNumber;
        serialNumber = $serialNumber;
    }
    return $data
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
        #Write-host "Waiting for API..."
        Start-Sleep -Seconds 3
        $headers = @{   "Ocp-Apim-Subscription-Key"="$subscriptionKey"                        
        }
        $responseRaw = (Invoke-WebRequest -Uri $operationLocation -Headers $headers -Method Get).Content
        $response = ConvertFrom-Json $responseRaw
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


 foreach ($blob in Get-AzStorageBlob -Context $storageContext -Container "imgs" -Prefix "nameplate-trane") 
 {    
     $blobFullUrl = $blobContainerUrl + $blob.Name + $sasQueryString     
     $blobName = $blob.Name.Replace("/","-")
 
     #Write-Output "Analyzing img $blobName ..."

     $operationLocation = RecognizeText $baseUrl $blobFullUrl

     $response = GetRecognizeTextOperationResult $operationLocation          
     #$response
     $response = $response | ConvertFrom-Json    

     $data = ExtractData $response
     ConvertTo-Json $data

     Write-host -ForegroundColor Green "File : $($blobName) - Data extracted: Manufacturer = $($data.manufacturer); Model = $($data.modelNumber); Serial = $($data.serialNumber)" 

     #$response >> "$resultsPath\$($blobName).json"
     #$response = $response | ConvertFrom-Json

     #Write-Output "Analysis complete for $blobName"
 } 

