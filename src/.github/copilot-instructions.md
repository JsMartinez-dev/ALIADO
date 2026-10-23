# Instrucciones del repositorio para GitHub Copilot

Antes de implementar cualquier tarea, lee el archivo `AGENTS.md` de la raíz y síguelo como guía arquitectónica del proyecto.

Este repositorio es un monolito modular que aplica Arquitectura Limpia. Respeta en todos los módulos la estructura y las reglas descritas en `AGENTS.md`, especialmente la separación entre `domain`, `application`, `infrastructure` y `presentation`, la inversión de dependencias y los límites entre módulos.

Antes de modificar código, inspecciona recursivamente `/docs` y lee el Plan General del proyecto y todos los `spec` disponibles. Usa estos documentos como fuente de verdad, traza los cambios a sus requisitos y no inventes funcionalidades. Si hay conflictos documentales o faltan archivos, informa la situación en lugar de afirmar que revisaste información inaccesible.

Haz cambios acotados, conserva las convenciones existentes, prueba lo que modifiques e informa de manera honesta qué verificaciones ejecutaste y cuáles no pudiste ejecutar.
