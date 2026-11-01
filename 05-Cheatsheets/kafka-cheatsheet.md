# Kafka Cheatsheet

## Listar topics
```bash
/opt/kafka_2.13-4.3.1/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## Producir mensaje
```bash
echo 'mensaje' | /opt/kafka_2.13-4.3.1/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic <topic_name>
```

## Consumir mensajes
```bash
/opt/kafka_2.13-4.3.1/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic <topic_name> \
  --from-beginning \
  --max-messages 5 \
  --timeout-ms 5000
```

## Ejemplo práctico (HTB Stream)
```bash
# Producir mensaje a DLQ
echo '<?xml version="1.0"?><broken/>' | /opt/kafka_2.13-4.3.1/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic aidx.flightleg.dlq.v1

# Consumir mensajes
/opt/kafka_2.13-4.3.1/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic aidx.flightleg.dlq.v1 \
  --from-beginning \
  --max-messages 5 \
  --timeout-ms 5000
```