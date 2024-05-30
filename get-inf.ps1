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
    Write-Error 'Access Denied for Location Information'
} else {
    $latitude = $latitude_and_longitude.Position.Location.Latitude
    $longitude = $latitude_and_longitude.Position.Location.Longitude

    $headers = @{
        "X-RapidAPI-Key" = "abf409b819mshc2e12d6b68f54f9p19d04ajsne5f8a164db12"
        "X-RapidAPI-Host" = "google-maps-api-free.p.rapidapi.com"
    }

    $maxRetries = 3
    $retryCount = 0
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            # Gửi yêu cầu API để lấy thông tin geocode
            $response = Invoke-WebRequest -Uri "https://google-maps-api-free.p.rapidapi.com/google-geocode?lat=$latitude&long=$longitude" -Method GET -Headers $headers
            # Chuyển đổi nội dung phản hồi thành JSON object
            $jsonResponse = $response.Content | ConvertFrom-Json

            # Lấy giá trị của trường formatted_address
            $formattedAddress = $jsonResponse.results[0].formatted_address

            $match_addr_no_diacritics = RemoveVietnameseDiacritics($formattedAddress)
            $match_addr_no_diacritics_unique = $match_addr_no_diacritics | Select-Object -Unique

            $ipWAN = $wanIP

            Write-Host "$ipWAN|$match_addr_no_diacritics_unique"
            $success = $true
        } catch {
            # Bắt lỗi và hiển thị thông tin chi tiết
            #Write-Host "An error occurred: $($_.Exception.Message)"
            if ($_.Exception.Message -eq "The remote server returned an error: (502) Bad Gateway.") {
                $retryCount++
                #Write-Host "Retrying... ($retryCount/$maxRetries)"
                Start-Sleep -Seconds 3
            } else {
                break
            }
        }
    }

    if (-not $success) {
        Write-Host "Failed to retrieve geocode information after $maxRetries attempts."
    }
}
