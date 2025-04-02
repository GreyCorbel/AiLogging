function Write-AiDependency
{
    <#
    .SYNOPSIS
        Logs a call to external service
        Logged call is used by Application Insights to populate Application Map blade
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
            #Default: current time - Start
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
        if($null -eq $Duration) {$Duration = (Get-Date) - $Start}
        $dependencyData = new-object Microsoft.ApplicationInsights.DataContracts.DependencyTelemetry
        foreach($key in $Connection.telemetryMetadata.Keys) {$dependencyData.Properties[$Key] = $Connection.telemetryMetadata[$key]}
        $dependencyData.Type=$DependencyType
        $dependencyData.Name=$Name
        $dependencyData.Timestamp=$Start
        $dependencyData.Duration = $Duration
        $dependencyData.Success = $Success
        $dependencyData.Target = $Target
        $dependencyData.Data = $Data
        if($null -ne $ResultCode) {
            $dependencyData.ResultCode = $ResultCode
        }
        if($null -ne $Metrics) {
            foreach($key in $Metrics.Keys) {
                $dependencyData.Metrics[$Key] = $Metrics[$key]
            }
        }
        Write-Verbose "Writing dependency: Name = $Name, Type = $DependencyType, Start = $start, Duration = $Duration, Success = $Success,  Target = $Target, Data = $Data"
        $Connection.TrackDependency($dependencyData)
    }
}
