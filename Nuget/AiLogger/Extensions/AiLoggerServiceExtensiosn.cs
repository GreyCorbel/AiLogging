using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Text;

namespace GreyCorbel.Logging.Extensions
{
    /// <summary>
    /// Implements DI support
    /// </summary>
    public static class AiLoggerServiceExtensiosn
    {
        /// <include file='./Docs/AiLoggerServiceCollectionExtensions.xml' path='SCE/AILogger1/*'/>
        public static IServiceCollection AddAiLogger(this IServiceCollection serviceCollection, IConfiguration configuration)
        {
            serviceCollection.AddSingleton(p => new AiLogger(configuration));
            return serviceCollection;
        }
        /// <include file='./Docs/AiLoggerServiceCollectionExtensions.xml' path='SCE/AILogger2/*'/>
        public static IServiceCollection AddAiLogger(this IServiceCollection serviceCollection, string InstrumentationKey, string Application, string Module, string Component)
        {
            serviceCollection.AddSingleton(p => new AiLogger(InstrumentationKey, Application, Component, Module));
            return serviceCollection;
        }
        /// <include file='./Docs/AiLoggerServiceCollectionExtensions.xml' path='SCE/AILogger3/*'/>
        public static IServiceCollection AddAiLogger(this IServiceCollection serviceCollection, string InstrumentationKey, string Application, string Component)
        {
            serviceCollection.AddSingleton(p => new AiLogger(InstrumentationKey, Application, Component));
            return serviceCollection;
        }
        /// <include file='./Docs/AiLoggerServiceCollectionExtensions.xml' path='SCE/AILogger4/*'/>
        public static IServiceCollection AddAiLogger(this IServiceCollection serviceCollection, string InstrumentationKey, string Application, string Component, string Role, string Instance)
        {
            serviceCollection.AddSingleton(p => new AiLogger(InstrumentationKey, Application, Component, Role, Instance));
            return serviceCollection;
        }

        /// <include file='./Docs/AiLoggerServiceCollectionExtensions.xml' path='SCE/AiLoggerConfig1/*'/>
        public static IServiceCollection AddAiLoggerConfiguration(this IServiceCollection serviceCollection, TelemetryConfiguration telemetryConfiguration)
        {
            serviceCollection.AddSingleton(p => telemetryConfiguration);
            return serviceCollection;
        }
    }
}
