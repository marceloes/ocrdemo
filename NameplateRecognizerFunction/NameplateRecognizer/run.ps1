using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

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

function ExtractModelSerial ($array, $regEx, $cleanupRegexArray)
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
    #$modelNumber = ExtractModelSerial $array "M[I\/]{1}N|MOD\. NO\.|UNIT MODEL|MODEL" @("\:","VOLTS","[0-9]{3}\/[0-9]{3}")  
    #$serialNumber = ExtractModelSerial $array "S[I\/]{1}N|SERIAL NO\.|SERIAL" @("\:") 

    switch ($manufacturer)
    {
        "LENNOX" {
                    $modelNumber = ExtractModelSerial $array "M[I\/]?N" @("\:")  
                    $serialNumber = ExtractModelSerial $array "S[I\/]?N" @("\:") 
                    break
                 }
        "TRANE"  {
                    $modelNumber = ExtractModelSerial $array "MOD\.|MODEL" @("VOLTS","[0-9]{3}\/[0-9]{3}","UNIT","NUMBER","NO.")  
                    $serialNumber = ExtractModelSerial $array "SERIAL" @("UNIT","NUMBER", "NO\.") 
                    break
                 }
        "YORK"   {
                    $modelNumber = ExtractModelSerial $array "UNIT MODEL" @()  
                    $serialNumber = ExtractModelSerial $array "SERIAL NO\." @() 
                    break
                 }
        "ENGA"   {
                    $modelNumber = ExtractModelSerial $array "MODELE" @()  
                    $serialNumber = ExtractModelSerial $array "NUMERO DE SERIE" @() 
                    break
                 }
        "GSW"   {
                    $modelNumber = ExtractModelSerial $array "MODELE" @("MODEL")  
                    $serialNumber = ExtractModelSerial $array "NO. DE SERIE" @("SERIAL") 
                    break
                 }
        Default  {  $modelNumber = ExtractModelSerial $array "MODEL|TYPE" @()  
                    $serialNumber = ExtractModelSerial $array "SERIAL|NUMERO SERIE" @() 
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
        $response = $responseRaw | ConvertFrom-Json        
    } while ($response.status -in ("Running", "NotStarted"))

    return $responseRaw
}

#cognitive services info
#$subscriptionKey = "13513c354a7740d3ad5c3f29f6c12f00"
$subscriptionKey = $env:COGNITIVE_SERVICES_SUBSCRIPTION_KEY

#$baseUrl = "https://southcentralus.api.cognitive.microsoft.com/"
$baseUrl = $env:COGNITIVE_SERVICES_BASE_URL

# Interact with query parameters or the body of the request.
Write-Host "Base request object: $Request"
$blobFullUrl = $Request.Query.imageUrl
Write-Host "Query object: $($Request.Query)"
Write-Host "Body object: $($Request.Body)"

if (-not $blobFullUrl) 
{
    $blobFullUrl = $Request.Body.imageUrl
}

if ($blobFullUrl) 
{
    try 
    {
        Write-Host "Blob image url = $blobFullUrl"
        $operationLocation = RecognizeText $baseUrl $blobFullUrl
        $operationResult = GetRecognizeTextOperationResult $operationLocation | ConvertFrom-Json
        Write-Host "Operation result raw: $operationResult"

        if ($operationResult.status -eq "Succeeded")
        {
            $data = ExtractData $operationResult 
            Write-Host "Response from API: $data"
            $data = $data | ConvertTo-Json        
            Write-Host "Response from API (JSON): $data"
            $status = [HttpStatusCode]::OK
            $body = $data     
        }
        else 
        {
            $status = [HttpStatusCode]::BadRequest
            $body = "{""error"":""$($operationResult.status)""}"
        }
    }
    catch 
    {
        $status = [HttpStatusCode]::BadRequest
        $body = $_
    }
    finally 
    {        
    }
}
else 
{
    $status = [HttpStatusCode]::BadRequest
    $body = "Please pass a valid URL (imageUrl) on the query String or body."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})
