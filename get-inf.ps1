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

    $api_key = "AAPKea62091723b24fb09b6a7385d28395f2EiPVPUvO8LiMfF714GZ9JG0b_dVH_xnGgpJSN-uBHAYXj2YreOFUPkl2wemDhu7X"
    $url = "https://geocode-api.arcgis.com/arcgis/rest/services/World/GeocodeServer/reverseGeocode?location=$longitude,$latitude&featureTypes=StreetInt&f=json&token=$api_key"
    $response = Invoke-RestMethod -Uri $url

    $match_addr = $response.address.Match_addr
    $match_addr_no_diacritics = RemoveVietnameseDiacritics($match_addr)
    $match_addr_no_diacritics_unique = $match_addr_no_diacritics | Select-Object -Unique

    $ipWAN = $wanIP

    Write-Host "$ipWAN|$match_addr_no_diacritics_unique"
}