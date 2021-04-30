#Declare some variables and input parameters
$access_token = $env:MY_FLOOD_TOKEN
$api_url = "https://api.flood.io"
$data_path = 'data/MCI.csv'
$flood_project = 'azure-devops'
$flood_name = 'myAzureTest'

#Setup the API URI that contains all parameters required to start a Grid, Flood and test settings.
$uri = "$api_url/api/floods?flood[tool]=jmeter&flood[threads]=5&flood[duration]=120&flood[project]=$flood_project&flood[privacy]=public&flood[name]=$flood_name&flood[grids][][infrastructure]=demand&flood[grids][][instance_quantity]=1&flood[grids][][region]=us-east-1&flood[grids][][instance_type]=m5.xlarge&flood[grids][][stop_after]=10"

#Encode the Flood auth token with Base64 and use it as a header for our request to Flood API
$bytes = [System.Text.Encoding]::ASCII.GetBytes($access_token)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"
$headers = @{
    'Authorization' = $basicAuthValue
}

#Read the data file and transplant it as part of a UTF-8 based payload
$fileBytes = [System.IO.File]::ReadAllBytes($data_path);
$fileEnc = [System.Text.Encoding]::GetEncoding('UTF-8').GetString($fileBytes);
$boundary = [System.Guid]::NewGuid().ToString();
$LF = "`r`n";
$contentType = "multipart/form-data; boundary1=`"$boundary`""
$payload = (
    "--$boundary",
    "Content-Disposition: form-data; name=`"flood_files[]`"; filename=`"MCI.csv`"",
    "Content-Type: application/octet-stream$LF",
    $fileEnc1,
    "--$boundary--$LF"
) -join $LF
