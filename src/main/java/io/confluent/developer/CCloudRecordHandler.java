package io.confluent.developer;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.protobuf.Timestamp;
import io.confluent.developer.proto.PurchaseProto;
import io.confluent.developer.proto.ShippingProto;
import io.confluent.kafka.serializers.protobuf.KafkaProtobufDeserializer;
import io.confluent.kafka.serializers.protobuf.KafkaProtobufDeserializerConfig;
import io.confluent.kafka.serializers.protobuf.KafkaProtobufSerializer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
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
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

public class CCloudRecordHandler implements RequestHandler<Map<String, Object>, Void> {
    private final Producer<String, ShippingProto.Shipped> producer;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final Map<String, Object> configs = new HashMap<>();
    private final KafkaProtobufDeserializer<PurchaseProto.Purchase> protobufDeserializer = new KafkaProtobufDeserializer<>();

    public CCloudRecordHandler() {
        configs.putAll(getSecretsConfigs());
        configs.put("security.protocol", "SASL_SSL");
        final String username = (String) configs.get("username");
        final String password = (String) configs.get("password");
        String jaasConfig = String.format("org.apache.kafka.common.security.plain.PlainLoginModule   required username='%s'   password='%s';", username, password);
        configs.put("sasl.jaas.config", jaasConfig);
        configs.put("sasl.mechanism", "PLAIN");
        configs.put("basic.auth.credentials.source", "USER_INFO");
        configs.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        configs.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaProtobufSerializer.class);
        configs.put(KafkaProtobufDeserializerConfig.SPECIFIC_PROTOBUF_VALUE_TYPE, PurchaseProto.Purchase.class);
        
        producer = new KafkaProducer<>(configs);
        protobufDeserializer.configure(configs, false);
    }

    @Override
    @SuppressWarnings("unchecked")
    public Void handleRequest(Map<String, Object> payload, Context context) {
        List<Future<RecordMetadata>> shippingConfirmationMetadata = new ArrayList<>();
        LambdaLogger logger = context.getLogger();
        logger.log("Configs are " + configs);
        Map<String, List<Map<String, Object>>> records = (Map<String, List<Map<String, Object>>>) payload.get("records");
        records.forEach((key, recordList) -> {
                    logger.log("The Key is " + key);
                    recordList.forEach(recordMap -> {
                        byte[] bytes = decode(recordMap, "value");
                        PurchaseProto.Purchase purchase = protobufDeserializer.deserialize("lambda-test-input", bytes);
                        logger.log("The Value is " + purchase);
                        Instant now = Instant.now();
                        Timestamp timestamp = Timestamp.newBuilder().setSeconds(now.getEpochSecond()).setNanos(now.getNano()).build();
                        ShippingProto.Shipped shipped = ShippingProto.Shipped.newBuilder()
                                .setAddress("1123 Maple Avenue, Anytown, USA")
                                .setCustomerId(purchase.getCustomerId())
                                .setItem(purchase.getItem())
                                .setShippedAt(timestamp).build();

                        logger.log("Shipping item " + shipped);
                        ProducerRecord<String, ShippingProto.Shipped> shippedProducerRecord = new ProducerRecord<>("lambda-test-output", purchase.getCustomerId(), shipped);
                        shippingConfirmationMetadata.add(producer.send(shippedProducerRecord));
                    });
                }
        );
        
        shippingConfirmationMetadata.forEach((recordMetadataFuture -> {
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

    private byte[] decode(final Map<String, Object> map, final String key) {
        return Base64.getDecoder().decode((String) map.get(key));
    }

    private Map<String, String> getSecretsConfigs() {
        String secretName = "CCloudKey";
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
            return objectMapper.readValue(secret, new TypeReference<>() {
            });

        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
