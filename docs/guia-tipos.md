# Guía: tipos de día propios, en 3 sesiones

Grill del 2026-10-05. Gym y Shabbat tienen sentido para ti, pero no para alguien que descargue la app. El problema no
es que existan esos días, sino que la app los trae **ya armados con tu nombre y tus reglas** (el entrenador, leer en
la noche, el sábado bloqueado, el silencio desde el viernes). La solución: cada persona arma sus propios tipos de día,
y los tuyos pasan a ser dos tipos más.

## Cómo empezar cada sesión

Abre una conversación nueva y escribe solo:

> **Seguimos con los tipos**

Claude lee esta guía, ve cuál es la primera sesión sin marcar y la hace. Al terminar, la marca aquí con una nota de
qué quedó.

Reglas para todas las sesiones:

- **Cómo se prueba:** con `/probar` (escenarios con datos inventados), nunca con tus datos reales. Se instala con
  `app/renovar.sh ya`.
- **Tus datos no pierden nada.** Lo que la app deje de usar (`gymTime`, `gymReading`) queda guardado en `extras`,
  como ya pasa con los campos viejos.
- **Qué no se toca:** los ids que ya existen. `normal`, `gym` y `off` siguen siendo los ids de tus tipos, y los ids
  de los pasos (`gym-steps-1`…) no cambian, así que las horas cambiadas en fechas sueltas siguen funcionando.
- **Medidas:** las de `Design/CardLayout.swift`. **Textos:** en inglés en el código y su español en
  `Localizable.xcstrings` (`python3 swift/tools/traducciones.py`).
- **Skills:** `swiftui-pro` siempre, y `apple-design` para hojas, listas y gestos de Horario.

---

## Lo decidido

**Tipos de día**
- Una sola lista de tipos. Unos tienen Amanecer (tus Normal y Gym) y otros son de descanso (tus Descanso y Shabbat).
- Se pueden crear, duplicar, renombrar y borrar, sin límite. Al crear uno se elige "con Amanecer" o "descanso", o se
  duplica uno que ya existe.
- Los nombres son únicos (sin distinguir mayúsculas). "Normal" y "Descanso" siguen el idioma de la app hasta que los
  renombres.
- Siempre queda por lo menos un tipo con Amanecer. Cuando la app necesita uno por defecto (un día sin tipo, un
  descanso hecho igual), usa **el primero de la lista, que es el más antiguo**. La lista no se reordena a mano.
- **Borrar un tipo que algunos días usan:** la app avisa ("Miércoles y viernes usan Gym. Pasan a Normal.") y, al
  confirmar, esos días de la semana y las fechas futuras cambiadas a mano pasan al primer tipo.
- **El pasado nunca cambia.** Cambiar tu semana o borrar un tipo vale desde hoy. Los días que ya pasaron quedan como
  fueron: no se corta la racha ni aparecen fallados en Historial. Un tipo borrado se sigue recordando para la historia.
  (Hoy no es así: `Routine.weekType` calcula el pasado con la semana actual.)

**Un tipo de descanso**
- Solo tiene nombre, sin horas.
- No rompe la racha y siempre tiene "Hacerlo igual" (usa las horas del primer tipo).
- En Hoy, el título grande es su nombre ("Descanso", "Shabbat") y debajo dice "Sunling descansa hoy".
- Se abre en Historial como cualquier día.

