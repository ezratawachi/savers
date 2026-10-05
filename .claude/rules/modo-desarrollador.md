---
paths:
  - "swift/SAVERS/App/**"
  - "swift/SAVERS/Settings/DeveloperSection.swift"
  - "swift/tools/**"
---

# Modo desarrollador y escenarios

- Modo desarrollador (solo Debug): instalación aparte (`savers-dev`, preferencias `savers.dev`), sin nube ni avisos.
  Todo lo nuevo que use estado global (Keychain, `UserDefaults.standard`, avisos) también se aísla ahí
  (`App/AppWorld.swift`, `App/DevMode.swift`).
- Escenarios de `/probar` (`App/Scenario.swift`): datos inventados en una carpeta temporal. Si falta un estado para
  probar algo, agregar un escenario; nunca probar sobre los datos reales.
