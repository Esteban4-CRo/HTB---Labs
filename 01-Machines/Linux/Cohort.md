# Cohort — Hack The Box (Easy, Linux)

> Informe de laboratorio | 14 de noviembre de 2026 | Estado: comprometida hasta `root`

> [!warning] Entorno autorizado
> Pruebas realizadas exclusivamente contra la máquina de laboratorio Cohort de Hack The Box. La dirección IP puede cambiar al reiniciar la máquina.

## Índice

1. [Resumen ejecutivo](#1-resumen-ejecutivo)
2. [Alcance y metodología](#2-alcance-y-metodología)
3. [Reconocimiento](#3-reconocimiento)
4. [Enumeración web y SSRF](#4-enumeración-web-y-ssrf)
5. [Acceso inicial: Marimo](#5-acceso-inicial-marimo)
6. [Escalada de privilegios](#6-escalada-de-privilegios)
7. [Impacto y remediación](#7-impacto-y-remediación)
8. [Evidencias y estado de flags](#8-evidencias-y-estado-de-flags)

## 1. Resumen ejecutivo

La superficie web de Cohort expone una función que valida y obtiene una URL suministrada por el usuario. La validación bloquea direcciones loopback en su forma habitual, pero una representación alternativa (`127.1`) permitió alcanzar el servicio local y obtener información de un upstream interno. Esa respuesta reveló un subdominio de Marimo que no estaba publicado en la navegación del sitio.

El servicio interno de Marimo fue vulnerable a ejecución de comandos sin autenticación mediante su terminal WebSocket (CVE-2026-39987), lo que proporcionó una shell como `marimo`. Desde esa cuenta se identificó y explotó una condición de carrera local de PackageKit (CVE-2026-41651), que instaló un binario `bash` SUID. La verificación mostró EUID 0 y permitió leer la flag de `root`.

**Cadena de ataque:** enumeración de servicios → validación de URL vulnerable a SSRF → descubrimiento de upstream interno → RCE en Marimo → shell como `marimo` → carrera TOCTOU de PackageKit → acceso como `root`.

## 2. Alcance y metodología

- **Objetivo:** máquina Linux Cohort (Hack The Box).
- **Dominio principal:** `cohort.htb`.
- **IP de la sesión inicial:** `10.129.197.212`.
- **IP observada tras reiniciar la máquina:** `10.129.244.174`. Se debe confirmar la IP activa antes de repetir las pruebas.
- **IP de laboratorio del atacante observada en las capturas:** `10.10.15.49`.
- **Servicios evaluados:** SSH, HTTP/HTTPS, endpoint de validación de URLs, upstream Marimo y sistema local tras obtener acceso.

La metodología fue de caja negra: reconocimiento de puertos y TLS, navegación manual, inspección de solicitudes/respuestas con Burp Suite, enumeración controlada del endpoint, validación de los servicios internos encontrados y, tras el acceso inicial, enumeración local y confirmación de privilegios. Las capturas que siguen documentan los resultados observados; la posible vulnerabilidad SCTP encontrada durante la enumeración local se trata como indicio, no como vector confirmado.

## 3. Reconocimiento

### 3.1 Escaneo de servicios

```bash
sudo nmap -p- -sSCV --min-rate 5000 -Pn 10.129.197.212 -oN scan
```

| Puerto | Servicio | Resultado |
|---|---|---|
| 22/tcp | SSH | OpenSSH 9.6p1 (Ubuntu) |
| 80/tcp | HTTP | nginx 1.24.0; redirección a `https://cohort.htb/` |
| 443/tcp | HTTPS | nginx 1.24.0; certificado para `cohort.htb` y `*.cohort.htb` |

SSH estaba expuesto, pero no se contaba inicialmente con credenciales. La aplicación web y el certificado wildcard justificaron priorizar la enumeración HTTP y de subdominios.

## 4. Enumeración web y SSRF

### 4.1 Comportamiento de la aplicación

El portal `portal.html` permite registrar una URL como fuente de reportes. La interfaz indica que se consulta el endpoint, se comprueba el tipo de contenido y se genera una vista previa. Al introducir `http://127.0.0.1`, la aplicación rechazó la solicitud con el mensaje `Internal or loopback addresses are not permitted`.

La solicitud observada en Burp Suite fue `POST /api/validate`, con un cuerpo JSON que contiene `url` y `format`. La validación era el límite de seguridad relevante: el servidor realiza la petición de salida en nombre del usuario.

![El portal rechaza la representación directa de loopback](../../Images/cohort/Pasted%20image%2020261114175946.png)

![Solicitud y respuesta inicial de validación capturadas con Burp Suite](../../Images/cohort/Pasted%20image%2020261114181947.png)

### 4.2 Acceso a un servicio interno

En las pruebas del laboratorio, una representación alternativa de loopback (`127.1`) no fue bloqueada. Al validar `http://127.1/status`, la respuesta incluyó datos de configuración del upstream y reveló el host interno `nb-1be3782a8afd3ad5.cohort.htb`, asociado con el servicio local `127.0.0.1:8888`. Esto es evidencia de una SSRF y de una validación de destinos que puede eludirse; no se debe confundir con una simple enumeración de directorios.

El subdominio interno resolvió a una instancia Marimo que mostraba una pantalla de autenticación. La existencia de autenticación no evitó la explotación del endpoint vulnerable descrito en la siguiente sección.

![El endpoint responde para la forma alternativa de loopback](../../Images/cohort/Pasted%20image%2020261114182021.png)

![Respuesta que revela el host interno de Marimo y su upstream](../../Images/cohort/Pasted%20image%2020261114182701.png)

![Pantalla de autenticación del servicio Marimo interno](../../Images/cohort/Pasted%20image%2020261114182834.png)

## 5. Acceso inicial: Marimo

La instancia identificada ejecutaba una versión afectada por **CVE-2026-39987**, una vulnerabilidad de ejecución remota de comandos preautenticada en Marimo. La evidencia de la sesión muestra el uso del terminal WebSocket y una conexión inversa recibida como el usuario `marimo` (UID/GID 1000).

La captura confirma tanto la identidad de la shell como el cambio de dirección de la máquina tras reiniciarla. No se incluye aquí el código del exploit; para el análisis técnico, consultar el [aviso de seguridad de Marimo](https://github.com/marimo-team/marimo/security/advisories/GHSA-2679-6mx9-h9xc).

![Shell recibida como marimo a través del servicio interno](../../Images/cohort/Pasted%20image%2020261114183328.png)

## 6. Escalada de privilegios

### 6.1 Enumeración local

Se ejecutó LinPEAS para identificar configuraciones y componentes potencialmente vulnerables. Su salida señaló un kernel Linux `6.8.0-136-generic` con SCTP disponible y una posible exposición asociada a **CVE-2026-74469**. Este resultado es un candidato de enumeración: las capturas no muestran que se explotara ni que otorgara privilegios.

![Hallazgo candidato de LinPEAS relacionado con SCTP](../../Images/cohort/Pasted%20image%2020261114183952.png)

### 6.2 Vector confirmado: PackageKit TOCTOU

La escalada que sí quedó confirmada utilizó **CVE-2026-41651**, una condición de carrera TOCTOU en PackageKit. La evidencia muestra la preparación y ejecución de la prueba de concepto, la creación de `/var/tmp/.suid_bash` y la espera hasta que el archivo adquiere el bit SUID. Después, `id` reportó `euid=0(root)`.

La prueba se basa en código de terceros; antes de reutilizarlo, debe verificarse su procedencia e integridad. La captura de la sesión muestra el resultado del laboratorio, no una recomendación para ejecutar el exploit en sistemas reales.

![La prueba de concepto de PackageKit prepara el binario SUID](../../Images/cohort/Pasted%20image%2020261114184359.png)

![Verificación de EUID 0 y lectura de root.txt](../../Images/cohort/Pasted%20image%2020261114184538.png)

## 7. Impacto y remediación

| Hallazgo | Evidencia e impacto | Recomendación |
|---|---|---|
| SSRF en `/api/validate` | El servidor acepta una URL controlada por el usuario; se evadió el bloqueo de loopback y se obtuvo información de un upstream interno. | Aplicar una lista permitida estricta de destinos; resolver y validar todas las direcciones IPv4/IPv6; bloquear loopback, rangos privados, link-local y redirecciones a destinos no permitidos; revalidar cada salto y limitar el acceso de red saliente. |
| Marimo vulnerable (CVE-2026-39987) | Acceso al terminal WebSocket y ejecución de comandos sin autenticación, con shell como `marimo`. | Actualizar Marimo a una versión corregida; no exponer el servicio interno; exigir autenticación y restringir el acceso al WebSocket mediante controles de red. |
| PackageKit vulnerable (CVE-2026-41651) | La condición de carrera produjo un `bash` SUID y permitió obtener EUID 0 desde una cuenta sin privilegios. | Aplicar la actualización de seguridad del proveedor; limitar el software de gestión de paquetes a los usuarios que lo necesiten; revisar periódicamente binarios SUID y permisos de `/var/tmp`. |
| Candidato SCTP (CVE-2026-74469) | LinPEAS lo señaló como posible exposición, pero no se verificó como vector de escalada en esta sesión. | Validar la aplicabilidad con la versión y los avisos del proveedor; deshabilitar SCTP si no se utiliza y mantener el kernel actualizado. |

## 8. Evidencias y estado de flags

- **Acceso inicial:** confirmado como `marimo` (UID 1000).
- **Privilegios de root:** confirmados por `euid=0(root)`.
- **Root flag:** lectura de `root.txt` visible en la captura final; el valor se omite deliberadamente.
- **User flag:** el archivo `user.txt` aparece en el listado del directorio personal, pero las capturas disponibles no muestran su lectura. No se marca como verificada.

### Referencias

- [Aviso de seguridad de Marimo — GHSA-2679-6mx9-h9xc](https://github.com/marimo-team/marimo/security/advisories/GHSA-2679-6mx9-h9xc)
- CVE-2026-41651 — PackageKit TOCTOU (vector local observado en el laboratorio).
- CVE-2026-74469 — SCTP, únicamente candidato reportado por la enumeración local.
