package io.confluent.developer.clients;

import io.confluent.developer.proto.ShippingProto;
import io.confluent.kafka.serializers.protobuf.KafkaProtobufDeserializer;
import io.confluent.kafka.serializers.protobuf.KafkaProtobufDeserializerConfig;
import org.apache.kafka.clients.consumer.Consumer;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.io.FileInputStream;
import java.io.IOException;
import java.time.Duration;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

public class EventConsumer {

    public static void main(String[] args) throws IOException {
        var consumerProperties = new Properties();
        try (FileInputStream fis = new FileInputStream("src/main/resources/confluent.properties")) {
            consumerProperties.load(fis);
        }
        var consumerConfigs = new HashMap<String, Object>();
        consumerProperties.forEach((k, v) -> consumerConfigs.put((String) k, v));

        consumerConfigs.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        consumerConfigs.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        consumeProtobufRecords(consumerConfigs);

    }
    

    static void consumeProtobufRecords(final Map<String, Object> baseConfigs) {
        var consumerConfigs = new HashMap<>(baseConfigs);
        consumerConfigs.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaProtobufDeserializer.class);
        consumerConfigs.put(KafkaProtobufDeserializerConfig.SPECIFIC_PROTOBUF_VALUE_TYPE, ShippingProto.Shipped.class);
        consumerConfigs.put(ConsumerConfig.GROUP_ID_CONFIG, "proto-group");
        try (final Consumer<String, ShippingProto.Shipped> protoConsumer = new KafkaConsumer<>(consumerConfigs)) {
            final String topicName = "lambda-test-output";
            protoConsumer.subscribe(Collections.singletonList(topicName));
            ConsumerRecords<String, ShippingProto.Shipped> records = protoConsumer.poll(Duration.ofSeconds(5));
            records.forEach(record -> {
                final ShippingProto.Shipped shippingEvent = record.value();
                System.out.println("Consumed event from Lambda " + shippingEvent);
                });
        }
    }
}
