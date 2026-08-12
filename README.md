# 365 Days of Hack The Box

> Poder de la capa, madafakin uan jandred an eigdi nain.

Reto personal: resolver máquinas de [Hack The Box](https://www.hackthebox.com/) durante 365 días seguidos, documentando cada writeup, técnica y error en el camino. Este repositorio es mi cuaderno de bitácora público: enumeración, explotación y escalada de privilegios, máquina por máquina.

No es una carrera por el número. Es una carrera contra la excusa de "hoy no tengo tiempo".

---

## Estado del reto

|Métrica|Valor|
|---|---|
|Día actual|3|
|Máquinas resueltas|3|
|Racha actual|3 días|
|Última actualización|11 Aug 2026|

---

## Progreso

|#|Máquina|OS|Dificultad|Vector inicial|Privesc|Fecha|
|---|---|---|---|---|---|---|
|1|[Reactor](HTB/Reactor.md)|Linux|Easy|CVE-2025-55182 (Next.js RCE no autenticado)|Node.js Inspector / CDP mal configurado|08 Aug 2026|
|2|[TwoMillion](HTB/TwoMillion.md)|Linux|Easy|Mass Assignment / Command Injection en API|CVE-2023-0386 (OverlayFS)|09 Aug 2026|
<<<<<<< HEAD
|3|[Appointment](HTB/Appoinment.md)|Linux|Very Easy|SQL Injection — bypass de autenticación|N/A (acceso directo a flag)|11 Aug 2026|
=======
>>>>>>> 295a4e25b09bfc51624d40531bbad165838c2bb8

Se irá actualizando esta tabla con cada máquina resuelta, en el orden en que caen.

---

## Estructura del repositorio

```text
.
├── HTB/          # Writeups en Markdown, uno por máquina
├── Images/       # Capturas de pantalla usadas en los writeups
├── Certificados/ # Captturas de constancia completada maquina
└── README.md     # Este archivo
```

Los writeups están escritos originalmente como notas de Obsidian (por eso usan callouts tipo `[!info]`, `[!success]`, etc. y diagramas Mermaid), así que se recomienda leerlos con un visor que soporte ambos, aunque también son perfectamente legibles como Markdown plano en GitHub.

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

- Nmap
- Burp Suite
- curl / jq
- Python (PoCs y scripts de explotación)
- Node.js (cuando el objetivo lo requiere)
- SSH

---

## Aviso

Todo el contenido de este repositorio corresponde a máquinas de laboratorio de Hack The Box, resueltas en entornos aislados y con fines exclusivamente educativos. Ninguna técnica aquí descrita está dirigida a sistemas de producción ni a infraestructura ajena a estos laboratorios.

---

## Contacto

Si encuentras un error en algún writeup o quieres discutir una técnica alternativa, los issues y pull requests están abiertos.