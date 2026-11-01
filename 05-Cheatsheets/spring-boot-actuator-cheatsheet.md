# Spring Boot Actuator Cheatsheet

## Endpoints comunes
| Endpoint | Descripción |
|----------|-------------|
| /actuator | Lista de endpoints disponibles |
| /actuator/health | Estado de la aplicación |
| /actuator/heapdump | Descarga de heap dump (HPROF) |
| /actuator/env | Variables de entorno |
| /actuator/beans | Beans de Spring |
| /actuator/metrics | Métricas de la aplicación |

## Descargar heapdump
```bash
curl -s -o heapdump.hprof http://<host>:<port>/actuator/heapdump
```

## Analizar heapdump
```bash
# Extraer strings
strings -a heapdump.hprof | grep -iE 'setUsername|setPassword|jdbc:'

# Buscar clases específicas
grep -aoE 'Lcom/[A-Za-z0-9/$]+;' heapdump.hprof | sort -u
```

## Mitigación
- Deshabilitar endpoints sensibles
- Configurar autenticación en Actuator
- No exponer /actuator/heapdump en producción