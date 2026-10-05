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
swift/tools/probar.sh hoja                      # compila y captura los 8 escenarios (~80 s)
swift/tools/probar.sh hoja hechas abiertas:2    # solo esos; ":2" baja y captura una segunda pantalla
swift/tools/probar.sh hoja manana --sin-build   # sin compilar (si no cambió el código)
swift/tools/probar.sh hoja --en                 # en inglés, con datos inventados en inglés
```

La app abre en español, como el iPhone; `--en` (en `hoja` y `abrir`) la abre en inglés. Después de compilar,
`python3 swift/tools/traducciones.py` dice qué texto del código no tiene español en
`SAVERS/Resources/Localizable.xcstrings` y cuál sobra. Ojo: `--sin-build` usa lo último instalado, no lo
último compilado a mano.

Imprime la ruta de `hoja.png`; léela con Read. Es una imagen para todo, en vez de una captura por paso.
Escenarios: `manana` (nada marcado, Silencio en Ahora), `abiertas` (Afirmaciones, Visualización y Escritura
abiertas con texto), `hechas` (mañana completa, bloque "hechas" abierto con una letra abierta), `dia-completo`,
`shabbat`, `sin-savers`, `historial`, `ajustes` (la pestaña Ajustes, para entrar a Horario o Notificaciones con `tocar`).
Fuera de la hoja de siempre: `nuevo` (instalación nueva: las 3 pantallas de inicio), `siete` (alguien nuevo en su
séptimo amanecer completo: "¿Quieres más tiempo?") y `semana` (el lunes pasó a Descanso hoy, abre en Historial:
los lunes pasados siguen contando).

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
- El simulador es iOS 26.5, como el iPhone (iOS 26). Con Xcode 27, `tocar` usa `--tap-style simulator` y
  `AXE_HID_STABILIZATION_MS=500`: sin esa espera AXe dice "completed successfully" y no toca nada (AXe #71).
  Si escribes `axe tap` a mano, usa lo mismo.
- Un menú desplegable (`Menu`, p. ej. "Leer en") **no se abre con AXe**. Ábrelo con
  `mcp__Claude_Code_iOS_Simulator__control` tap: sus coordenadas van en 360x780, no en los 375x812 de `ui`
  (multiplica x por 0.96 y y por 0.96). Lo de adentro del menú sí se toca con `tocar`.
- `ui` puede fallar con "No translation object returned" en los primeros minutos tras arrancar: espera y repite.
- `tocar` (y `axe tap` con `--tap-style simulator`) cae unos 4 % más abajo de lo pedido: cerca del borde de abajo
  puede tocar el botón de debajo. Ahí toca por coordenadas multiplicadas por 0.96 (x e y de `ui`).
- Si falta una etiqueta para tocar algo, agrégale `.accessibilityLabel` en el código: también ayuda a VoiceOver.
- Los interruptores (Toggle) no cambian con toques simulados, y un botón de fila de lista a veces solo
  responde si el toque cae en su parte de arriba (prueba y-10). No es un error de la app.
- El botón Pegar de iOS (PasteButton) no acepta toques simulados. Para probar "Hablar con una IA" con una
  respuesta de IA: `xcrun simctl launch "$(cat swift/.sim-id)" com.ezratawachi.savers -escenario ajustes -pegar /ruta/respuesta.txt`
  y entra a la página: se lee como si se hubiera pegado.
- Para leer lo que manda "Mandar a la IA" (la hoja de Compartir tampoco se abre con toques): lanza con
  `-paquete /ruta/paquete.md` y entra a "Hablar con una IA"; el texto queda en ese archivo.

## Reglas

1. Capturas del panel del simulador (`mcp__Claude_Code_iOS_Simulator__control` screenshot) solo como último
   recurso: animaciones o algo que ni `hoja` ni `ui` muestran.
2. Nunca probar en los datos reales. Si el estado que necesitas no existe, agrega un caso a `Scenario`
   (y a la lista de arriba) en vez de armarlo a mano.
3. Termina con `probar.sh real` para que el simulador quede como lo dejó el usuario.
4. Al mostrarle al usuario el resultado, manda `hoja.png` (o un recorte) con SendUserFile.
