$wanIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -UseBasicParsing).ip

function RemoveVietnameseDiacritics($text) {
    $normalizedString = $text.Normalize('FormD')
    $sb = New-Object System.Text.StringBuilder

    for ($i = 0; $i -lt $normalizedString.Length; $i++) {
        $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($normalizedString[$i])

        if ($category -ne 'NonSpacingMark') {
            $sb.Append($normalizedString[$i])
        }
    }

    return $sb.ToString()
}

Add-Type -AssemblyName System.Device

$latitude_and_longitude = New-Object System.Device.Location.GeoCoordinateWatcher
$latitude_and_longitude.Start()

while (($latitude_and_longitude.Status -ne 'Ready') -and ($latitude_and_longitude.Permission -ne 'Denied')) {
    Start-Sleep -Milliseconds 100
}

if ($latitude_and_longitude.Permission -eq 'Denied') {
    #Write-Error 'no perminssion'
} else {
    $latitude = $latitude_and_longitude.Position.Location.Latitude
    $longitude = $latitude_and_longitude.Position.Location.Longitude

    $headers = @{
        "X-RapidAPI-Key" = "abf409b819mshc2e12d6b68f54f9p19d04ajsne5f8a164db12"
        "X-RapidAPI-Host" = "google-maps-api-free.p.rapidapi.com"
    }

    $success = $false
    $location = ""
    $errors = @()

    for ($retryCount = 1; $retryCount -le 3; $retryCount++) {
        try {
            $response = Invoke-RestMethod -Uri "https://google-maps-api-free.p.rapidapi.com/google-geocode?lat=$latitude&long=$longitude" -Method GET -Headers $headers
            $formattedAddress = $response.results[4].formatted_address

            $match_addr_no_diacritics = RemoveVietnameseDiacritics($formattedAddress)
            $match_addr_no_diacritics_unique = $match_addr_no_diacritics | Select-Object -Unique

            $location = "$wanIP|$match_addr_no_diacritics_unique"
            $success = $true
            break
        } catch {
            $errors += $_.Exception.Message
            if ($_.Exception.Message -eq "The remote server returned an error: (502) Bad Gateway.") {
                Start-Sleep -Seconds 1
            } else {
                break
            }
        }
    }

    if ($success) {
        Write-Host $location
    } else {
        #Write-Host "khong the lay sau 3 lan:"
        #$errors | ForEach-Object { Write-Host $_ }
    }
}
