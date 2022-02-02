using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

using Newtonsoft.Json;
using Confluent.Kafka;

namespace Confluent.Functions
{
    static class AzureSinkTrigger
    {

        static IProducer<string, string> producer;
        static string outputTopic = "azure-output";
        static string rawConfigJson;


        static AzureSinkTrigger()
        {
            if (producer is null)
            {
                rawConfigJson = Environment.GetEnvironmentVariable("ccloud-producer-configs");
                Dictionary<string, string> producerConfigs =  JsonConvert.DeserializeObject<Dictionary<string, string>>(rawConfigJson);
                producer = new ProducerBuilder<string, string>(producerConfigs).Build();
            }
        }

        [FunctionName("AzureSinkConnectorTrigger")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function for Azure Sink Connector processed a request.");
            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            dynamic records = JsonConvert.DeserializeObject(requestBody);
            int NumberRecords = 0;

            log.LogInformation($"full request body {requestBody}");

            foreach (dynamic record in records)
            {
                string recordString = "Parsed record  - key [" + record.key + "] value[" + record.value + "]";
                dynamic value = record.value;
                producer.Produce(outputTopic, new Message<string, string> { Key = record.key, Value = $"processed order for {record.key}" },
                (deliveryReport) =>
                {
                    if (deliveryReport.Error.Code != ErrorCode.NoError)
                    {
                        log.LogError($"Problem producing record: {deliveryReport.Error.Reason}");
                    }
                    else
                    {
                        log.LogInformation($"Produced record to {deliveryReport.Topic} at offset {deliveryReport.Offset} with timestamp {deliveryReport.Timestamp.UtcDateTime}");

                    }
                });
                log.LogInformation(recordString);
                NumberRecords++;

            }
            producer.Flush();
            string responseMessage = $"This Azure Sink Connector triggered function executed successfully and it processed {NumberRecords} records";
            return new OkObjectResult(responseMessage);
        }
    }
}
