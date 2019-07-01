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
        switch ($array[$i].text) 
        {
            {$_ -match "M[I\/]?N"}   {$foundModel = $true; $text = ($_ -replace "M[I\/]?N","") -replace "\:",""; break }
            {$_ -match "UNIT MODEL"} {$foundModel = $true; $text = ($_ -replace "UNIT MODEL","") -replace "\:",""; $regExtToUse = "[A-Z0-9]{8}-[A-Z]{3}";break }
            Default {continue}
        }
        if ($foundModel) 
        {
                #remove original ocurrence
            if ($text.length -gt 6)
            {
                $modelNumber = $text                
            }
            else 
            {
                if ($array[$i+1].text.length -gt 8)
                {
                    $modelNumber = $array[$i+1].text
                }
                else 
                {
                    $modelNumber = $array[$i-1].text
                }
            }           
            $foundModel = $true
        }

        switch ($array[$i].text) 
        {
            {$_ -match "S[I\/]?N"}   {$foundModel = $true; $text = ($_ -replace "S[I\/]?N","") -replace "\:","";  break }
            {$_ -match "SERIAL NO"} {$foundModel = $true; $text = ($_ -replace "SERIAL NO","") -replace "\.",""; $regExtToUse = "[A-Z0-9]{10}"; break }
            Default {continue}
        }

        if ($foundSerial) 
        {
            if ($text -gt 7)
            {
                $serialNumber = $text
            }
            else 
            {
                if ($array[$i+1].text.length -gt 8)
                {
                    $serialNumber = $array[$i+1].text
                }
                else 
                {
                    $serialNumber = $array[$i-1].text
                }
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
    foreach ($item in (Get-ChildItem -Path "D:\work\cbre\ai\testec-results")) 
    {
        $analysisResult = Get-Content $item.FullName | ConvertFrom-Json
        $data = ExtractData $analysisResult
        Write-output "File : $($item.Name) - Data extracted: Manufacturer = $($data.manufacturer); Model = $($data.modelNumber); Serial = $($data.serialNumber)" 
    }
#    $data = ExtractData($response)

#     $msg = "Detected: MN=$($data.ModelNumber); SN=$($data.SerialNumber); CO=$($data.Manufacturer) for $rowkey"
#     Write-Output $msg
#     $msg >> $summaryFile

#     #also write to file
#     $responseRaw > "D:\work\cbre\ai\ocr\results\$($rowKey).json"


