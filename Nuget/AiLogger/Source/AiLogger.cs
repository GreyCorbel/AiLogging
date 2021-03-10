using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector;
using Microsoft.ApplicationInsights.Metrics;
using Microsoft.Extensions.Configuration;

namespace GreyCorbel.Logging
{
    /// <summary>
    /// Helper class for AppInsights logging while following defined logging standards, namely:
    /// <list type="bullet">
    /// <item>
    /// <description>Application and Component (and optionally a Module) are recorded in Custom dimensions of all events</description>
    /// </item>
    /// <item>
    /// <description>All metrics have unified namespace in format [Application].[Component][.[Module]]</description>
    /// </item>
    /// <item>
    /// <description>Support for W3C traceParentHeader</description>
    /// </item>
    /// <item>
    /// <description>All metrics strictly logged via instance of Metric class with metric namespace constructed as specified above.</description>
    /// </item>
    /// </list>
    /// </summary>
    public class AiLogger : IAiLogger, IDisposable
    {
        //private readonly IConfiguration _cfg;

        private TelemetryClient _client;
        private TelemetryConfiguration _clientConfig = null;
        private bool _disposed=false;

        private System.Collections.Generic.Dictionary<string, string> _metadata = new Dictionary<string, string>();
        private List<string> _protectedMetadata = new List<string>();
        private string _metricNamespace;

        //W3C support
        int _traceParentHeaderVersion;
        int _traceParentHeaderFlags;

