# Sunling

Esta página es la verdad de hoy sobre la app. Cómo se mantiene:

- Si algo de aquí cambia, se actualiza en el mismo commit y se avisa en una línea ("Actualicé CLAUDE.md: …").
- Si una memoria o un doc viejo dice otra cosa, gana esta página. Si el código dice otra cosa, avisar: o la página
  quedó vieja o el código tiene un error.
- Lo que un grill decide y todavía no se hace va a "En curso" antes de cerrar la sesión.
- Memorias: una por tema, en presente, con el porqué y lo descartado. Sin bitácoras ni hashes de commits.

## Qué es

Sunling es una app de iPhone para la mañana, con un método propio, el **Amanecer** (Sunrise): seis pasos que se
hacen cada mañana. Es primero del usuario, pero se construye con calidad de App Store por si algún día se publica.
Inglés base y español completo. Es una sola app, también la suya: no hay modo personal.

Los seis pasos, siempre los seis y en este orden: **Respira, Afirma, Imagina, Muévete, Lee, Escribe** (Breathe,
Affirm, Imagine, Move, Read, Write). Para enseñar, y nunca en Hoy, se agrupan en tres momentos: Calma, Rumbo, Crecer
(Still, Aim, Grow). El método viene de los SAVERS de Hal Elrod, que es una marca registrada: el crédito a Hal va solo
en Ajustes › El método, con "not affiliated". Detalle en `docs/metodo-sunling.md`.

Las tres pestañas:

- **Hoy** = qué hago ahora. Una guía de la mañana por bloques del horario. Arriba, una franja de noche con la palabra
  "Amanecer" de borde a borde, que se llena de ámbar con cada paso, y Sunling, que sube y abre los ojos. La carta
  **Ahora** es el primer paso sin marcar (por progreso, nunca por el reloj); dentro, un sol camina hacia los minutos
  que quedan. Al terminar: "Mañana lista" (falta lo de Más tarde) o "Día completo". Un día de descanso es casi todo
  noche con Sunling dormido.
- **Historial** = cómo me fue. El mes es el título; en la franja de noche, cada día es un solecito que asoma según
  los pasos hechos. Debajo, "Lo que escribiste". Tocar un día lo abre; también los días futuros, para prepararlos.
- **Ajustes** = cómo quiero mi semana. Arriba la franja "Tu semana" (abre Horario). Luego grupos: lo que dices y ves
  (Respira, Afirma, Imagina), ayuda (El método, Hablar con una IA), sonido y avisos, tus datos (respaldo en la nube)
  y, solo en Debug, Modo desarrollador.

## Palabras

| Se dice | No se dice | En el código sigue |
|---|---|---|
| Amanecer / Sunrise | SAVERS | carpeta `SAVERS`, claves `savers:`, bundle id, Firestore |
| paso | letra | `Letter`, `letters`, ids `silencio`, `afirmaciones`, `visualizacion`, `ejercicio`, `lectura`, `escritura` |
| bloque | | `Step` (un bloque del horario con su hora y sus pasos) |
| tipo de día | Normal / Gym fijos | `DayType`, ids `normal`, `gym`, `off`, `shabbat` |
| Descanso (tipo sin pasos) | Sin SAVERS, Día libre | id `off` |
| Ahora | Lo que toca | |
| Más tarde | | `later` (bloques después de la mañana) |
| Sunling | | la app y el pajarito, que es el sol |

## Cómo funciona el horario

- **Tipos de día propios**, sin límite: se crean, duplican, renombran y borran. Hay tipos con Amanecer y tipos de
  descanso. Siempre queda uno con Amanecer; el más antiguo es el de por defecto. Cada día de la semana tiene su tipo.
  La semana y el calendario empiezan en domingo.
- Cada tipo tiene **bloques** con hora; cualquier paso puede ir en cualquier bloque. La hora de cada paso = hora del
  bloque + minutos de los pasos anteriores. Si se pasan del bloque siguiente, ese bloque no se mueve.
- **Horas y minutos en 3 niveles**, gana el más específico: el tipo (todos sus días), un día de la semana, una fecha.
  Una fecha guarda solo lo que se tocó. Solo Respira y Lee tienen minutos editables (10 y 4 por defecto); los demás
  salen de su contenido.
- **Prepararte** (`schedule.windDown`): un número para todas las noches, minutos antes de Dormido (45 si falta).
- **Duración del Amanecer**: 10, 20 o 30 min (`SunriseLength`); a los 7 amaneceres sugiere más tiempo una vez.
- **El pasado nunca cambia** al cambiar la semana o borrar un tipo (`Schedule.pastWeeks`, semanas con fecha `until`).

