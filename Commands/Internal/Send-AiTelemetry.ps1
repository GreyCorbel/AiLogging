function Send-AiTelemetry
{
    param
    (
        [Parameter(Mandatory)]
        $Connection
    )

    process
    {
        $Connection.LastFlush = [DateTime]::UtcNow
        if($Connection.Buffer.Count -eq 0) { return }

        $pending = $Connection.Buffer.ToArray()
        $Connection.Buffer.Clear()

        if([string]::IsNullOrEmpty($Connection.InstrumentationKey))
        {
            Write-Verbose "AiLogger: No instrumentation key configured, discarding $($pending.Count) telemetry item(s)"
            return
        }

        $retriableCodes = @(408, 429, 439, 500, 502, 503, 504)
        $maxAttempts = 3
        for($attempt = 1; $attempt -le $maxAttempts; $attempt++)
        {
            $statusCode = 0
            $responseBody = $null
            try
            {
                $json = ConvertTo-Json -InputObject @($pending) -Depth 10 -Compress
                $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $Connection.TrackUri)
                $request.Content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
                $authHeader = Get-AiAuthorizationHeader -Connection $Connection
                if(-not [string]::IsNullOrEmpty($authHeader))
                {
                    [void]$request.Headers.TryAddWithoutValidation('Authorization', $authHeader)
                }
                Write-Verbose "AiLogger: Sending $($pending.Count) telemetry item(s) to $($Connection.TrackUri) (attempt $attempt)"
                $response = $script:AiHttpClient.SendAsync($request).GetAwaiter().GetResult()
                $statusCode = [int]$response.StatusCode
                $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                $response.Dispose()
                $request.Dispose()
            }
            catch
            {
                Write-Verbose "AiLogger: Sending telemetry failed: $($_.Exception.Message)"
            }

            switch($statusCode)
            {
                200 {
                    return
                }
                206 {
                    $result = $responseBody | ConvertFrom-Json
                    $retry = new-object System.Collections.Generic.List[object]
                    foreach($err in $result.errors)
                    {
                        if($err.statusCode -in $retriableCodes) {
                            $retry.Add($pending[$err.index])
                        }
                        else {
                            Write-Warning "AiLogger: Telemetry item rejected: $($err.statusCode) $($err.message)"
                        }
                    }
                    if($retry.Count -eq 0) { return }
                    $pending = $retry.ToArray()
                    break
                }
                {$_ -in 401, 403} {
                    Write-Warning "AiLogger: Telemetry rejected with status $statusCode (authentication/authorization failure): $responseBody"
                    return
                }
                {$_ -eq 0 -or $_ -in $retriableCodes} {
                    Write-Verbose "AiLogger: Transient failure (status $statusCode)"
                    break
                }
                default {
                    Write-Warning "AiLogger: Telemetry rejected with status $statusCode`: $responseBody"
                    return
                }
            }
            if($attempt -lt $maxAttempts) { Start-Sleep -Seconds ([Math]::Pow(2, $attempt - 1)) }
        }
        Write-Warning "AiLogger: Failed to send $($pending.Count) telemetry item(s) after $maxAttempts attempts"
    }
}
