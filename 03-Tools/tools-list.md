# Herramientas Utilizadas en HTB Writeups

## Escaneo y Reconocimiento
| Herramienta | Uso | Máquina |
|-------------|-----|---------|
| Nmap | Escaneo de puertos y servicios | Todas |
| RustScan | Escaneo rápido de puertos | Stream |
| Feroxbuster | Fuzzing de directorios web | Stream |
| WPScan | Escaneo de WordPress | MakeSense |
| ffuf | Fuzzing de vhosts y directorios | Stream |
| WhatWeb | Identificación de tecnologías web | Responder |

## Análisis Web y APIs
| Herramienta | Uso | Máquina |
|-------------|-----|---------|
| Burp Suite | Interceptación y modificación de requests | DanglingTree, Stream |
| curl | Peticiones HTTP | Todas |
| jq | Procesamiento de JSON | Stream |
| WPSScan | Escaneo de WordPress | MakeSense |

## Explotación
| Herramienta | Uso | Máquina |
|-------------|-----|---------|
| Python3 | Scripts de explotación (XXE, XXE in-band) | Stream, DutyBound |
| Netcat | Reverse shells | Todas |
| Socat | Redirección de puertos | - |
| Evil-WinRM | Acceso remoto a Windows mediante WinRM | Responder |

## Captura de credenciales
| Herramienta | Uso | Máquina |
|-------------|-----|---------|
| Responder | Captura de desafíos NetNTLMv2 | Responder |

## Escalada de Privilegios
| Herramienta | Uso | Máquina |
|-------------|-----|---------|
| LinPEAS | Enumeración de privilegios Linux | Todas |
| WinPEAS | Enumeración de privilegios Windows | - |
| Pspy | Monitoreo de procesos | Stream |
| ClickHouse client | Interacción con ClickHouse | Stream |
| Kafka console producer/consumer | Interacción con Kafka | Stream |

## Post-Explotación
| Herramienta | Uso | Máquina |
|-------------|-----|---------|
| John the Ripper | Crackeo de hashes NetNTLMv2 | Responder |
| Hashcat | Crackeo de contraseñas | - |
| Mimikatz | Extracción de credenciales Windows | - |
| Impacket | Herramientas de red y autenticación | - |
| BloodHound | Análisis de Active Directory | - |

## Análisis Forense
| Herramienta | Uso | Máquina |
|-------------|-----|---------|
| strings | Extracción de texto de binarios | Stream (heap dump) |
| grep | Búsqueda de patrones | Todas |
| xxd | Visualización hexadecimal | - |