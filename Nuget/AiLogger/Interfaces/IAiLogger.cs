using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using System;
using System.Collections.Generic;

namespace GreyCorbel.Logging
{
    /// <summary>
    /// Interface for AppInsights logging helper that follows defined logging standards, namely:
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
    public interface IAiLogger
    {
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/AddMetadata/*'/>
        void AddMetadata(string Name, string Value);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/ClearOperationContext/*'/>
        void ClearOperationContext();
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/ClearOperationState/*'/>
        void ClearOperationState();
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/ClearUserContext/*'/>
        void ClearUserContext();
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/GetMetric/*'/>
        Metric GetMetric(string Name);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/GetMetric2/*'/>
        Metric GetMetric(string Name, string NamespaceSuffix);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/RemoveMetadata/*'/>
        void RemoveMetadata(string Name);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/ResetMetadata/*'/>
        void ResetMetadata();
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/SetOperationContext2/*'/>
        void SetOperationContext(string traceParentHeader, string Name);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/SetOperationContext/*'/>
        void SetOperationContext(string traceId, string Name, string parentId = null);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/SetOperationState/*'/>
        void SetOperationState(string traceStateHeader);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/SetUserContext/*'/>
        void SetUserContext(string Id, string AuthenticatedId = null, string AccountId = null, string UserAgent = null);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteDependency/*'/>
        void WriteDependency(string Target, string TypeName, string Name, string Data, DateTime Start, TimeSpan Duration, string ResultCode, bool Success = true);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteEvent/*'/>
        void WriteEvent(string EventName, Dictionary<string, string> Metadata = null);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteException/*'/>
        void WriteException(Exception Exception, Dictionary<string, string> Metadata = null);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteRequest/*'/>
        void WriteRequest(string Name, DateTime Start, TimeSpan Duration, string StatusCode, bool IsSuccess, string Url = null, string RequestId = null);
        /// <include file='..\\Docs\AiLogger.xml' path='AiLogger/WriteTrace/*'/>
        void WriteTrace(string Message, SeverityLevel Severity = SeverityLevel.Verbose, Dictionary<string, string> Metadata = null);
    }
}