---
paths:
  - "swift/SAVERS/Assistant/**"
---

# Hablar con una IA

- El paquete nunca lleva lo escrito (gratitud, ideas, notas).
- La IA solo puede cambiar lo que el usuario puede cambiar en Ajustes. Si algo nuevo se vuelve editable en Ajustes,
  agregarlo también al paquete, a `AIProposal` y a `AIWord` (las dos lenguas).
- Pegar usa `PasteButton`: un botón normal que lee `UIPasteboard` bloquea el hilo principal esperando el permiso.
- `aiWeek` y `aiDates` también los usa el hook de inicio de Claude (`privado/contexto/`): si cambian de firma, se
  recompila solo, pero revisar que siga funcionando.
