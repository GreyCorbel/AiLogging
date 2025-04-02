using System;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.ApplicationInsights.Channel;

public class CloudRoleNameTelemetryInitializer : ITelemetryInitializer
{
    private readonly string _roleName;
    private readonly string _roleInstance;
    public CloudRoleNameTelemetryInitializer(string roleName, string roleInstance)
    {
        _roleName = roleName;
        _roleInstance = roleInstance;
    }
    public void Initialize(ITelemetry telemetry)
    {
        // set custom role name here
        if(!string.IsNullOrEmpty(_roleName))
            telemetry.Context.Cloud.RoleName = _roleName;
        if(!string.IsNullOrEmpty(_roleInstance))
            telemetry.Context.Cloud.RoleInstance = _roleInstance;
    }
}