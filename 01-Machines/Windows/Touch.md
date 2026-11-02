---
title: Touch
description: Resumen y aprendizajes defensivos de un laboratorio Windows.
tags:
  - HTB
  - Windows
---

# Touch

> [!info] Ficha
> - **Plataforma:** Hack The Box
> - **Sistema:** Windows
> - **Dificultad:** Easy
> - **Estado:** completada
> - **Fecha:** 1 de noviembre de 2026

## Resumen

Este laboratorio muestra cómo varias debilidades de configuración y control de acceso pueden encadenarse y afectar un kiosco Windows y los servicios que lo respaldan. La revisión de la aplicación y sus dependencias destaca la importancia de proteger los datos del dispositivo, aislar las aplicaciones interactivas y restringir los privilegios de los servicios.

Esta página ofrece un resumen del ejercicio y sus aprendizajes. No incluye comandos, credenciales, direcciones de objetivos, capturas operativas ni instrucciones para reproducir la cadena.

## Lecciones defensivas

- No usar identificadores de dispositivos como contraseñas ni exponerlos en endpoints públicos.
- Mantener los secretos fuera del código, los archivos accesibles y las respuestas del cliente.
- Aplicar aislamiento de aplicaciones y restringir la apertura de programas externos en kioscos.
- Ejecutar cada servicio con privilegios mínimos y limitar los permisos de escritura.
- Revisar dependencias, registrar errores y alertar ante actividad anómala.

## Alcance

Ejercicio realizado en un entorno de laboratorio autorizado. El contenido se limita a contexto y recomendaciones defensivas.