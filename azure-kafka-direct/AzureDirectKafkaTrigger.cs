using System;
using System.Collections.Generic;
using Confluent.Kafka;
using Confluent.Kafka.SyncOverAsync;
using Confluent.SchemaRegistry;
using Io.Confluent.Developer.Proto;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Kafka;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;


namespace AzureKafkaDirect;

public static class AzureDirectKafkaTrigger
{
    private const string InputTopic = "user_trades";
    private const string OutputTopic = "trade-settlements";
    static IProducer<string, TradeSettlement> _producer;
    private static string rawConfigJson;
    private static string rawSchemaRegistryConfigs;

    static AzureDirectKafkaTrigger()
    {
        rawConfigJson = Environment.GetEnvironmentVariable("ccloud-producer-configs");
        rawSchemaRegistryConfigs = Environment.GetEnvironmentVariable("schema-registry-configs");
        var producerConfigs = JsonConvert.DeserializeObject<Dictionary<string, string>>(rawConfigJson);
        var schemaConfigs = JsonConvert.DeserializeObject<Dictionary<string, string>>(rawSchemaRegistryConfigs);
        var schemaRegistryConfig = new SchemaRegistryConfig();
        foreach (var configEntry in schemaConfigs)
        {
            schemaRegistryConfig.Set(configEntry.Key, configEntry.Value);
        }

        var schemaRegistry = new CachedSchemaRegistryClient(schemaRegistryConfig);
        _producer = new ProducerBuilder<string, TradeSettlement>(producerConfigs)
            .SetValueSerializer(new Confluent.SchemaRegistry.Serdes.ProtobufSerializer<TradeSettlement>(schemaRegistry)
                .AsSyncOverAsync())
            .Build();
    }

    [FunctionName("AzureKafkaDirectFunction")]
    public static void KafkaTopicTrigger(
        [KafkaTrigger("%bootstrap-servers%",
            InputTopic,
            ConsumerGroup = "azure-consumer",
            Protocol = BrokerProtocol.SaslSsl,
            AuthenticationMode = BrokerAuthenticationMode.Plain,
            Username = "%sasl-username%",
            Password = "%sasl-password%")]
        KafkaEventData<string, string>[] kafkaEvents,
        [Kafka("%bootstrap-servers%",
            OutputTopic,
            Protocol = BrokerProtocol.SaslSsl,
            AuthenticationMode = BrokerAuthenticationMode.Plain,
            Username = "%sasl-username%",
            Password = "%sasl-password%")]
        IAsyncCollector<KafkaEventData<string, TradeSettlement>> outputRecords,
        ILogger logger)
    {
        var numberRecords = 0;
        foreach (var kafkaEvent in kafkaEvents)
        {
            var key = kafkaEvent.Key;
            var random = new Random();
            var now = DateTime.UtcNow;
            var secInspection = random.Next(100);
            Dictionary<string, object> trade = JsonConvert.DeserializeObject<Dictionary<string, object>>(kafkaEvent.Value);  

            var shares = (Int64) trade["QUANTITY"];
            var price = (Int64) trade["PRICE"];    
            var amount = (double) shares * price;  
            var user = "theUser";         
            var symbol = (string) trade["SYMBOL"]; 
            var timestamp = now.Ticks;
            string disposition;
            string reason;

            if (user.Equals("NO USER"))
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

            var tradeSettlement = new TradeSettlement
            {
                User = user,
                Symbol = symbol,
                Disposition = disposition,
                Reason = reason,
                Timestamp = timestamp
            };

            logger.LogInformation($"Trade Settlement result {tradeSettlement}");
            var tradeSettlementEvent = new KafkaEventData<string, TradeSettlement>()
            {
                Key = user,
                Value = tradeSettlement
            }; 
            
          outputRecords.AddAsync(tradeSettlementEvent);
           numberRecords++;
        }
        logger.LogInformation($"Processed {numberRecords} records");
    }
}