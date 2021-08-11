package io.confluent.developer.clients;

import io.confluent.developer.proto.PurchaseProto;
import io.confluent.kafka.serializers.protobuf.KafkaProtobufSerializer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

public class DataProducer {


    public static void main(String[] args) throws IOException {
        var producerProperties = new Properties();
        try (FileInputStream fis = new FileInputStream("src/main/resources/confluent.properties")) {
            producerProperties.load(fis);
        }
        producerProperties.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        var producerConfigs = new HashMap<String, Object>();
        producerProperties.forEach((k, v) -> producerConfigs.put((String) k, v));

        System.out.println("Producing Proto records");
        produceProtobuf(producerConfigs);
    }

    private static void produceProtobuf(final Map<String, Object> originalConfigs) {
        Map<String, Object> producerConfigs = new HashMap<>(originalConfigs);
        producerConfigs.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaProtobufSerializer.class);

        try (final Producer<String, PurchaseProto.Purchase> producer = new KafkaProducer<>(producerConfigs)) {
            String topic = "lambda-test-input";
            PurchaseProto.Purchase purchase = PurchaseProto.Purchase.newBuilder()
                    .setAmount(100.00)
                    .setCustomerId("1234")
                    .setItem("shoes").build();

            PurchaseProto.Purchase purchaseII = PurchaseProto.Purchase.newBuilder()
                    .setAmount(333.00)
                    .setCustomerId("5678")
                    .setItem("pants").build();

            PurchaseProto.Purchase purchaseIII = PurchaseProto.Purchase.newBuilder()
                    .setAmount(5000.25)
                    .setCustomerId("5432")
                    .setItem("boat").build();

            List<PurchaseProto.Purchase> events = List.of(purchase, purchaseII, purchaseIII);


            events.forEach(event -> producer.send(new ProducerRecord<>(topic, event.getCustomerId(), event), ((metadata, exception) -> {
                if (exception != null) {
                    System.err.printf("Producing %s resulted in error %s", event, exception);
                } else {
                    System.out.println("Produced record to " + metadata);
                }
            })));
        }
    }

}
