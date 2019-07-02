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

# function ExtractLennoxData ($array)
# {
#     $foundModel = $false
#     $foundSerial = $false
#     for ($i = 0; ($i -lt $array.Count) -and !($foundModel -and $foundSerial); $i++) 
#     {
#         if ($array[$i].text -match "M[I\/]?N" -and ! $foundModel)       
#         {
#             $foundModel = $true
#             $text = (($array[$i].text -replace "M[I\/]?N","") -replace "\:","").Trim()

#             #remove original ocurrence
#             if ($text.length -gt 6)
#             {
#                 $modelNumber = $text                
#             }
#             else 
#             {
#                 if ($array[$i+1].text.length -gt 8)
#                 {
#                     $modelNumber = $array[$i+1].text
#                 }
#                 else 
#                 {
#                     $modelNumber = $array[$i-1].text
#                 }
#             }           
#             $foundModel = $true
#         }

#         if ($array[$i].text -match "S[I\/]?N" -and ! $foundSerial)
#         {
#             $foundSerial = $true
#             $text = (($array[$i].text -replace "S[I\/]?N","") -replace "\:","").Trim()

#             if ($text.length -gt 7)
#             {
#                 $serialNumber = $text
#             }
#             else 
#             {
#                 if ($array[$i+1].text.length -gt 8)
#                 {
#                     $serialNumber = $array[$i+1].text
#                 }
#                 else 
#                 {
#                     $serialNumber = $array[$i-1].text
#                 }
#             }          
#             $foundSerial = $true 
#         }
#     }
   
#     New-Object -TypeName PSCustomObject -Property @{
#         manufacturer = $manufacturer;
#         modelNumber = $modelNumber;
#         serialNumber = $serialNumber;
#     }
# }

# function ExtractTraneData ($array)
# {
#     $foundModel = $false
#     $foundSerial = $false
#     for ($i = 0; ($i -lt $array.Count) -and !($foundModel -and $foundSerial); $i++) 
#     {
#         if ($array[$i].text -match "MOD\.|MODEL NO\." -and ! $foundModel)
#         {
#             $foundModel = $true
#             $text = ($array[$i].text -replace "MOD\. NO\.|MODEL NO\.","" -replace "VOLTS","" -replace "[0-9]{3}\/[0-9]{3}","").Trim()

#             #remove original ocurrence
#             if ($text.length -gt 6)
#             {
#                 $modelNumber = $text                
#             }
#             else 
#             {
#                 if ($array[$i+1].text.length -gt 8)
#                 {
#                     $modelNumber = $array[$i+1].text
#                 }
#                 else 
#                 {
#                     $modelNumber = $array[$i-1].text
#                 }
#             }           
#             $foundModel = $true
#         }

#         if ($array[$i].text -match "SERIAL NO\." -and ! $foundSerial)
#         {
#             $foundSerial = $true
#             $text = ($array[$i].text -replace "SERIAL NO\.","" ).Trim()

#             if ($text.length -gt 7)
#             {
#                 $serialNumber = $text
#             }
#             else 
#             {
#                 if ($array[$i+1].text.length -gt 8)
#                 {
#                     $serialNumber = $array[$i+1].text
#                 }
#                 else 
#                 {
#                     $serialNumber = $array[$i-1].text
#                 }
#             }          
#             $foundSerial = $true 
#         }
#     }
   
#     New-Object -TypeName PSCustomObject -Property @{
#         manufacturer = $manufacturer;
#         modelNumber = $modelNumber;
#         serialNumber = $serialNumber;
#     }
# }
# function ExtractYorkData ($array)
# {
#     $foundModel = $false
#     $foundSerial = $false
#     for ($i = 0; ($i -lt $array.Count) -and !($foundModel -and $foundSerial); $i++) 
#     {
#         if ($array[$i].text -match "UNIT MODEL" -and ! $foundModel)
#         {
#             $foundModel = $true
#             $text = ($array[$i].text -replace "UNIT MODEL","" ).Trim()

#             #remove original ocurrence
#             if ($text.length -gt 6)
#             {
#                 $modelNumber = $text                
#             }
#             else 
#             {
#                 if ($array[$i+1].text.length -gt 8)
#                 {
#                     $modelNumber = $array[$i+1].text
#                 }
#                 else 
#                 {
#                     $modelNumber = $array[$i-1].text
#                 }
#             }           
#             $foundModel = $true
#         }

#         if ($array[$i].text -match "SERIAL NO\." -and ! $foundSerial)
#         {
#             $foundSerial = $true
#             $text = ($array[$i].text -replace "SERIAL NO\.","" ).Trim()

#             if ($text.length -gt 7)
#             {
#                 $serialNumber = $text
#             }
#             else 
#             {
#                 if ($array[$i+1].text.length -gt 8)
#                 {
#                     $serialNumber = $array[$i+1].text
#                 }
#                 else 
#                 {
#                     $serialNumber = $array[$i-1].text
#                 }
#             }          
#             $foundSerial = $true 
#         }
#     }
   
#     New-Object -TypeName PSCustomObject -Property @{
#         manufacturer = $manufacturer;
#         modelNumber = $modelNumber;
#         serialNumber = $serialNumber;
#     }
# }

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
                    $modelNumber = ExtractAnyManufacturerData $array "MOD\.|MODEL NO\." @("VOLTS","[0-9]{3}\/[0-9]{3}")  
                    $serialNumber = ExtractAnyManufacturerData $array "SERIAL NO\." @() 
                    break
                 }
        "YORK"   {
                    $modelNumber = ExtractAnyManufacturerData $array "UNIT MODEL" @()  
                    $serialNumber = ExtractAnyManufacturerData $array "SERIAL NO\." @() 
                    break
                 }

        Default  {$data = ExtractOtherData $array; break}
    }

    New-Object -TypeName PSCustomObject -Property @{
        manufacturer = $manufacturer;
        modelNumber = $modelNumber;
        serialNumber = $serialNumber;
    }
}

      #extract manufacturer, serial number and model number
    foreach ($file in (Get-ChildItem -Path "D:\work\cbre\ai\test-recog-results\york")) 
    {
        $analysisResult = Get-Content $file.FullName | ConvertFrom-Json
        $data = ExtractData $analysisResult
        Write-output "File : $($file.Name) - Data extracted: Manufacturer = $($data.manufacturer); Model = $($data.modelNumber); Serial = $($data.serialNumber)" 
    }
#    $data = ExtractData($response)

#     $msg = "Detected: MN=$($data.ModelNumber); SN=$($data.SerialNumber); CO=$($data.Manufacturer) for $rowkey"
#     Write-Output $msg
#     $msg >> $summaryFile

#     #also write to file
#     $responseRaw > "D:\work\cbre\ai\ocr\results\$($rowKey).json"


