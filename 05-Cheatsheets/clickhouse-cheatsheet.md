# ClickHouse Cheatsheet

## Conexión básica
```bash
curl -s -u "user:password" "http://<IP>/?query=SELECT+1"
```

## Listar bases de datos
```bash
curl -s -u "user:password" "http://<IP>/?query=SHOW+DATABASES"
```

## Listar tablas
```bash
curl -s -u "user:password" "http://<IP>/?query=SHOW+TABLES+FROM+<database>"
```

## Mostrar estructura de tabla
```bash
curl -s -u "user:password" --data-urlencode "query=SHOW+CREATE+TABLE+<database>.<table>" "http://<IP>/"
```

## Consultar datos
```bash
curl -s -u "user:password" --data-urlencode "query=SELECT+*+FROM+<database>.<table>" "http://<IP>/"
```

## Formato Vertical
```bash
curl -s -u "user:password" --data-urlencode "query=SELECT+*+FROM+<table>+FORMAT+Vertical" "http://<IP>/"
```

## Ejemplo práctico (HTB Stream)
```bash
# Listar tablas de partner_feed
curl -s -u "svc_events:Yl4aCgh4y2PnU" "http://db.htb-airport.htb/?query=SHOW+TABLES+FROM+partner_feed"

# Mostrar estructura de tabla
curl -s -u "svc_events:Yl4aCgh4y2PnU" --data-urlencode "query=SHOW+CREATE TABLE partner_feed.flightleg_json" "http://db.htb-airport.htb/"
```