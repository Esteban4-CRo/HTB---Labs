# 365 Days of Hack The Box

> Un día a la vez. Un laboratorio a la vez.

Reto personal: resolver máquinas de [Hack The Box](https://www.hackthebox.com/) durante 365 días seguidos y documentar el proceso, los aprendizajes y los errores. Este repositorio reúne writeups y notas de laboratorio organizados por máquina y por tema.

El objetivo no es acumular máquinas, sino mantener la constancia y aprender algo nuevo en cada laboratorio.

---

## Estado del reto

| Métrica | Valor |
|---------|-------|
| Objetivo | Resolver máquinas durante 365 días consecutivos |
| Máquinas documentadas | 16 |
| Última máquina registrada | Responder — 01 Nov 2026 |

---

## Progreso

| # | Máquina | OS | Dificultad | Vector inicial | Privesc | Fecha |
|---|---------|-----|-----------|----------------|---------|-------|
| 1 | [Reactor](01-Machines/Linux/Reactor.md) | Linux | Easy | CVE-2025-55182 (Next.js RCE no autenticado) | Node.js Inspector / CDP mal configurado | 08 Aug 2026 |
| 2 | [TwoMillion](01-Machines/Linux/TwoMillion.md) | Linux | Easy | Mass Assignment / Command Injection en API | CVE-2023-0386 (OverlayFS) | 09 Aug 2026 |
| 3 | [Appointment](01-Machines/Linux/Appoinment.md) | Linux | Very Easy | SQL Injection — bypass de autenticación | N/A (acceso directo a flag) | 11 Aug 2026 |
| 4 | [Fireflow](01-Machines/Linux/Fireflow.md) | Linux | Medium Easy | CVE-2026-33017 (Langflow RCE) | JWT Bypass (`alg: none`) + Kubelet API Exec (WebSockets) | 13 Aug 2026 |
| 5 | [Sequel](01-Machines/Linux/Sequel.md) | Linux | Very Easy | Acceso MariaDB sin contraseña (`root@3306`) | N/A (acceso directo a flag) | 15 Aug 2026 |
| 6 | [Odyssey](01-Machines/Active-Directory/Odyssey.md) | Windows | Insane | NoSQL Pipeline Injection + WebAuthn Synthetic Registration | CVE-2025-1302 → GodPotato → dMSA Ouroboros → YAML Deser → DCSync | 20 Aug 2026 |
| 7 | [Crocodile](01-Machines/Linux/Cocodrile.md) | Linux | Very Easy | FTP Anonymous Login (`allowed.userlist` / `allowed.userlist.passwd`) | Credential Reuse en panel `login.php` | 23 Aug 2026 |
| 8 | [DanglingTree](01-Machines/Active-Directory/DanglingTree.md) | Windows | Medium | SMB anónimo → PDF con creds → WAC RCE (PowerShell injection) → SmarterMail Hub exploit | DPAPI credential theft → DCSync → Pass-the-Hash | 26 Aug 2026 |
| 9 | [Bedside](01-Machines/Linux/Bedside.md) | Linux | Medium | CVE-2025-64512 (pdfminer.six RCE) + Path Traversal (Docker container escape) | PyTorch CheckpointLoader (`torch.load` RCE) | 23 Sep 2026 |
| 10 | [MakeSense](01-Machines/Linux/MakeSense.md) | Linux | Medium | XSS almacenado en WordPress → RCE como `www-data` | ChromeDriver RCE como `admin` → servicio OCR interno como root | 25 Sep 2026 |
| 11 | [Orion](01-Machines/Linux/Orion.md) | Linux | Easy | Craft CMS pre-auth RCE (CVE-2025-32432) | Telnetd authentication bypass (CVE-2026-24061) | 01 Oct 2026 |
| 12 | [Layover](01-Machines/Linux/Layover.md) | Linux | Medium | Credenciales RDP → pivote WiFi → credenciales HTTP → Craft CMS RCE (CVE-2026-28695) | CUPS LPE (CVE-2026-34990) | 09 Oct 2026 |
| 13 | [Stream](01-Machines/Linux/Stream.md) | Linux | Medium | Spring Boot Actuator `/actuator/heapdump` → credenciales ClickHouse (`svc_events`) → XXE in-band | ClickHouse `default` WRITE ON FILE → formateador `aidx_quarantine.py` como `root` vía `aidx-dlq-drainer.timer` | 27 Oct 2026 |
| 14 | [DutyBound](01-Machines/Linux/DutyBound.md) | Linux | Medium | SQLi en campo `airline_use` de tarjeta de embarque (BCBP) → `COPY ... TO PROGRAM` → RCE como `postgres` | Pivote X11/XTEST a `dutyfree-kiosk` → CSV injection en `/opt/vrs/data/duty-rates.csv` → `root` | 28 Oct 2026 |
| 15 | [Touch](01-Machines/Windows/Touch.md) | Windows | Easy | SSH como `svc-infra` → XXE in-band → ClickHouse `default` WRITE ON FILE → formateador `aidx_quarantine.py` como `root` vía `aidx-dlq-drainer.timer` | 28 Oct 2026 |
| 16 | [Responder](01-Machines/Windows/Responder.md) | Windows | Very Easy | LFI → captura y crackeo de NetNTLMv2 → acceso por WinRM | N/A (acceso directo a flag) | 01 Nov 2026 |

Se irá actualizando esta tabla con cada máquina resuelta, en el orden en que caen.

---

## Estructura del repositorio

```text
.
├── 00-Templates/         # Plantillas para nuevos writeups
│   └── Machine-Template.md
├── 01-Machines/          # Writeups organizados por sistema operativo
│   ├── Linux/
│   ├── Windows/
│   └── Active-Directory/
├── 02-Techniques/        # Técnicas y metodologías
├── 03-Tools/             # Herramientas y scripts
├── 04-CVE-Database/      # Base de datos de CVE
├── 05-Cheatsheets/       # Cheatsheets de referencia
├── Certficados/          # Capturas de constancia completada máquina
├── Images/               # Capturas de pantalla organizadas por máquina
│   ├── Responder/        # Capturas de Responder
│   ├── _shared/          # Imágenes compartidas entre máquinas
│   └── _unused/          # Imágenes sin referencia en ningún writeup
├── README.md             # Este archivo
└── .obsidian/            # Configuración de Obsidian
```

Los writeups están escritos como notas de Obsidian y pueden incluir callouts (`[!info]`, `[!success]`) y diagramas Mermaid. Se recomienda abrir este repositorio como vault en Obsidian para conservar ese formato; las imágenes usan rutas relativas dentro del vault. También se pueden consultar como Markdown en GitHub.

---

## Metodología general

Cada writeup sigue, en la medida de lo posible, la misma estructura:

1. Enumeración inicial (puertos, servicios, tecnologías).
2. Identificación del vector de explotación inicial.
3. Obtención de acceso (shell / RCE / credenciales).
4. Enumeración post-explotación.
5. Escalada de privilegios.
6. Captura de flags.
7. Lecciones aprendidas y remediación.

---

## Herramientas frecuentes

- [Inventario de herramientas](03-Tools/tools-list.md)
- Nmap
- WhatWeb
- Burp Suite
- curl / jq
- Python (PoCs y scripts de explotación)
- Responder
- John the Ripper
- Evil-WinRM
- Node.js / WebSockets (cuando el objetivo lo requiere)
- Impacket (MSSQL, secretsdump, ticketConverter)
- BloodHound / BloodyAD / Certipy
- Ligolo-ng (pivoting)
- Evil-WinRM
- John the Ripper / Hashcat
- GodPotato / Rubeus
- SSH

---

## Aviso

Todo el contenido de este repositorio corresponde a máquinas de laboratorio de Hack The Box, resueltas en entornos aislados y con fines exclusivamente educativos. Ninguna técnica aquí descrita está dirigida a sistemas de producción ni a infraestructura ajena a estos laboratorios.

---

## Contacto

Si encuentras un error en algún writeup o quieres discutir una técnica alternativa, los issues y pull requests están abiertos.