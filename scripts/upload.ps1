$fileBytes = [System.IO.File]::ReadAllBytes($$csv_path = 'scripts/jmeter/MCI.csv');
$fileEnc = [System.Text.Encoding]::GetEncoding('UTF-8').GetString($fileBytes);
$boundary = [System.Guid]::NewGuid().ToString();
$LF = "`r`n";
$contentType = "multipart/form-data; boundary=`"$boundary`"
"$payload = (
 "--$boundary", 
 "Content-Disposition: form-data; name=`"flood_files[]`"; filename=`"MCI.csv`"", 
 "Content-Type: application/octet-stream$LF", $fileEnc, "--$boundary--$LF"
 ) -join $LF
