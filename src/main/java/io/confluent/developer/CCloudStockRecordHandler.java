package io.confluent.developer;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.confluent.developer.proto.TradeSettlementProto;
import io.confluent.developer.proto.TradeSettlementProto.TradeSettlement;
import io.confluent.developer.proto.TradeSettlementProto.TradeSettlement.Builder;
import io.confluent.kafka.serializers.protobuf.KafkaProtobufSerializer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueResponse;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Random;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

public class CCloudStockRecordHandler implements RequestHandler<Map<String, Object>, Void> {
    private final Producer<String, TradeSettlementProto.TradeSettlement> producer;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final Map<String, Object> configs = new HashMap<>();
    private final StringDeserializer stringDeserializer = new StringDeserializer();

    public CCloudStockRecordHandler() {
        configs.putAll(getSecretsConfigs());
        configs.put("security.protocol", "SASL_SSL");
        configs.put("sasl.mechanism", "PLAIN");
        configs.put("basic.auth.credentials.source", "USER_INFO");
        configs.put(ProducerConfig.CLIENT_ID_CONFIG, "LambdaProducer");
        configs.put(ProducerConfig.ACKS_CONFIG, "all");
        configs.put(ProducerConfig.CLIENT_DNS_LOOKUP_CONFIG, "use_all_dns_ips");
        configs.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        configs.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaProtobufSerializer.class);
        
        producer = new KafkaProducer<>(configs);
        stringDeserializer.configure(configs, false);
    }

    @Override
    @SuppressWarnings("unchecked")
    public Void handleRequest(Map<String, Object> payload, Context context) {
        List<Future<RecordMetadata>> tradeSettlementFutures = new ArrayList<>();
        LambdaLogger logger = context.getLogger();
        logger.log("Configs are " + configs);
        Map<String, List<Map<String, Object>>> records = (Map<String, List<Map<String, Object>>>) payload.get("records");

        records.forEach((key, recordList) -> recordList.forEach(recordMap -> {
            byte[] keyBytes;
            String tradeKey = null;
            if (recordMap.containsKey("key")) {
                keyBytes = decode((String)recordMap.get("key"));
                tradeKey = stringDeserializer.deserialize("", keyBytes);
            }
            byte[] bytes = decode((String)recordMap.get("value"));
            Map<String, Object> trade = getMapFromString(stringDeserializer.deserialize("", bytes));
            logger.log("Key is " + tradeKey + " Record is " + trade);
            Instant now = Instant.now();
            int secInspection = new Random().nextInt(100);
            Builder builder = TradeSettlement.newBuilder();
            int shares = (Integer)trade.get("QUANTITY");
            int price = (Integer)trade.get("PRICE");
            builder.setAmount(((double)shares * price));
            builder.setUser(Objects.requireNonNullElse(tradeKey, "NO USER"));
            builder.setSymbol((String)trade.get("SYMBOL"));
            builder.setTimestamp(now.toEpochMilli());
            String disposition;
            String reason;
            
            if (builder.getUser().equals("NO USER")) {
                disposition = "Rejected";
                reason = "No user account specified";
            } else if (builder.getAmount() > 100000) {
                disposition = "Pending";
                reason = "Large trade";
            } else if (secInspection < 30) {
                disposition = "SEC Flagged";
                reason = "This trade looks sus";
            } else {
               disposition = "Completed";
               reason = "Within same day limit";
            }
            builder.setDisposition(disposition);
            builder.setReason(reason);

            TradeSettlement tradeSettlement = builder.build();

            logger.log("Trade Settlement result " + tradeSettlement);
            ProducerRecord<String, TradeSettlement> settlementRecord = new ProducerRecord<>("trade-settlements", tradeSettlement.getSymbol(), tradeSettlement);
            tradeSettlementFutures.add(producer.send(settlementRecord));
        })
        );
        
        tradeSettlementFutures.forEach((recordMetadataFuture -> {
            try {
                RecordMetadata metadata = recordMetadataFuture.get(5, TimeUnit.SECONDS);
                if (metadata != null) {
                    String message = String.format("Sent record to CCloud Kafka topic=%s, offset=%d, timestamp=%s", metadata.topic(), metadata.offset(), metadata.timestamp());
                    logger.log(message);
                }
            } catch (Exception e) {
                logger.log("Caught exception trying to produce " + e.getMessage());
            }
        }));


        return null;
    }

    private byte[] decode(final String encoded) {
        return Base64.getDecoder().decode(encoded);
    }

    private <K,V> Map<K, V> getMapFromString(final String value)  {
        try {
            return objectMapper.readValue(value, new TypeReference<>() {
            });
        } catch (JsonProcessingException e) {
            throw new RuntimeException(e);
        }
    }

    private Map<String, String> getSecretsConfigs() {
        String secretName = "CCloudLambdaCredentials";
        Region region = Region.of("us-west-2");
        SecretsManagerClient client = SecretsManagerClient.builder()
                .region(region)
                .build();
        String secret;
        GetSecretValueRequest getSecretValueRequest = GetSecretValueRequest.builder()
                .secretId(secretName)
                .build();
        GetSecretValueResponse getSecretValueResponse;
        try {
            getSecretValueResponse = client.getSecretValue(getSecretValueRequest);
            if (getSecretValueResponse.secretString() != null) {
                secret = getSecretValueResponse.secretString();
            } else {
                secret = new String(Base64.getDecoder().decode(getSecretValueResponse.secretBinary().asByteBuffer()).array());
            }
            return getMapFromString(secret);

        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
