---
name: probar
description: Ver y probar la app Swift de SAVERS en el simulador sin gastar capturas ni tocar datos reales. Úsalo siempre que cambies algo en swift/ y haya que verificarlo, revisar en el simulador, ver cómo quedó, comparar estados de Hoy/Historial, o tocar/escribir en la app para probar una interacción.
---

# Probar la app Swift

Todo pasa por `swift/tools/probar.sh`. La app abre en **escenarios** con datos inventados, en una carpeta y
unas preferencias propias, sin nube, sin avisos y sin Gemini (`SAVERS/App/Scenario.swift`, solo en Debug).
Nunca hace falta marcar, escribir ni desmarcar en los datos reales del usuario.

## Ver cómo se ve: una sola imagen

```bash
swift/tools/probar.sh hoja                      # compila y captura los 7 escenarios (~50 s)
swift/tools/probar.sh hoja hechas abiertas:2    # solo esos; ":2" baja y captura una segunda pantalla
swift/tools/probar.sh hoja manana --sin-build   # sin compilar (si no cambió el código)
```

Imprime la ruta de `hoja.png`; léela con Read. Es una imagen para todo, en vez de una captura por paso.
Escenarios: `manana` (nada marcado, Silencio en Ahora), `abiertas` (Afirmaciones, Visualización y Escritura
abiertas con texto), `hechas` (mañana completa, bloque "hechas" abierto con una letra abierta), `dia-completo`,
`shabbat`, `sin-savers`, `historial`.

## Probar una interacción: texto, no imágenes

```bash
swift/tools/probar.sh abrir abiertas            # compila y deja la app en ese escenario
swift/tools/probar.sh ui                        # la pantalla como texto: tipo, 'etiqueta', marco en puntos
swift/tools/probar.sh tocar "Marcar Silencio"   # toca por etiqueta de accesibilidad
axe type 'hola' --udid "$(cat swift/.sim-id)"   # escribir en el campo que tiene el foco
swift/tools/probar.sh real                      # al terminar: vuelve a abrir la app con sus datos reales
```

- `ui` también sirve para **medir**: los marcos dicen dónde empieza cada cosa (p. ej. el círculo en x=26 con
  su zona de 44 pt → dibujo en 30 = 16 de pantalla + 14 de carta). No midas píxeles en capturas.
- `ui` lista también lo que está fuera de pantalla; para verlo en imagen usa `hoja escenario:2`.
- Los toques van con `--tap-style physical` (el toque por defecto de AXe no llega a los botones de SwiftUI).
- Si falta una etiqueta para tocar algo, agrégale `.accessibilityLabel` en el código: también ayuda a VoiceOver.

## Reglas

1. Capturas del panel del simulador (`mcp__Claude_Code_iOS_Simulator__control` screenshot) solo como último
   recurso: animaciones o algo que ni `hoja` ni `ui` muestran.
2. Nunca probar en los datos reales. Si el estado que necesitas no existe, agrega un caso a `Scenario`
   (y a la lista de arriba) en vez de armarlo a mano.
3. Termina con `probar.sh real` para que el simulador quede como lo dejó el usuario.
4. Al mostrarle al usuario el resultado, manda `hoja.png` (o un recorte) con SendUserFile.
