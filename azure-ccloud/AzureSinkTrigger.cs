using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

using Newtonsoft.Json;
using Confluent.Kafka;
using Confluent.SchemaRegistry;
using Confluent.SchemaRegistry.Serdes;
using Io.Confluent.Developer.Proto;


namespace Confluent.Functions
{
    static class AzureSinkTrigger
    {

        static IProducer<string, TradeSettlement> producer;
        static string outputTopic = "trade-settlements";

        static AzureSinkTrigger()
        {
            if (producer is null)
            {
                var rawConfigJson = Environment.GetEnvironmentVariable("ccloud-producer-configs");
                var rawSchemaRegistryConfigs = Environment.GetEnvironmentVariable("schema-registry-configs");

                Dictionary<string, string> producerConfigs = JsonConvert.DeserializeObject<Dictionary<string, string>>(rawConfigJson);
                Dictionary<string, string> schemaConfigs = JsonConvert.DeserializeObject<Dictionary<string, string>>(rawSchemaRegistryConfigs);

                var schemaRegistryConfig = new SchemaRegistryConfig();
                foreach (KeyValuePair<string, string> configEntry in schemaConfigs)
                {
                    schemaRegistryConfig.Set(configEntry.Key, configEntry.Value);
                }

                var schemaRegistry = new CachedSchemaRegistryClient(schemaRegistryConfig);
                producer = new ProducerBuilder<string, TradeSettlement>(producerConfigs)
                .SetValueSerializer(new ProtobufSerializer<TradeSettlement>(schemaRegistry))
                .Build();
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
            Random random = new Random();
            foreach (dynamic record in records)
            {
                string recordString = "Parsed record  - key [" + record.key + "] value[" + record.value + "]";
                DateTime now = DateTime.UtcNow;
                int secInspection = random.Next(100);
                Dictionary<string, object> trade = JsonConvert.DeserializeObject<Dictionary<string, object>>(record.value);

                int shares = (int)trade["QUANTITY"];
                int price = (int)trade["PRICE"];
                var amount = (double)shares * price;
                var user = record.key;
                var symbol = (String)trade["SYMBOL"];
                long timestamp = now.Ticks;
                string disposition;
                string reason;

                if (user.equals("NO USER"))
                {
                    disposition = "Rejected";
                    reason = "No user account specified";
                }
                else if (amount > 100000)
                {
                    disposition = "Pending";
                    reason = "Large trade";
                }
                else if (secInspection < 30)
                {
                    disposition = "SEC Flagged";
                    reason = "This trade looks sus";
                }
                else
                {
                    disposition = "Completed";
                    reason = "Within same day limit";
                }

                TradeSettlement tradeSettlement = new TradeSettlement
                {
                    User = user,
                    Symbol = symbol,
                    Disposition = disposition,
                    Reason = reason,
                    Timestamp = timestamp
                };

                log.LogInformation("Trade Settlement result " + tradeSettlement);
                producer.Produce(outputTopic, new Message<string, TradeSettlement> { Key = symbol, Value = tradeSettlement },
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
