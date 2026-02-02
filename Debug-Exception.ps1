# Deep dive into exception structure
Write-Host "Debugging exception structure..." -ForegroundColor Cyan
Write-Host ""

try {
    $url = "https://www.powershellgallery.com/packages/Entra-PIM"
    $null = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 5 -ErrorAction Stop
} catch {
    Write-Host "Exception caught!" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Exception Properties:" -ForegroundColor Yellow
    $_.Exception | Get-Member -MemberType Property | ForEach-Object {
        $propName = $_.Name
        $propValue = $_.Exception.$propName
        Write-Host "  $propName : $propValue"
    }

    Write-Host ""
    Write-Host "Response Object:" -ForegroundColor Yellow
    if ($_.Exception.Response) {
        Write-Host "  Type: $($_.Exception.Response.GetType().FullName)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Response Properties:" -ForegroundColor Gray
        $_.Exception.Response | Get-Member -MemberType Property | ForEach-Object {
            $propName = $_.Name
            try {
                $propValue = $_.Exception.Response.$propName
                Write-Host "    $propName : $propValue"
            } catch {
                Write-Host "    $propName : <error accessing>"
            }
        }

        Write-Host ""
        Write-Host "  Trying to get Location header:" -ForegroundColor Yellow
        try {
            $headers = $_.Exception.Response.Headers
            Write-Host "    Headers Type: $($headers.GetType().FullName)" -ForegroundColor Gray
            Write-Host "    Headers Count: $($headers.Count)" -ForegroundColor Gray

            # Try different ways to access
            Write-Host ""
            Write-Host "    Method 1 - Direct access:" -ForegroundColor Gray
            $loc1 = $headers['Location']
            Write-Host "      Result: $loc1"

            Write-Host ""
            Write-Host "    Method 2 - GetValues:" -ForegroundColor Gray
            $loc2 = $headers.GetValues('Location')
            Write-Host "      Result: $loc2"

            Write-Host ""
            Write-Host "    All headers:" -ForegroundColor Gray
            foreach ($key in $headers.Keys) {
                Write-Host "      $key = $($headers[$key])"
            }
        } catch {
            Write-Host "    Error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  No Response object in exception" -ForegroundColor Red
    }
}
