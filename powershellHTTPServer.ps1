function Write-String{
	$b=[System.Text.Encoding]::UTF8.GetBytes($args[1])
	$args[0].Write($b,0,$b.Length)
}

# HTML Encoder
function Html-Encode{
	return [System.Web.HttpUtility]::HtmlEncode($args[0])
}

# URL Encoder
function Url-Encode{
	return [uri]::EscapeDataString($args[0])
}

Add-Type -AssemblyName System.Web

$httpListener = New-Object System.Net.HttpListener
$httpListener.Prefixes.Add("http://localhost:8080/")
$httpListener.Start()

New-PSDrive -Name MyPowerShellSite -PSProvider FileSystem -Root $PWD.Path

$context = $httpListener.GetContext()

$URL = $Context.Request.Url.LocalPath
echo "Request: $URL"

if(Test-Path "MyPowerShellSite:$URL" -PathType Leaf){
    echo "Requesting a File"
	# Is file, serve it
	$Content = Get-Content -Encoding Byte -Path "MyPowerShellSite:$URL" -ReadCount 0

	# This can throw an error on older versions of PowerShell but the web server will still work
	$Context.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($URL)
	$Context.Response.ContentLength = $Content.Length

	# Write content as-is
	$Context.Response.OutputStream.Write($Content, 0, $Content.Length)
}
elseif (Test-Path "MyPowerShellSite:$URL" -PathType Container){
	if($Context.Request.Url.Query -eq "?$nonce"){
		echo "Requesting Server Shutdown"
		# Stop listener
		$Context.Response.ContentType = "text/html"
		Write-String $Context.Response.OutputStream "<h1>The server has been shut down</h1>"
		$Context.Response.Close()
		# Give the component time to deliver the answer
		sleep 1
		$listener.Stop()
		return
	}
    else{
		echo "Requesting Directory listing"
		# Is directory, show contents
		$Context.Response.ContentType = "text/html; charset=utf-8"
		$Context.Response.ContentEncoding = [System.Text.Encoding]::UTF8

		# Make it look somewhat nice
		Write-String $Context.Response.OutputStream "
<style>
*{font-family:monospace;font-size:14pt}
div a{text-decoration:none;display:inline-block;width:49%;padding:5px}
div a:hover{background-color:#FF0}
#sd{color:#F00;text-decoration:none;}</style>"
		Write-String $Context.Response.OutputStream "<h1>Directory Listing</h1><div>"

		# UP
		Write-String $Context.Response.OutputStream "<a href=""../"">&lt;UP&gt;</a><br />"

		# Directories above files
		Get-ChildItem "MyPowerShellSite:$URL" | Where-Object { $_.PSIsContainer } | Foreach-Object {
			$fn=[System.IO.Path]::GetFileName($_.FullName)
			$href=Url-Encode $fn
			$fn=Html-Encode $fn
			Write-String $Context.Response.OutputStream "<a href=""$href/"">$fn/</a>"
		}
		Get-ChildItem "MyPowerShellSite:$URL" | Where-Object { -not $_.PSIsContainer } | Foreach-Object {
			$fn=[System.IO.Path]::GetFileName($_.FullName)
			$href=Url-Encode $fn
			$fn=Html-Encode $fn
			Write-String $Context.Response.OutputStream "<a href=""$href"">$fn</a>"
		}
        # Shutdown
        Write-String $Context.Response.OutputStream "</div><hr/>[<a id=""sd"" href=""/?$nonce"">SHUTDOWN</a>]<hr/>"
	}
}
else{
	echo "HTTP 404"
	# Not found
	$Context.Response.StatusCode = 404;
	$Context.Response.ContentType = "text/plain";
	Write-String $Context.Response.OutputStream "$URL not found"
}
echo "Done"
# Complete request
$Context.Response.Close()
$httpListener.Close()
Remove-PSDrive -Name MyPowerShellSite
