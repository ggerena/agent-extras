---
name: mira
description: 'Usar cuando el usuario diga "mira" sobre un repositorio, pida "mirar este repo por encima" o leer solo el README y explicar qué hace en términos generales. Hace una exploración superficial: clonar si hace falta, leer el README y explicar el proyecto de forma simple, sin revisar código, ejecutar pruebas, iniciar servidores ni editar archivos.'
---

# Mira

## Alcance

Haz únicamente una exploración superficial del repositorio basada en su README.

Aplica este alcance a pedidos como:

- "mira este repo"
- "mira este repo por encima"
- "mira microsoft/presidio"
- "mira este repo y dime que hace"
- "mira este repo, clonalo si hace falta"

## Flujo

1. Si el repositorio no está en local y el usuario proporcionó una URL o `owner/repo`, clónalo en la
   carpeta de código configurada por el usuario o en otra ubicación segura del espacio de trabajo.
   No fijes una ruta específica de una persona.
2. Lee solo el README principal de la raíz, dando preferencia a `README.md`, después a `README.MD`
   y luego a otras variantes de README.
3. Explica en español simple:
   - para qué sirve el proyecto;
   - qué problema resuelve;
   - sus componentes o funciones principales, solo si el README los menciona;
   - cómo se usaría en términos generales, solo si el README lo menciona.
4. Mantén la respuesta breve y sin tecnicismos, salvo que el propio README los requiera.

## Límites

No inspecciones código fuente, pruebas, issues, PR, archivos de CI, ejemplos, documentación fuera del README ni configuración de paquetes.

No ejecutes compilaciones, pruebas, comprobaciones de estilo, comandos de instalación, servidores de desarrollo, Docker ni preparación de dependencias.

No edites archivos, crees commits, hagas push, crees PR ni des recomendaciones, salvo que el usuario lo pida expresamente después de la explicación general.

Si falta el README, informa que no se encontró en la raíz y proporciona solo los datos mínimos del repositorio disponibles en el listado de archivos.
