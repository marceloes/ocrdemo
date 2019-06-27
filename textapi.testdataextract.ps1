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
    $manufacturer = $jsonObject.recognitionResult.lines[0].text

    #usually the model number is the next text detected after the keyword MIN
    #we'll search using the given order wich already is from top/left to bottom/right

    #TODO:  add logic as follows
    #       once found a string that matches M?N or MOD?? (same for serial)
    #       look for the number on the nearest box, so calculating relative distance to the current box is needed.

    $foundModel = $false
    $foundSerial = $false
    for ($i = 0; ($i -lt $array.Count) -and !($foundModel -and $foundSerial); $i++) 
    {       
        if ($array[$i].text -like "*M?N*") 
        {
            if ($array[$i].text.length -gt 6)
            {
                $modelNumber = $array[$i].text                
            }
            else 
            {
                $modelNumber = $array[$i+1].text
            }           
            $foundModel = $true
        }
        if ($array[$i].text -like "*S?N*") 
        {
            if ($array[$i].text.length -gt 6)
            {
                $serialNumber = $array[$i].text
            }
            else 
            {
                $serialNumber = $array[$i+1].text
            }          
            $foundSerial = $true 
        }
    }
   
    New-Object -TypeName PSCustomObject -Property @{
        manufacturer = $manufacturer;
        modelNumber = $modelNumber;
        serialNumber = $serialNumber;
    }
}

      #extract manufacturer, serial number and model number
    foreach ($item in (Get-ChildItem -Path "C:\work\cbre\results")) 
    {
        $analysisResult = Get-Content $item.FullName | ConvertFrom-Json
        $data = ExtractData $analysisResult
        $data
    }
#    $data = ExtractData($response)

#     $msg = "Detected: MN=$($data.ModelNumber); SN=$($data.SerialNumber); CO=$($data.Manufacturer) for $rowkey"
#     Write-Output $msg
#     $msg >> $summaryFile

#     #also write to file
#     $responseRaw > "D:\work\cbre\ai\ocr\results\$($rowKey).json"


