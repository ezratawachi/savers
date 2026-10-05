---
paths:
  - "swift/SAVERS/Sound/**"
  - "swift/SAVERS/Notices/**"
  - "swift/SAVERS/Timers/**"
  - "swift/SAVERS/Exercise/**"
---

# Sonido, voz y avisos

- La app pone el audio en `.ambient` al arrancar (`ToneEngine.mixFromLaunch()`); si no, la música del usuario se para
  hasta que suena algo propio.
- Todo el audio pasa por un solo `ToneBank`.
- Toda frase nueva que diga la app lleva un tono (`SpeechTone`). Si Gemini falla, suena la voz de Apple sin avisar;
  las palabras de la guía de Muévete no tienen ese respaldo (sin clip, no se dicen).
- `NoteDelegate` es `nonisolated` y aparte: iOS lo llama fuera del hilo principal.
- Avisos: pocos, nada en la mañana, nada de culpa. Un día sin pasos no tiene avisos.
