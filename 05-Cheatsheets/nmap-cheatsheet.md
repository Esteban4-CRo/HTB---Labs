# Nmap Cheatsheet

## Escaneo básico
```bash
# Escaneo de puertos comunes
nmap -sCV -T4 <IP>

# Escaneo de todos los puertos
nmap -p- --min-rate=5000 -sCV -T4 <IP> -oN scan.txt

# Escaneo de UDP
sudo nmap -sU -p- <IP>
```

## Escaneo de vulnerabilidades
```bash
nmap -sV --script vuln <IP>
```

## Escaneo de SSL/TLS
```bash
nmap -p 443 --script ssl-cert <IP>
```

## Resultados típicos
```
PORT    STATE SERVICE   VERSION
22/tcp  open  ssh       OpenSSH X.Xp1 Ubuntu
80/tcp  open  http      nginx X.X.X.X
443/tcp open  ssl/http  nginx/X.X.X.X