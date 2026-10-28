function Write-AiDependency
{
    <#
    .SYNOPSIS
        Logs a dependency call to an external service.

    .DESCRIPTION
        Writes dependency telemetry to Application Insights for calls to external systems such as
        HTTP endpoints, SQL databases, or other services. Dependency telemetry can be used by
        Application Insights to populate the Application Map.

    .PARAMETER Target
        Host name or other target identifier for the dependency.

    .PARAMETER DependencyType
        Dependency type such as HTTP, SQL, or FTP.

    .PARAMETER Name
        Operation name for the dependency call.

    .PARAMETER Data
        Optional dependency details such as a URL, stored procedure name, or command text.

    .PARAMETER Start
        Start time of the dependency call.

    .PARAMETER Duration
        Duration of the dependency call. When omitted, the duration is calculated from Start to the current UTC time.

    .PARAMETER ResultCode
        Optional status or result code returned by the dependency.

    .PARAMETER Metrics
        Optional metrics dictionary to include with the dependency telemetry.

    .PARAMETER Success
        Indicates whether the dependency call succeeded.

    .PARAMETER Connection
        Telemetry connection created by Connect-AiLogger. When omitted, the most recently created
        connection is used.

    .EXAMPLE
        $start = Get-Date
        Invoke-WebRequest -Uri $uri | Out-Null
        Write-AiDependency -Target $uri.Host -DependencyType 'HTTP' -Name 'Invoke-WebRequest' -Data $uri.AbsoluteUri -Start $start

        Logs an HTTP dependency and calculates the duration automatically.

    .EXAMPLE
        Write-AiDependency -Target 'sql-prod-01' -DependencyType 'SQL' -Name 'usp_LoadOrders' -Data 'usp_LoadOrders' -Start $start -Duration $duration -ResultCode '0' -Success $true -Connection $connection

        Logs a SQL dependency using an explicit connection and duration.
    #>
    param
    (
        [Parameter(Mandatory)]
        [string]
            #Name of endpoint (hostname or host identifier for server being called)
        $Target,
        [Parameter(Mandatory)]
        [string]
            #Name of the dependency type, such as FTP, SQL or HTTP
        $DependencyType,
        [Parameter(Mandatory)]
        [string]
            #Name of the dependency, such as FileDownload, StoredProcedureCall
        $Name,
        [Parameter()]
        [string]
            #Dependency details, such as name of SQL stored procedure, or complete URL requested via HTTP
        $Data,
        [Parameter(Mandatory)]
        [DateTime]
            #When the call started
        $Start,
        [Parameter()]
        [TimeSpan]
            #Duration of the call
            #Default: (current time in UTC) - Start
        $Duration,
        [Parameter()]
        [string]
            #Result code returned by the service
        $ResultCode=$null,
        [Parameter()]
        [System.Collections.Generic.Dictionary[String,Double]]
            #Optional metrics to be sent with the dependency data
        $Metrics=$null,
        [Parameter()]
        [bool]
            #Whether or not call was successful
        $Success = $true,
        [Parameter()]
            #Connection created by Connect-AiLogger
            #Defaults to last created connection
        $Connection = $script:LastCreatedAiLogger
    )
    begin
    {

    }
    Process
    {   
        if(-not $PSBoundParameters.ContainsKey('Duration')) {
            $Duration = ([DateTime]::UtcNow) - $Start.ToUniversalTime()
        }
        $baseData = [ordered]@{
            id = [Guid]::NewGuid().ToString('N').Substring(0, 16)
            name = $Name
            type = $DependencyType
            target = $Target
            data = $Data
            duration = $Duration.ToString('c', [System.Globalization.CultureInfo]::InvariantCulture)
            success = $Success
        }
        if(-not [string]::IsNullOrEmpty($ResultCode)) {
            $baseData['resultCode'] = $ResultCode
        }
        if($null -ne $Metrics) {
            $baseData['measurements'] = $Metrics
        }
        $envelope = New-AiEnvelope -Connection $Connection -TelemetryType RemoteDependency -BaseData $baseData -Timestamp $Start

        Write-Verbose "Writing dependency: Name = $Name, Type = $DependencyType, Start = $Start, Duration = $Duration, Success = $Success,  Target = $Target, Data = $Data"
        Add-AiTelemetry -Connection $Connection -Envelope $envelope
    }
}
