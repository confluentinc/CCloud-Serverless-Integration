using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Azure.Functions.Extensions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.IO;

[assembly: FunctionsStartup(typeof(Confluent.Functions.Startup))]
namespace Confluent.Functions
{
    public class Startup : FunctionsStartup
    {
        public override void ConfigureAppConfiguration(IFunctionsConfigurationBuilder 
builder)
        {
            FunctionsHostBuilderContext context = builder.GetContext();

            builder.ConfigurationBuilder
                .AddJsonFile(Path.Combine(context.ApplicationRootPath, "appsettings.json"), optional: true, reloadOnChange: true).AddEnvironmentVariables();
        }

       public override void Configure(IFunctionsHostBuilder builder) 
       {
            builder.Services.AddOptions<ConfluentCloudOptions>()
            .Configure<IConfiguration>((settings, configuration) =>
            {
                configuration.GetSection("ConfluentCloudOptions").Bind(settings);
            });
       }
    }
}