**Pasos fuera del Amanecer**
- Cualquiera de los seis pasos puede ir en otro bloque del horario de un tipo ("Gym 5:15", "Leer 8:50 pm", "En el
  bus 7:30"). Nada se apaga: siguen siendo los seis.
- Su carta muestra el nombre y la hora de ese bloque, y sigue abriendo su guía. (En tu Gym, Muévete pasa de
  "45 min" sin abrir a "5:15" y abre la rutina de casa, que puedes marcar igual.)
- Un paso en un bloque más tarde que no esté marcado tiene su aviso de "es la hora" (hoy solo existe "Hora de leer").
- La pista de Escribe ("lo que leíste hoy/ayer") mira si Lee viene antes o después que Escribe ese día, no si es Gym.
- El bloque Amanecer queda marcado de forma explícita. Hoy `TypeSchedule.sunriseBlockID` lo adivina por ser el que
  tiene más pasos, y eso falla si mueves pasos.

**Shabbat**
- Pasa a ser tu tipo de descanso llamado "Shabbat", asignado al sábado. Sin reglas especiales:
  - sin silencio de avisos: no silenciaba nada, porque un día sin pasos casi no tiene avisos;
  - sin bloqueo: se puede cambiar un sábado puntual, tiene "Hacerlo igual" y se abre en Historial;
  - sin "Shabbat Shalom" ni "See you on Sunday".

**Lo que se ve**
- El encabezado de Hoy y el aviso de dormir muestran el nombre del tipo cuando no es el primero ("· Gym",
  "Mañana es Gym").
- Tu semana cuenta por tipo en vez de "2 at the gym".
- Ajustes › Notificaciones: "Sunday to Thursday" y "On gym days" se vuelven generales, y "Hora de leer" pasa a
  "Hora de un paso".
- Tu domingo dice "Descanso" en vez de "Día libre".

**Horario** (Ajustes › Horario, una sola página)
- **Tu semana:** los 7 días, cada uno con un menú para elegir su tipo.
- **Tipos de día:** la lista. Al tocar un tipo se abre su página: nombre, y si tiene Amanecer, sus bloques y horas,
  con crear bloques y mover pasos de uno a otro. Desde ahí se duplica o se borra. Al final, "Nuevo tipo".
- La hoja del día (Hoy e Historial) ofrece todos los tipos.

**Alguien nuevo**
- Bienvenida con una pantalla nueva entre "When do you wake up?" y "Notifications": **"¿Qué días?"**, con los 7 días
  marcados. Los que desmarque quedan como Descanso. Se necesita por lo menos uno marcado para continuar.
- Empieza con dos tipos: Normal y Descanso.

**La IA**
- El paquete explica los tipos por su nombre. Ya no dice "Normal, Gym or Rest" ni "Saturday is Shabbat".
- Al pegar, puede asignar tipos existentes a cualquier día (sábado incluido) y cambiar horas. No crea ni borra tipos
  en esta versión.

**La web**
- Se baja. Si quedara congelada, su `migrateSchedule` cambiaría los tipos que no conoce por la semana de siempre, y
  al guardar pisaría tus datos de la nube. Se apaga GitHub Pages (**confirmar contigo antes**) y `index.html` con sus
  archivos sale del repo. Queda en el historial de git. Se actualizan CLAUDE.md y la memoria.

**Fuera de este plan:** la semana y el calendario empiezan siempre en domingo (`Weekday`, `MonthGrid`). Para
alguien de España empezarían en lunes. Es otro tema.

---

## Las sesiones

- [ ] **1. El modelo.** Por fuera, tu app se ve igual salvo los cambios ya decididos.

  **Antes de tocar nada**
  - [ ] Pedirte un respaldo desde Ajustes. (Pedido; falta que confirmes antes de instalar.)
  - [x] Con `/probar`, guardar cómo se ven hoy un lunes, un miércoles (Gym), un sábado y un domingo, para comparar
    al final.

  **Los tipos**
  - [x] `Model/DayType.swift` deja de ser un enum fijo: un tipo tiene id, nombre opcional, si tiene Amanecer y su
    orden de creación. Tus `normal`, `gym`, `off` y `shabbat` se convierten con esos mismos ids, en ese orden.
  - [x] `Schedule.week` gana la clave `"6"` (el sábado deja de ser fijo). `DayType.defaultWeek` y el `w == 6` de
    `Domain/Routine.swift` se van.
  - [x] `Schedule.types` acepta cualquier id; `starter(wake:)` crea Normal y Descanso.

  **El pasado nunca cambia**
  - [x] Elegir y anotar aquí cómo: guardar el tipo en los días pasados afectados al cambiar la semana o al borrar,
    o guardar la semana con fecha de inicio. Un tipo borrado se sigue recordando para la historia.
    **Elegido: la semana con fecha.** `Schedule.pastWeeks` guarda cada semana anterior con `until` (el último día
    que valió); `Schedule.setWeek` la agrega al cambiar un día, y `Schedule.week(on:today:)` da la semana que valía
    en una fecha. Así no hay que escribir en cada día pasado (ni subir cientos de días a la nube). Un tipo borrado
    queda en `types` con `deleted: true`: no sale en las listas pero los días pasados lo siguen nombrando. Las
    fechas futuras cambiadas a un tipo borrado vuelven a su semana. El escenario `semana` (lunes pasado a Descanso
    hoy) lo prueba: los lunes de septiembre siguen contando.
  - [x] La racha (`Routine.streak`) y Historial (`MonthGrid`, `DayRecordView`) usan eso.

  **Lo que hoy pregunta "¿es Gym?" o "¿es Shabbat?"**
  - [x] Las cartas leen el bloque: `Today/LetterInfo.swift`, `Today/ReadingBody.swift`, el `ExerciseTimer` de
    `Today/TodayView.swift`, y `WritingField.hint` / `WritingBody` (orden de Lee y Escribe).
  - [x] `TypeSchedule.sunriseBlockID` pasa a ser explícito (también en `Schedule/DayEditor.swift`).
  - [x] Descanso: `TodayHeader` y `TodayView` (título = nombre del tipo, sin `.shabbat`), `RestCard`,
    `SunlingPose`, `DayRecordView`, `MonthGrid` (el sábado deja de estar desactivado).
  - [x] Avisos (`Notices/Notices.swift`): se va `shabbatQuiet`; el aviso de leer pasa a "Hora de un paso" para
    cualquier paso en un bloque más tarde; "Mañana es {nombre}". Textos de `NoticesSettings`.
  - [x] `Settings/WeekBand.swift`: cuenta por tipo.

  **Cierre**
  - [x] Actualizar los escenarios de `App/Scenario.swift` (`shabbat` sigue existiendo como escenario de tu sábado).
  - [x] Comparar con lo guardado al principio y repasar `/probar` mañana, hechas, sin-savers, shabbat e historial,
    en español e inglés.
  - [ ] Instalar en el iPhone.

  **Notas para la sesión 2**
  - La hoja del día usa `SegmentedChoice`: con 4 tipos (Normal, Gym, Descanso, Shabbat) cabe justo; con más hay
    que cambiarla por una lista o un menú.
  - Horario hoy solo tiene lo mínimo: un menú por cada uno de los 7 días con todos los tipos, y las horas de los
    tipos con Amanecer. Borrar un tipo: marcar `deleted`, pasar sus días con `setWeek` (guarda el pasado) y sus
    fechas futuras al primer tipo.
  - Cada tipo con Amanecer guarda su bloque Amanecer en `sunrise` (lo puso la migración). Al mover pasos, Lee o
    Muévete fuera de ese bloque se muestran con el nombre y la hora de su bloque (`Routine.placement`).

  *Tú pruebas:* tu miércoles (Gym con su bloque y su hora), tu sábado ("Shabbat", con "Hacerlo igual") y que tu
  racha y tu Historial sigan igual.

- [ ] **2. Horario.**
  - [ ] `Settings/ScheduleSettings.swift`: secciones Tu semana (menú por día, los 7) y Tipos de día (lista +
    "Nuevo tipo").
  - [ ] La página de un tipo: nombre (único), y si tiene Amanecer, bloques con horas, crear bloques y mover pasos
    entre ellos. Duplicar y borrar, con el aviso de qué días cambian y la regla de que quede uno con Amanecer.
  - [ ] Las hojas de horas (`Schedule/UsualSheets.swift`) y la hoja del día (`Schedule/DaySheet.swift`,
    `DayEditor.swift`) con todos los tipos.
  - [ ] Probar: crear, renombrar, duplicar Normal como "Gym 2", mover Escribe a un bloque de la noche, borrar un tipo
    en uso (y ver que el pasado no cambia).

  *Tú pruebas:* duplicar un tipo, cambiarle una hora y asignarlo a un día.

- [ ] **3. El resto.**
  - [ ] Bienvenida (`App/WelcomeView.swift`): pantalla "¿Qué días?" entre la 2 y la 3, los 7 marcados, por lo menos
    uno; `AppStore.startFresh` recibe los días.
  - [ ] La IA: `Assistant/AIPacket.swift` (tipos por nombre, sin Shabbat), `AIProposal.swift` y `AIText.swift`
    (leer nombres de tipos en vez de normal/gym/rest; sin el guard del sábado).
  - [ ] La web: confirmar contigo antes de apagar GitHub Pages. Después sacar `index.html` y sus archivos del repo,
    y actualizar CLAUDE.md y la memoria (`savers-web-app`).
  - [ ] Probar `/probar nuevo` (bienvenida) y el paquete de la IA (`-paquete archivo`).

  *Tú pruebas:* la bienvenida con el modo desarrollador, y pegar un cambio de la IA que use "Shabbat" por nombre.
