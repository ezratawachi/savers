# SAVERS

- La app del iPhone es Swift, en `swift/`. La web (`index.html`, GitHub Pages) se bajó el 2026-10-05; queda en el
  historial de git.
- Para ver o probar cualquier cambio en `swift/`, usa el skill `/probar` (`swift/tools/probar.sh`): escenarios con
  datos inventados, una sola imagen para ver, texto de accesibilidad para tocar. Capturas del panel del simulador
  solo como último recurso, y nunca probar sobre los datos reales.
- Al escribir o revisar código en `swift/`, carga `swiftui-pro`; si el cambio toca movimiento, gestos, hojas o
  tipografía, también `apple-design`.
- Textos de la app: en inglés en el código (`String(localized:)` o `Text("…")`) y su español en
  `swift/SAVERS/Resources/Localizable.xcstrings`. Tras compilar, `python3 swift/tools/traducciones.py` dice qué falta.
- Medidas de las cartas: `swift/SAVERS/Design/CardLayout.swift`. No uses números sueltos para márgenes o esquinas.
- Instalar en el iPhone: `app/renovar.sh ya`.