## Reglas que no se rompen

- El pasado nunca cambia.
- Nada personal en el repo: es público. Lo personal va en `privado/` (ignorado) o en la nube.
- Lo normal no se anuncia; solo las excepciones. Una sola cosa fuerte arriba en Hoy: sin saludo ni chips.
- Colores: ámbar `#F2B544` = hecho (con check azul noche); azul cielo = Ahora. Azul noche `#1B2538` y suelo `#10151F`
  vienen del ícono. Sin rojo, sin parpadeos, sin culpa.
- Diseñar y revisar primero en modo claro (el usuario lo usa); después oscuro.
- Sunling: uno por pantalla, siempre sobre un horizonte, solo donde se ve un día entero (nunca en cartas ni celdas).
  No sonríe ni habla; solo cambian párpados y altura; resortes lentos sin rebote.
- Consistencia en toda la app: si algo se ve raro en un lugar, se arregla la regla en todas partes. Medidas de las
  cartas en `swift/SAVERS/Design/CardLayout.swift` (pantalla 16, interior 14, esquinas 16 cartas / 12 cajas); nunca
  números sueltos.
- Textos en inglés en el código (`String(localized:)` o `Text("…")`) y su español en
  `swift/SAVERS/Resources/Localizable.xcstrings`.
- Nunca probar con los datos reales: `/probar` usa escenarios con datos inventados.
- Avisos pocos y con propósito: nada en la mañana, nada de rachas ni culpa. Son cuatro: fin de la lectura, hora de un
  paso (si quedó para más tarde), prepararte para dormir, revisión del mes (Afirma e Imagina, primer domingo 11 am).

## Dónde vive cada cosa

- `swift/SAVERS/`: `Today`, `History`, `Settings`, `Schedule` (Horario y tipos), `Model` y `Domain` (datos y reglas),
  `Assistant` (Hablar con una IA), `Cloud` (Firebase), `Sound` (voz y tonos), `Exercise` (Muévete guiado),
  `Notices` (avisos), `Design` (piezas comunes, Sunling, franja de noche), `App` (arranque, bienvenida, escenarios,
  modo desarrollador).
- **Nube**: Firebase gratis (proyecto `savers-ezra`), entrada con Google; iPhone y Mac editan, gana el último cambio.
  Claude lee y escribe la nube con `python3 privado/nube.py` (mostrar el cambio antes de escribir).
- **Voz**: Gemini TTS con caché; si falla, la voz de Apple sin avisar. La clave solo en el iPhone (Keychain).
- **Hablar con una IA** (Ajustes): arma un paquete (`AIPacket`) con el horario y las notas para cualquier IA, y pega
  sus cambios con vista previa (`AIProposal`). Nunca manda lo escrito.
- **Modo desarrollador** (solo Debug): una instalación nueva aparte, sin nube ni avisos, hasta "Salir". Lo nuevo que
  use estado global (Keychain, `UserDefaults.standard`, avisos) también se aísla ahí.
- `privado/`: datos y scripts del usuario, fuera de git.

## En curso

- Nada abierto.

## Para después

- La IA no crea ni borra tipos de día.
- `avisos/` (Worker de Cloudflare) y `app/ios` (cascarón Capacitor) quedaron sin uso; `app/renovar.sh` sí se usa.
- Modo desarrollador: una guía a los ajustes tras llegar a Hoy (primero vivir el recorrido).
- Sol de Ahora: el número al tocar ("Vas 4 min tarde") y qué hacer cuando no llegas.
- Sunling: sonido al terminar.
- Hablar con una IA: Gemini dentro de la app; Claude dejando una propuesta en la nube.
- Antes de publicar: abogado de marcas (hay una marca "Sunling" en joyería).
- Plugin swift-lsp para Claude.

## Herramientas

- Para ver o probar cualquier cambio en `swift/`, usa el skill `/probar` (`swift/tools/probar.sh`): escenarios con
  datos inventados, una sola imagen para ver, texto de accesibilidad para tocar. Capturas del panel del simulador
  solo como último recurso.
- Al escribir o revisar código en `swift/`, carga `swiftui-pro`; si el cambio toca movimiento, gestos, hojas o
  tipografía, también `apple-design`.
- Tras compilar, `python3 swift/tools/traducciones.py` dice qué traducción falta.
- Instalar en el iPhone: `app/renovar.sh ya` (firma gratis de 7 días; launchd la renueva sola). Si falla con
  "No Accounts", revisar que Xcode tenga el Apple ID en Settings › Accounts.
- La web (`index.html`, GitHub Pages) se bajó el 2026-10-05; queda en el historial de git.