        private void AddMetadataInternal(string name, string value, bool protectedMetadata = true)
        {
            if(string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("Metadata name cannot be null, empty string or whitespace");

            if (!string.IsNullOrWhiteSpace(value))
            {
                _metadata[name] = value;
                if (protectedMetadata)
                    _protectedMetadata.Add(name);
            }
            else
                throw new ArgumentNullException(name, "Metadata value cannot be null, empty string or whitespace");
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Ctor1/*'/>
        public AiLogger(IConfiguration Configuration): this(Configuration["InstrumentationKey"], Configuration["Application"], Configuration["Component"])
        {
            if (null != Configuration["Module"])
            {
                //module is optional; we should not fail if not present
                AddMetadataInternal("Module", Configuration["Module"]);
                _metricNamespace = $"{Configuration["Application"]}.{Configuration["Component"]}.{Configuration["Module"]}";
            }
            if (!string.IsNullOrWhiteSpace(Configuration["Role"]))
                _client.Context.Cloud.RoleName = Configuration["Role"];
            else
                _client.Context.Cloud.RoleName = _metricNamespace;
            if (!string.IsNullOrWhiteSpace(Configuration["Instance"]))
                _client.Context.Cloud.RoleName = Configuration["Instance"];

         }
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Ctor2/*'/>
        public AiLogger(string InstrumentationKey, string Application, string Component, string Module) : this(InstrumentationKey, Application, Component)
        {
            AddMetadataInternal("Module", Module);

            _metricNamespace = $"{Application}.{Component}.{Module}";
        }
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Ctor3/*'/>
        public AiLogger(string InstrumentationKey, string Application, string Component)
        {
            #region ArgsValidation
            _ = InstrumentationKey ?? throw new ArgumentNullException(nameof(InstrumentationKey));
            #endregion

            _clientConfig = new TelemetryConfiguration(InstrumentationKey);
            _client = new TelemetryClient(_clientConfig);

            AddMetadataInternal("Application", Application);
            AddMetadataInternal("Component", Component);

            _metricNamespace = $"{Application}.{Component}";
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Ctor4/*'/>
        public AiLogger(string InstrumentationKey, string Application, string Component, string Role, string Instance) : this(InstrumentationKey, Application, Component)
        {
            #region ArgsValidation
            _ = Role ?? throw new ArgumentNullException(nameof(Role));
            _ = Instance ?? throw new ArgumentNullException(nameof(Instance));
            #endregion
            _client.Context.Cloud.RoleName = Role;
            _client.Context.Cloud.RoleInstance = Instance;
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Ctor8/*'/>
        public AiLogger(TelemetryConfiguration TelemetryConfig, IConfiguration Configuration): this(TelemetryConfig, Configuration["Application"], Configuration["Component"])
        {
            if (null != Configuration["Module"])
            {
                //module is optional; we should not fail if not present
                AddMetadataInternal("Module", Configuration["Module"]);
                _metricNamespace = $"{Configuration["Application"]}.{Configuration["Component"]}.{Configuration["Module"]}";
            }
            if (!string.IsNullOrWhiteSpace(Configuration["Role"]))
                _client.Context.Cloud.RoleName = Configuration["Role"];
            else
                _client.Context.Cloud.RoleName = _metricNamespace;
            if (!string.IsNullOrWhiteSpace(Configuration["Instance"]))
                _client.Context.Cloud.RoleName = Configuration["Instance"];
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Ctor5/*'/>
        public AiLogger(TelemetryConfiguration Config, string Application, string Component)
        {
            //we do not keep telemetryClientConfiguration instance in this case
            _client = new TelemetryClient(Config);
            AddMetadataInternal("Application", Application);
            AddMetadataInternal("Component", Component);
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Ctor6/*'/>
        public AiLogger(TelemetryConfiguration Config, string Application, string Component, string Module):this(Config, Application, Component)
        {
            AddMetadataInternal("Module", Module);
            _metricNamespace = $"{Application}.{Component}.{Module}";
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Ctor7/*'/>
        public AiLogger(TelemetryConfiguration Config, string Application, string Component, string Role, string Instance) : this(Config, Application, Component)
        {
            #region ArgsValidation
            _ = Role ?? throw new ArgumentNullException(nameof(Role));
            _ = Instance ?? throw new ArgumentNullException(nameof(Instance));
            #endregion
            _client.Context.Cloud.RoleName = Role;
            _client.Context.Cloud.RoleInstance = Instance;
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/AddMetadata/*'/>
        public void AddMetadata(string Name, string Value)
        {
            lock (this)
            {
                if (_protectedMetadata.Contains(Name, StringComparer.CurrentCultureIgnoreCase))
                {
                    throw new ArgumentException(Name, "Metadata is protected and cannot be rewritten");
                }
                _metadata[Name] = Value;
            }
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/RemoveMetadata/*'/>
        public void RemoveMetadata(string Name)
        {
            lock (this)
            {
                if (_protectedMetadata.Contains(Name, StringComparer.CurrentCultureIgnoreCase))
                {
                    throw new ArgumentException(Name, "Metadata is protected and cannot be removed");
                }
                _metadata.Remove(Name);
            }
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/ResetMetadata/*'/>
        public void ResetMetadata()
        {
            lock (this)
            {
                var keys = new List<string>(_metadata.Keys);
                foreach (var key in keys)
                {
                    if (!_protectedMetadata.Contains(key))
                        _metadata.Remove(key);
                }
            }
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteTrace/*'/>
        public void WriteTrace(string Message, SeverityLevel Severity = SeverityLevel.Verbose, Dictionary<string, string> Metadata = null)
        {
            if (null != Metadata)
            {
                Dictionary<string, string> data = new Dictionary<string, string>(Metadata, StringComparer.OrdinalIgnoreCase);
                foreach (var key in _metadata.Keys)
                    data[key] = _metadata[key];
                _client.TrackTrace(Message, Severity, data);
            }
            else
                _client.TrackTrace(Message, Severity, _metadata);
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteRequest/*'/>
        public void WriteRequest(string Name, DateTime Start, TimeSpan Duration, string StatusCode, bool IsSuccess, string Url = null, string RequestId = null)
        {
            var data = new RequestTelemetry(Name, Start, Duration, StatusCode, IsSuccess);
            if (!string.IsNullOrEmpty(Url))
                data.Url = new Uri(Url);
            if (!string.IsNullOrEmpty(RequestId))
                data.Id = RequestId;

            _client.TrackRequest(data);
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/SetOperationContext/*'/>
        public void SetOperationContext(string traceId, string Name, string parentId = null)
        {
            _client.Context.Operation.Id = traceId;
            _client.Context.Operation.Name = Name;
            _client.Context.Operation.ParentId = parentId;
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/SetOperationContext2/*'/>
        public void SetOperationContext(string traceParentHeader, string Name)
        {
            string[] parts = traceParentHeader.Split('-');
            if (parts.Length != 4)
                throw new ArgumentException(nameof(traceParentHeader), "Argument has invalid number of parts");

            if (!int.TryParse(parts[0], System.Globalization.NumberStyles.HexNumber, System.Globalization.CultureInfo.InvariantCulture, out _traceParentHeaderVersion))
                throw new ArgumentException(nameof(traceParentHeader), "Argument has invalid version part");
            if (!int.TryParse(parts[3], System.Globalization.NumberStyles.HexNumber, System.Globalization.CultureInfo.InvariantCulture, out _traceParentHeaderFlags))
                throw new ArgumentException(nameof(traceParentHeader), "Argument has invalid flags part");

            _client.Context.Operation.Id = parts[1]; ;
            _client.Context.Operation.ParentId = parts[2];
            _client.Context.Operation.Name = Name;
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/SetOperationState/*'/>
        public void SetOperationState(string traceStateHeader)
        {
            _metadata["TraceState"] = traceStateHeader;
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/ClearOperationContext/*'/>
        public void ClearOperationContext()
        {
            _client.Context.Operation.Id = null;
            _client.Context.Operation.Name = null;
            _client.Context.Operation.ParentId = null;
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/ClearOperationState/*'/>
        public void ClearOperationState()
        {
            lock (this)
            {
                if (_metadata.Keys.Contains("TraceState"))
                    _metadata.Remove("TraceState");
            }
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/SetUserContext/*'/>
        public void SetUserContext(string Id, string AuthenticatedId = null, string AccountId = null, string UserAgent = null)
        {
            _client.Context.User.Id = Id;
            _client.Context.User.AccountId = AccountId;
            _client.Context.User.AuthenticatedUserId = AuthenticatedId;
            _client.Context.User.UserAgent = UserAgent;
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/ClearUserContext/*'/>
        public void ClearUserContext()
        {
            _client.Context.User.Id = null;
            _client.Context.User.AccountId = null;
            _client.Context.User.AuthenticatedUserId = null;
            _client.Context.User.UserAgent = null;
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteEvent/*'/>
        public void WriteEvent(string EventName, Dictionary<string, string> Metadata = null)
        {
            if (null != Metadata)
            {
                Dictionary<string, string> data = new Dictionary<string, string>(Metadata, StringComparer.OrdinalIgnoreCase);
                foreach (var key in _metadata.Keys)
                    data[key] = _metadata[key];
                _client.TrackEvent(EventName, data);
            }
            else
                _client.TrackEvent(EventName, _metadata);
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteException/*'/>
        public void WriteException(Exception Exception, Dictionary<string, string> Metadata = null)
        {
            if (null != Metadata)
            {
                Dictionary<string, string> data = new Dictionary<string, string>(Metadata, StringComparer.OrdinalIgnoreCase);
                foreach (var key in _metadata.Keys)
                    data[key] = _metadata[key];
                _client.TrackException(Exception, data);
            }
            else
                _client.TrackException(Exception, _metadata);
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/GetMetric/*'/>
        public Metric GetMetric(string Name)
        {
            return _client.GetMetric(new MetricIdentifier(_metricNamespace, Name));
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/GetMetric2/*'/>
        public Metric GetMetric(string Name, string NamespaceSuffix)
        {
            if (string.IsNullOrWhiteSpace(NamespaceSuffix))
                return GetMetric(Name);
            return _client.GetMetric(new MetricIdentifier($"{_metricNamespace}.{NamespaceSuffix}", Name));
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteDependency/*'/>
        public void WriteDependency(string Target, string TypeName, string Name, string Data, DateTime Start, TimeSpan Duration, string ResultCode, bool Success = true)
        {
            var dependencyData = new DependencyTelemetry()
            {
                Target = Target,
                Type = TypeName,
                Name = Name,
                Data = Data,
                Timestamp = Start,
                Duration = Duration,
                Success = Success
            };
            if (!string.IsNullOrWhiteSpace(ResultCode))
                dependencyData.ResultCode = ResultCode;

            foreach (string key in _metadata.Keys) { dependencyData.Properties[key] = _metadata[key]; }

            _client.TrackDependency(dependencyData);
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Dispose1/*'/>
        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    if(null!=_clientConfig)
                    {
                        _clientConfig.Dispose();
                        _clientConfig = null;
                    }
                }
                _disposed = true;
            }
        }

        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/Dispose2/*'/>
        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }
    }
}
