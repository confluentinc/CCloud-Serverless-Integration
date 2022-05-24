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
    const string OutputTopic = "trade-settlements";
    static IDeserializer<UserTrade> _protoDeserializer;
    private static ISerializer<TradeSettlement> _protoSerializer;
    private static string rawConfigJson;
    static string rawSchemaRegistryConfigs;
    private static SerializationContext _consumeSerializationContext;
    private static SerializationContext _produceSerializationContext;


    static AzureDirectKafkaTrigger()
    {
        rawConfigJson = Environment.GetEnvironmentVariable("ccloud-producer-configs");
        rawSchemaRegistryConfigs = Environment.GetEnvironmentVariable("schema-registry-configs");
        var schemaConfigs = JsonConvert.DeserializeObject<Dictionary<string, string>>(rawSchemaRegistryConfigs);
        var producerConfigs = JsonConvert.DeserializeObject<Dictionary<string, string>>(rawConfigJson);
        producerConfigs.Add("client.id", "Confluent-Azure-Producer");
        var schemaRegistryConfig = new SchemaRegistryConfig();
        foreach (var configEntry in schemaConfigs)
        {
            schemaRegistryConfig.Set(configEntry.Key, configEntry.Value);
        }

        var schemaRegistry = new CachedSchemaRegistryClient(schemaRegistryConfig);
        _protoDeserializer = new Confluent.SchemaRegistry.Serdes.ProtobufDeserializer<UserTrade>().AsSyncOverAsync();
        _consumeSerializationContext = new SerializationContext(MessageComponentType.Value, InputTopic);
        _protoSerializer = new Confluent.SchemaRegistry.Serdes.ProtobufSerializer<TradeSettlement>(schemaRegistry)
            .AsSyncOverAsync();
        _produceSerializationContext = new SerializationContext(MessageComponentType.Value, OutputTopic);
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
        KafkaEventData<string, byte[]>[] incomingKafkaEvents,
        [Kafka("%bootstrap-servers%",
            OutputTopic,
            Protocol = BrokerProtocol.SaslSsl,
            AuthenticationMode = BrokerAuthenticationMode.Plain,
            Username = "%sasl-username%",
            Password = "%sasl-password%")]
        IAsyncCollector<KafkaEventData<string, byte[]>> outputRecords,
        ILogger logger)
    {
        var numberRecordsProcessed = 0;
        logger.LogInformation($"The number of records in the consumed batch {incomingKafkaEvents.Length} ");
        foreach (var kafkaEvent in incomingKafkaEvents)
        {
            var key = kafkaEvent.Key;
            var random = new Random();
            var now = DateTime.UtcNow;
            var secInspection = random.Next(100);
            var userTrade = _protoDeserializer.Deserialize(kafkaEvent.Value, false, _consumeSerializationContext);

            var shares = userTrade.Quantity;
            var price = userTrade.Price;
            var amount = (double) shares * price;
            var user = key;
            var symbol = userTrade.Symbol;
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
            
            var tradeSettlementBytes = _protoSerializer.Serialize(tradeSettlement, _produceSerializationContext);
            var eventData = new KafkaEventData<string, byte[]>()
            {
                Key = symbol,
                Value = tradeSettlementBytes
            };
            outputRecords.AddAsync(eventData);
            numberRecordsProcessed++;
        }

        logger.LogInformation($"Processed {numberRecordsProcessed} records with output binding");
    }
}