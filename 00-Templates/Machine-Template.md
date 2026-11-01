# {{MACHINE_NAME}} — Hack The Box ({{DIFICULTAD}}, {{OS}})

> [!info] Información de la máquina
> - **Plataforma:** Hack The Box
> - **Máquina:** {{MACHINE_NAME}}
> - **OS:** {{OS}}
> - **Dificultad:** {{DIFICULTAD}}
> - **IP objetivo:** `{{IP_OBJETIVO}}` *(cambió a mitad de sesión respecto a la IP inicial — la máquina se reseteó)*
> - **IP atacante (tun0):** `{{IP_ATACANTE}}`
> - **Dominios:** `{{DOMINIO_1}}` `{{DOMINIO_2}}`

---

## Índice

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Reconocimiento](#2-reconocimiento)
3. [Enumeración](#3-enumeración)
4. [Análisis de Vulnerabilidades](#4-análisis-de-vulnerabilidades)
5. [Explotación](#5-explotación)
6. [Escalada de Privilegios](#6-escalada-de-privilegios)
7. [Captura de Flags](#7-captura-de-flags)
8. [Lecciones de método](#8-lecciones-de-metodo)

---

## 1. Resumen Ejecutivo

Descripción breve de la máquina, qué servicios estaban expuestos, y el camino general de compromiso.

## 2. Reconocimiento

```bash
sudo nmap -p- --min-rate=5000 -sCV -T4 {{IP_OBJETIVO}} -oN scan_{{MACHINE_NAME}}
```

## 3. Enumeración

Detalle de la enumeración de servicios web, directorios, subdominios, etc.

## 4. Análisis de Vulnerabilidades

| Vulnerabilidad | CVE | Vector | Impacto |
|----------------|-----|--------|---------|
| | | | |

## 5. Explotación

Descripción del exploit, payloads usados, comandos ejecutados.

```bash
# Comando de explotación
```

## 6. Escalada de Privilegios

Descripción de cómo se pasó de usuario inicial a root/admin.

## 7. Captura de Flags

| Flag | Ruta | Estado |
|------|------|--------|
| User flag | `/home/{{USUARIO}}/user.txt` | ❌ Pendiente |
| Root flag | `/root/root.txt` | ❌ Pendiente |

## 8. Lecciones de método

| Lección | Explicación |
|---------|-------------|
| 1 | [Lección 1] |
| 2 | [Lección 2] |

---

> [!quote] Nota de procedencia
> Este documento contiene únicamente hallazgos verificados con comandos ejecutados en esta sesión. Cuando incluyo algo de writeups públicos o hipótesis sin comprobar, lo marco explícitamente como *(hipótesis)* o *(no verificado)*.