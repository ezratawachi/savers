# SAVERS — resumen para pasar a Swift

Este archivo reemplaza leer `index.html` (4.641 líneas, ~70 mil tokens) en cada sesión de la migración.
Dice **qué hace** la app y **con qué datos**; el *cómo* web (DOM, springs a mano, capas de navegación) no se copia:
en SwiftUI eso lo da el sistema. Cuando haga falta el detalle exacto de algo, el mapa del final dice qué líneas leer.

Escrito el 2026-09-29 sobre el commit `534756c`.

---

## 1. Qué es

App personal de la rutina matutina SAVERS (Miracle Morning) para un solo usuario, en español, iPhone 13 mini.
Tres pestañas: **Hoy** (guía del día), **Historial** (calendario y registros), **Ajustes**.

Las seis letras, en este orden fijo (`LETTERS`):

| key | letra | nombre |
|---|---|---|
| silencio | S | Silencio |
| afirmaciones | A | Afirmaciones |
| visualizacion | V | Visualización |
| ejercicio | E | Ejercicio |
| lectura | R | Lectura |
| escritura | S | Escritura |

Datos personales (nombre, afirmaciones, horario) nunca van en el código: llegan de la nube o de una copia importada.

---

## 2. Datos

**Regla dura:** el formato JSON de `settings` y de cada día debe quedar idéntico, porque la versión web
sigue usándose en la Mac y ambas escriben en el mismo Firestore.

### 2.1 Settings (`savers:settings`, y en la nube)

```jsonc
{
  "name": "Ezra",
  "affirmations": [{"label": "", "text": "..."}],          // al menos 1 (puede ir vacío)
  "visualization": {"items": [{"label": "Mi día", "text": "¿...?"}], "note": ""},
  "schedule": null | Schedule,
  "readApp": "libros" | "kindle" | "papel"
}
```

`normalizeSettings` (L684): acepta strings sueltos en listas (→ `{label:"", text}`), pone valores por defecto,
borra la nota vieja `OLD_VIS_NOTE`, migra el horario. Visualización por defecto: 3 preguntas
("Mi día" / "Mi obstáculo" / "Mi plan", ver L450).

### 2.2 Schedule

```jsonc
{
  "week": {"0": "off", "1": "normal", "2": "normal", "3": "gym", "4": "normal", "5": "gym"}, // 0=dom … 5=vie; sábado siempre Shabbat
  "gymTime": "5:15–6:00",        // define los minutos de Ejercicio en día de gym
  "gymReading": "...",           // texto opcional de cuándo leer en gym
  "types": {
    "normal": TypeSchedule,
    "gym": TypeSchedule
  },
  "table": {"headers": [], "rows": [[]]},   // legado: se muestra si no hay types
  "timelineNormal": [], "timelineGym": []   // legado
}
```

`TypeSchedule`:

```jsonc
{
  "night": [Step],   // "La noche anterior" (se muestra apagado)
  "steps": [Step],   // la mañana
  "later": [Step],   // "Más tarde"
  "minutes": {"silencio": 10, "lectura": 4},              // todos los días de ese tipo
  "minutesDays": {"lectura": {"jue": 10}}                  // solo un día de la semana
}
```

`Step`: `{id, title, short?, detail?, time: "5:20", times?: {"jue": "5:10"}, letters?: ["silencio", ...]}`.
Un bloque con `letters` contiene esas letras en ese orden. `id` es único; si falta se crea `tipo-grupo-índice`.

Horas como texto: `"5:20"` (mañana, sin am), `"10:10 pm"`, `"12:10 am"`. `parseTime` (L585) acepta
`h:mm` con `a`/`p` opcional → minutos del día. `timeLabel` hace lo inverso.

`migrateSchedule` (L604): esquema viejo con `types.x.days: "lun, mar"` → `week`; da ids; si un step tiene
`times` sin `time`, toma el primero como `time`; borra `times` iguales a `time`.

### 2.3 Un día (`savers:days` = `{ "AAAA-MM-DD": Day }`)

```jsonc
{
  "date": "2026-09-29",
  "checks": {"silencio": true, ...},
  "gratitude": "", "bookIdea": "", "notes": "",
  "extra": false,                 // SAVERS hechos en un día "Sin SAVERS"
  "updatedAt": "ISO",             // se pone en cada cambio; decide conflictos
  "type": "gym",                  // opcional: este día es otro tipo (solo si difiere de la semana)
  "times": {"<stepId>": "5:10"},  // opcional: hora solo para esta fecha
  "mins": {"lectura": 30}         // opcional: minutos solo para esta fecha
}
```

`dropOldFields` borra `priorities` y `prioDone` (campos viejos).
`hasContent(d)`: alguna letra marcada o algún texto escrito.

### 2.4 Solo en este aparato (nunca en copia ni nube)

| clave | qué |
|---|---|
| `savers:lastExport`, `savers:since` | fecha de la última copia / primer uso |
| `savers:affReviewed` | `"AAAA-MM"` del último mes revisado (arranca en el mes actual) |
| `savers:settingsAt`, `savers:settingsPushed` | ISO del último cambio de ajustes / el que ya subió |
| `savers:cloudUid`, `cloudLastUid`, `cloudPushed` (`{fecha: updatedAt}`), `cloudSeen` (ms), `cloudAt` | sincronización |
| `savers:timer`, `savers:timer:vis` | `{base, runStart, running, day}` de un temporizador en curso |
| `savers:reading` | `{day, start, min, notify, sent}` lectura en curso |
| `savers:geminiKey`, `voice`, `voiceNext`, `voiceHold` | voz (la clave va al Keychain en nativo) |
| `savers:keepMusic` (default true), `savers:avisos` (`{id: bool}`), `savers:planned` (ids agendados) | preferencias |

---

## 3. Reglas del dominio

**Tipo de día** (`dayType`, L545): sábado = `shabbat` siempre. Si no, `day.type` si existe, o `week[w]`, o
`DEFAULT_WEEK` (`dom off, lun normal, mar normal, mié gym, jue normal, vie gym`).
`isScheduled` = normal o gym. Nombres: `Normal / Gym / Sin SAVERS`; chip: `Día normal / Día de gym / Sin SAVERS / Shabbat`.
`schedTypeOf` = "gym" si es gym, si no "normal" (un día off con SAVERS usa el horario normal).

**Hora de un step** (`stepTime`, L551), de más a menos específica: `day.times[id]` → `step.times[díaSemana]`
(las claves se comparan sin acentos, 3 letras) → `step.time`.

**Minutos de Silencio y Lectura** (`minutesOn`/`usualMinutes`, L572): `day.mins[k]` → `minutesDays[k][díaSemana]`
→ `minutes[k]` → por defecto `silencio 10, lectura 4`. Válido: entero 1–240.
Opciones del selector: 1…60, 75, 90, 105, 120.

**Minutos de las demás letras** (`letterMinutes`, L779): Afirmaciones = ceil(n·25 s / 60), mínimo 1;
Visualización = n preguntas (1 min cada una), mínimo 1; Ejercicio = 8 (casa) o los minutos de `gymTime` (gym);
Escritura = 2.

**Bloques del día** (`dayBlocks`, L1853): cada step de `steps` con letras es un bloque con cabecera
`[hora, short||title]`; cada `later` es bloque `["Más tarde", hora]`. Una letra aparece una sola vez (la primera).
Las letras que ningún bloque pone van a un bloque sin cabecera antes de "Más tarde" (sin horario: las 6 ahí).

**"Ahora"** (`nextKey`, L1871): la primera letra sin marcar en el orden de los bloques. **Decide el progreso, nunca el reloj.**

**Final** (`finishState`, L1879): `"day"` con 6/6; `"morning"` (solo hoy) si hay bloques "Más tarde" y todos los
de la mañana están hechos; si no `""`.

**Racha** (`streak`, L1745): cuenta hacia atrás los días con SAVERS completos; los días sin SAVERS no la cortan.
Si hoy toca y no está completo, empieza desde ayer.

**Sol de la carta Ahora** (`sunPlan`/`updateSun`, L1928): solo hoy y en día con SAVERS. Inicio de la letra =
hora del bloque + minutos de las letras anteriores del bloque; largo = sus minutos. Se actualiza cada 1 s.
Muestra `p` (avance 0–1), zona ámbar = último minuto, etiqueta `"N min"` (ceil de lo que falta).
Pasado el tiempo espera al final y dice `"Sigue <siguiente>"` (siguiente letra sin marcar de la mañana, o el
siguiente step del horario sin letras abiertas, p. ej. "Baño"). Nunca parpadea, suena ni se pone rojo.

**Revisión mensual** (`affReviewDue`): el mes actual ≠ `affReviewed`.

**Copia atrasada** (`backupOverdue`): sin nube y más de 14 días desde la última copia (o desde el primer uso).

---

## 4. Hoy

### Cabecera
- Saludo por hora: `<12 Buenos días`, `<19 Buenas tardes`, si no `Buenas noches` + `", <nombre>"`.
- Fecha grande `"Martes 29 sept"` (`headDate`). A la derecha, chip del tipo de día → abre la **hoja del día** (§8).
  En Shabbat el chip no es botón.
- Sin datos personales y sin nube: aviso con **Entrar** (Google) e **Importar**.

### Según el día
- **Shabbat**: carta "Shabbat Shalom" + "Hoy no hay registro. Nos vemos el domingo."
- **Sin SAVERS** (y sin `extra`, sin contenido y sin haber tocado el botón): carta "Sin SAVERS" +
  "Hoy no toca SAVERS. Si quieres, puedes hacerlos igual y quedan registrados." + botón **Hacer mis SAVERS hoy**
  (pone `extra = true`).
- **Rutina**:
  - Las 6 letras grandes como palabra (no son botones): hechas en terracota, pendientes apagadas.
  - `Racha: N días` (se oculta con el día completo) + `Ver horario ›` (abre la hoja del día).
  - Lista por bloques con cabecera `**5:20** · SAVERS`.
  - Carta por letra: círculo (letra o ✓), nombre + etiqueta **Ahora**, subtítulo, minutos a la derecha, flecha si abre.

### Contenido de cada carta (`letterInfo`, L1788)

| letra | subtítulo | abre | dentro |
|---|---|---|---|
| Silencio | Daily Calm | no | — |
| Afirmaciones | En voz alta / *Toca revisarlas* (revisión pendiente) | sí | las frases; nota "Despacio, sintiendo cada frase." o "Mes nuevo: ¿siguen sintiéndose tuyas?" + **Revisar afirmaciones**; vacío: **Agregar afirmaciones** |
| Visualización | Ojos cerrados, guiada | sí | temporizador guiado + lista de preguntas + nota; vacío: **Agregar preguntas** |
| Ejercicio (casa) | Rutina en casa · 8 min | sí | temporizador con dibujo y mapa (§5) |
| Ejercicio (gym) | Gym con tu entrenador · minutos de gymTime | no | — |
| Lectura (normal) | Con tu café | sí | temporizador de lectura + "N minutos con tu café. La meta es el tiempo, no las páginas." |
| Lectura (gym) | Tu libro | sí | "Hoy lees más tarde, a las H. Empieza desde aquí y se marca sola." + temporizador |
| Escritura | Agradecer y anotar · 2 min | sí | 3 campos + botón **Listo** que marca |

Campos de Escritura (`W_FIELDS`): **Agradezco** (algo concreto de ayer y por qué), **Del libro** (una idea de lo
que leíste hoy / *ayer* en gym), **Notas** (opcional). Guardan mientras escribes (400 ms); lleno y sin foco se ve
como texto con "✓ Guardado"; vacío o editando = 3 renglones. Al salir de un campo de una carta ya hecha, la carta se cierra.

### Movimiento al marcar (ver memoria "Movimiento de Hoy")
1. Tocar el círculo: vibración + sonido "check doble" (o el arpegio si llega a un final). Sin toast.
2. La carta se vuelve fila simple: se encoge (320 ms, curva `.22,1,.36,1`) y el círculo y el título se deslizan a su lugar.
3. 150 ms después, "Ahora" pasa a la siguiente: si tiene contenido se abre y se trae a la vista (solo si no estás tocando ni desplazando).
4. Al llegar a un final, 400 ms después: todo lo hecho se pliega en su lugar en una fila `Mañana · N hechas`
   (o `Todo el día`) y después crece la carta final: ✓ grande, **Mañana lista** + "Falta Lectura a las 8:50 pm" o
   **Día completo** + racha; si la copia está atrasada, recordatorio con **Exportar**.
5. Desmarcar a mitad de camino revierte desde donde está.

Al abrir la app todas las cartas están cerradas, incluida la de Ahora. Las abiertas se recuerdan mientras la app sigue abierta.
Un cambio que llega de la nube no redibuja mientras escribes, editas, corre un temporizador o hay una hoja abierta.

---

## 5. Temporizadores guiados

El tiempo sale del reloj (`base + (ahora − runStart)`), no de contar ticks: sobrevive a que iOS pause la app.
Solo uno corre a la vez. Se guarda en `savers:timer[:vis]`; al volver el mismo día se retoma; si pasaron más de
total+10 min se reinicia. Mantiene la pantalla encendida mientras corre.

Botones: **Empezar / Pausar / Seguir / Repetir**, **Siguiente** (salta al siguiente paso), **Reiniciar** (solo si empezó).
Al terminar marca la letra y muestra toast. Ya hecho y parado: "Hecho" / "Si quieres, puedes repetirlo."

### Ejercicio en casa (8 min = 480 s)
Pasos (`buildSteps`, L480): Marchar en el sitio 60 s → 2 rondas de
[Bird dog, Dead bug, Puente de glúteos, Sentadilla a silla] de 40 s con "Cambio" de 5 s entre cada uno
(no después del último) → Respiraciones con piernas en la silla 65 s.

Pantalla: título del momento ("Listo para empezar" / nombre del paso / "Cambia de ejercicio"), dibujo animado,
reloj del paso, y un **mapa** de 6 partes (Marcha, Bird dog, Dead bug, Puente, Sentadilla, Respira) con anchos
proporcionales 37/43/48/35/52/39; hecho terracota, actual azul; el Cambio cuenta como la parte siguiente.

Voz (`exCue`/`exCueFull`): "Marchar en el sitio, un minuto." · "Sigue: dead bug." · "Ronda dos: bird dog." ·
"Último: piernas en la silla, respira lento." La versión larga agrega el consejo del paso
(`EX_TIP`, p. ej. "Espalda baja pegada al piso."); solo se usa si ya existe su audio de Gemini.
Cuándo: al empezar dice la marcha; en un Cambio y en el último paso, 700 ms después de entrar; en la marcha,
con 6 s restantes anuncia el primer ejercicio; en pasos sin guía suenan pitidos (660 Hz) en los últimos 3 s.
Final: pitidos 988 → 1318 Hz y "Listo. Ejercicio marcado."; toast "Ejercicio terminado y marcado".

### Guía por movimiento (`GUIDE`, L2364)
Cada ejercicio repite sus fases hasta llenar el paso; las repeticiones se estiran un poco para terminar justo.

| ejercicio | lados | fases (tipo, s, palabra) |
|---|---|---|
| birddog | sí | up 2 Estira · hold 3 Sostén · down 2 Vuelve |
| deadbug | sí | down 3 Baja despacio · up 2 Vuelve |
| puente | no | up 2 Sube · hold 2 Sostén · down 2 Baja |
| sentadilla | no | down 3 Baja · hold 0.5 Toca · up 2 Sube |
| descanso | no | (espera 5 s) up 4 Inhala · down 6 Exhala, tono calmado |

- Repeticiones: `n = round(tramo / ciclo)`; con lados, número par (mínimo 2), y en las impares la primera palabra es "Otro lado".
- Palabras: solo en la ronda 1 (y la respiración), las 2 primeras repeticiones, y solo con voz de Gemini.
- Sonidos: **glide** (sube o baja una quinta, G4 392 ↔ D5 587.3 Hz, seno + octava al 18 %, nivel 0.2 o 0.09 bajo una palabra);
  **hold** = un tic de madera por segundo (triángulo 1050→800 Hz, 70 ms); al final de cada ejercicio una **campana suave**
  (FM, E5 659.3 y 0.22 s después B5 987.8). Todo pasa por un compresor (−6 dB, ratio 12).
- Se agendan 0.6 s adelante en el reloj de audio; lo que pasó mientras la app dormía se descarta, no suena de golpe.

### Dibujos (`EX_FIGS`, L2515–2830)
Un pictograma articulado por ejercicio (marcha, birddog, deadbug, puente, sentadilla, descanso) con cinemática
directa e inversa (`fpt`, `fik`), piso, silla y trazos punteados del recorrido. Azul = lo que se mueve; el lado
lejano va más claro; el cercano con un borde del color de la carta. El dibujo sigue el mismo reloj que los sonidos
(la fase muestra su palabra: "Estira", "Sostén"…). En el Cambio muestra la pose inicial del siguiente con "Prepárate".
La marcha se repite sola. Con "Reducir movimiento": pose fija "Así se hace".
**En Swift:** portar la geometría tal cual a `Canvas` + `TimelineView`; las curvas GSAP son todas `sine.inOut`.

### Visualización
Un paso de 60 s por pregunta. Al entrar: pitido (inicio) o campana, y la voz lee la pregunta (tono calmado).
Con 10 s restantes, un tono suave. Final: campana + "Visualización lista." → marca; toast "Visualización lista y marcada".
Textos: "Cierra los ojos y escucha" / "La voz te lee cada pregunta y te da un minuto." / "Pregunta 2 de 3" + la pregunta.

### Lectura (L3080)
**Empezar lectura** guarda `{day, start, min}`, agenda el aviso "Lectura terminada" ("Leíste N minutos. Se marca
sola al volver a SAVERS.") y abre la app de lectura (`ibooks://`, `kindle://`, o nada si es papel).
Muestra "Leyendo · Faltan m:ss", **Ya terminé**, **Cancelar** (cancela el aviso). Al volver con el tiempo cumplido
se marca sola. Los minutos quedan fijos al empezar.
*Web:* sin avisos usa el atajo "Lectura SAVERS" de Atajos. **En nativo no hace falta:** siempre hay avisos locales.

---

## 6. Sonidos de la interfaz (`tone`, L1237)
Seno con ataque exponencial de 8 ms y caída exponencial.
- Marcar: 988 Hz 0.10 s + 1319 Hz 0.14 s a los 70 ms (pico 0.12).
- Completar: 659, 831, 988, 1319 cada 85 ms (0.14 s), 1661 a 0.34 s, 1976 (0.75 s) a 0.42 s + 3952 muy suave.
- Campana: 1175 Hz 1.1 s + 3243 Hz 0.3 s. Tono suave: 660 Hz 0.35 s. Pitido: pico 0.16.
- Aviso push: `campana.caf` (ya está en el proyecto iOS).

"Mantener mi música" (por defecto sí): los temporizadores suenan mezclados con tu música, pero la voz respeta
el modo silencio. Apagado: la voz pausa la música y suena siempre.
**En nativo** se puede además bajar la música mientras habla (`.duckOthers`), cosa que WebKit no podía.

---

## 7. Historial

- Título "Historial". Calendario de un mes que se desliza con el dedo entre meses (anterior / siguiente) y botones ‹ ›.
  Hacia atrás sin límite; hacia adelante hasta 12 meses.
- Cabecera "Septiembre de 2026" + "X de Y mañanas completas" / "Por venir" / "Sin mañanas todavía".
- Semana empieza en domingo (D L M M J V S). Cada día es un anillo que se llena con n/6 en terracota; 6/6 = relleno.
  Shabbat y días sin SAVERS sin contenido: sin anillo (Shabbat no se puede tocar). Futuro: 40 % de opacidad.
  Hoy: borde azul. Día futuro cambiado para sí mismo: punto azul.
- Leyenda: "El anillo se llena con cada letra. Toca un día para ver su registro o preparar uno que viene."
- "Registros del mes": los días con contenido, del más nuevo al más viejo, con "N de 6" y lo escrito.
  Vacío: "Todavía no hay registros este mes. Marca tu primera letra en Hoy." / mes futuro: "Este mes todavía no llega…".
- **Día abierto** (empuja desde la derecha, vuelve desde el borde): fecha larga, chip + "· N de 6". Es un registro:
  solo Escritura se abre, las letras se pueden marcar o desmarcar. Día futuro: solo el editor del día (§8).
  Shabbat: "Shabbat no tiene registro." Sin SAVERS: **Registrar mis SAVERS**.
- La pestaña siempre abre en el mes actual.

---

## 8. Horario

### Hoja del día (chip o "Ver horario")
Hoja alta, título "Hoy" o la fecha, botón **Listo**. Selector de 3: Normal / Gym / Sin SAVERS; debajo del tipo
habitual de ese día de la semana dice "los martes". Sin SAVERS: "Este día no hay SAVERS y no cuenta para tu racha."
Si no: la línea de tiempo del día (grupos "La noche anterior" (apagada), la mañana, "Más tarde"; el bloque SAVERS
con punto azul) y "Minutos" de Silencio y Lectura. Desde hoy en adelante cada hora y minuto es editable y lo
cambiado se ve en azul. "Lo que cambies aquí es solo para este día." + **Volver a lo de siempre**.
Solo se guarda lo que difiere de lo habitual (así un cambio posterior del horario sigue llegando a esa fecha).

### Ajustes › Horario
- **Días**: domingo a viernes con selector de tipo; "Sábado · Shabbat" fijo.
  Nota: "Para un solo día, como un feriado o un gym cancelado, tócalo en Hoy o en Historial."
- **Horas**: selector Normal | Gym (con sus días). Por grupo, cada step: título + resumen `"5:20 · jue 5:10"`.
  Debajo, sus letras con la hora en que empieza cada una y sus minutos; Silencio y Lectura abren su hoja de minutos.
- Aviso en rojo si las letras de un bloque pasan la hora del siguiente: "Lectura termina 6:12, pasa las 6:10 de Baño"
  (con los días a los que aplica).
- **Hoja de una hora**: selector Todos | cada día del tipo; rueda de hora grande. "Todos" borra las horas propias
  por día. En un día: "Solo los jueves." + **Usar la misma hora que los demás**.
- **Hoja de minutos**: igual, con la rueda de minutos.

---

## 9. Ajustes

Lista:
1. **Tu nombre** (campo en la fila, "Para el saludo").
2. **Horario** (N días) · **Afirmaciones** (N frases / Vacío) · **Visualización** (N preguntas / Vacío) · **Leer en** (Libros / Kindle / Libro físico).
3. **Notificaciones** (Activadas / Apagadas) · **Voz** (nombre de la voz / Del iPhone) · **Mantener mi música** (interruptor) + nota.
4. **Copia de seguridad** ("En la nube" o Nunca / Hoy / Ayer / Hace N días, en rojo si está atrasada).
5. Pie: "Tus registros se guardan en este aparato y en la nube." / "…viven solo en este aparato."

Pantallas (empujan desde la derecha, volver desde el borde):
- **Afirmaciones / Visualización**: lectura con **Editar**. Editando: **Cancelar** / **Listo**; cada ítem con título
  opcional + texto, ↑ ↓ **Borrar** (no se puede borrar el último), **＋ Agregar**. Visualización tiene además una nota.
  Al guardar se quitan los vacíos (queda al menos uno vacío). Cambiar de pestaña con cambios sin guardar pregunta:
  **Descartar / Guardar / Seguir editando**.
  **Listo** en Afirmaciones cuenta como la revisión del mes aunque no cambie nada.
- **Revisión del mes** (desde Hoy o desde el aviso): Afirmaciones ya editando → **Siguiente** → Visualización → **Listo**
  → toast "Revisión del mes lista". Cancelar la termina ahí. Entrando desde Hoy, el botón de volver dice "Hoy" y
  regresa al mismo punto.
- **Notificaciones**, **Voz**, **Horario**: cambian al tocar, sin Editar (como Configuración de iOS).
- **Copia de seguridad**: sección Nube (§10) + "Copia en archivo": última copia, **Exportar copia**, **Importar copia**.

---

## 10. Nube (Firebase, proyecto `savers-ezra`)

- Cuenta Google; las reglas de Firestore solo dejan entrar al dueño.
- Rutas: `users/{uid}/meta/settings` = `{settings, updatedAt: ISO string, syncedAt: serverTimestamp}` y
  `users/{uid}/days/{AAAA-MM-DD}` = `{day, syncedAt: serverTimestamp}`.
- Lo local manda: la app nunca espera a la red. Cada guardado sube lo que cambió.
- Bajada en vivo: ajustes, y los días con `syncedAt > cloudSeen` (solo lo nuevo, no todo el historial).
- **Primera vez en un aparato**: lo de la nube gana sobre los ajustes locales; se ignoran respuestas de la caché.
- **Conflictos**: gana el `updatedAt` más nuevo. Un día que llega con el mismo `updatedAt` no cambia nada; uno más
  viejo no pisa un día local con contenido. Ajustes: se aplican si su `updatedAt` > `settingsAt` local.
- Subida: días cuyo `updatedAt` ≠ `cloudPushed[fecha]`; ajustes si `settingsPushed` ≠ `settingsAt`.
- `permission-denied` → cierra sesión: "Esta cuenta de Google no tiene acceso a esta app."
- Estado: "Conectando…", "Subiendo…", "Sin conexión · se sube después", "Guardado · hace 5 min".
  Cerrar sesión pregunta antes; los datos quedan en el aparato.
- Login nativo ya resuelto en `app/ios/App/App/GoogleLogin.swift`: `ASWebAuthenticationSession` + PKCE → idToken y
  accessToken → credencial de Firebase.

---

## 11. Copia en archivo

Exportar (`backupJSON`, L879): `savers-copia-AAAA-MM-DD.json` con
`{app: "savers", version: 2, exportedAt, paraLaIA: SUMMARY_NOTE, resumen: weekSummary(), settings, days}`.
`resumen` describe la rutina día por día (letra, bloque, hora, minutos) para que una IA la lea; al importar no se usa.

Importar (`importBackupText`, L919): debe tener `app === "savers"`. Solo reemplaza las partes de settings que trae
el archivo (nombre, afirmaciones, visualización, horario); los días se agregan y, si ya existen, queda el más
reciente por `updatedAt`. Pregunta antes con un resumen ("Se reemplaza solo tu horario. Se agregan 12 días…").
Si el `resumen` del archivo dice horas o minutos distintos de los que salen del horario, avisa que eso no se guarda.

---

## 12. Voz (L1274–1581)

- **Gemini TTS** si hay clave y el audio de esa frase ya existe; si no, la voz del iPhone (español, prefiere
  Premium/Mejorada y es-MX, velocidad 0.92 en web), **sin avisar**.
- Modelo `gemini-3.8-flash-tts`, `POST https://generativelanguage.googleapis.com/v1beta/interactions`, header
  `x-goog-api-key`. Cuerpo y respuesta exactos: L1403. Llega PCM 16-bit 24 kHz mono (o WAV) → se guarda como WAV.
- Voces: Sulafat (mujer, cálida, por defecto), Vindemiatrix (mujer, suave), Achird (hombre, amable), Algieba (hombre, sereno).
- Tonos: `visualizacion` (calmado, lento), `ejercicio` (enérgico), `aviso` (neutro). Todos con acento mexicano.
- Caché: una entrada por `voz|tono|texto`, nombre = SHA-256 de `modelo|clave` (16 bytes en hex). Se generan todas
  las frases que la app puede decir hoy (`spokenPhrases`, L1366: frases del ejercicio, palabras de la guía, preguntas
  de visualización, avisos). Se borran las que ya nada dice.
- Una voz nueva solo reemplaza a la actual cuando tiene todas sus frases (una rutina nunca mezcla dos voces).
- Cuota: un 429 por minuto espera y reintenta; uno diario (o 3 seguidos) espera hasta la medianoche del Pacífico.
- Ajustes › Voz: lista de voces con ✓ y **Probar** (lee la primera pregunta de visualización), campo **Clave**, estado
  ("Las N frases están listas en este iPhone.", "Achird se está preparando: 12 de N frases…", errores en palabras simples).
- La clave nunca va a la copia, la nube ni el repo. **En nativo: Keychain.**

---

## 13. Avisos (notificaciones locales)

En la app ya son locales (`Avisos.swift`: `UNUserNotificationCenter`, sonido `campana.caf`, se muestran también
con la app abierta). El Worker de Cloudflare y el push web solo existen para la PWA.

| id | nombre | por defecto | qué |
|---|---|---|---|
| lectura | Fin de la lectura | apagado | al terminar los minutos de lectura |
| leer | Hora de leer | encendido | días con Lectura en "Más tarde" (gym), si no está marcada: "Tus N minutos de lectura de hoy." |
| dormir | Prepararte para dormir | encendido | 45 min antes del step de la noche que dice "dorm" (o el último), la noche anterior a un día con SAVERS: "Dormido a las 10:15 pm. Mañana es gym: te paras a las 4:45." |
| revision | Revisión del mes | encendido | primer domingo del mes a las 11:00 am, si hay afirmaciones o preguntas y el mes no está revisado |

- Se planean los próximos 14 días en cada apertura y cada cambio (1.5 s de espera); se cancelan los que ya no van
  (`savers:planned`). Ids: `dormir-AAAA-MM-DD`, `leer-AAAA-MM-DD`, `revision`.
- **Shabbat**: nada desde el viernes a las 15:00 hasta el fin del sábado. Nada en la mañana.
- Al tocar un aviso: `revision` → revisión del mes; `leer-…` → Hoy con Lectura abierta; otro → Hoy (salvo que estés editando).
- Permiso: se pide al encender el primer interruptor. Bloqueado: "Los avisos están bloqueados. Actívalos en
  Configuración › Notificaciones › SAVERS." Botón **Mandar un aviso de prueba**.

---

## 14. Diseño

Paleta **Amanecer** (del ícono): terracota = solo "hecho"; azul cielo = "Ahora" y enlaces; ámbar = solo el sol.

| token | claro | oscuro |
|---|---|---|
| bg | #F3F2EE | #10151F |
| surface | #FFFFFF | #1B2538 |
| surface-2 | #ECEAE4 | #263149 |
| ink | #1B2538 | #E6E9F0 |
| muted | #5E6677 | #9AA3B5 |
| line | #E0DDD6 | #3A4660 |
| dawn (hecho) | #E27D60 | #E27D60 |
| dawn-soft (carta final) | #F9E4DC | #1B2538 |
| sky (Ahora) | #3B5A8C | #9DB4DB |
| ok / warn | #2F7D5B / #B42318 | #5DC093 / #FF8A7A |
| sun / trail / zone / ink | #D4900F / #E9C67A / #F2D9A0 / #8F5E07 | #F2B544 / 50 % / 28 % / #F2C46B |
| floor / chair (dibujos) | #E4E0D8 / #CFC8BB | #2E3A54 / #4A5673 |

- Tipografías: **Bricolage Grotesque** 700/800 para títulos y números; **Atkinson Hyperlegible** 400/700 para texto (17 pt).
  Números tabulares en relojes.
- Cartas: radio 16, borde de 1 px, sombra mínima en claro. Hecha = fila sin caja, título al 50 %.
- Movimiento: resortes críticamente amortiguados (respuesta 0.36 s, sin rebote); alturas 320 ms `.22,1,.36,1`;
  todo interrumpible; "Reducir movimiento" = sin animación. Pulsar escala 0.94–0.97.
- Criterio: ver `.agents/skills/apple-design` y las memorias "Movimiento de Hoy" e "Historial y Ajustes".

---

## 15. Qué cambia en nativo

**Se tira** (lo da SwiftUI): `Spring`, `Tracker`, `rubberband`, capas de navegación, hojas arrastrables hechas a mano,
`details` animados, `reveal`, `swallowUntil`, el truco del `<input switch>` para vibrar, `unlockSpeech`,
wake lock, service worker, push web, el atajo de lectura, GSAP, los `render*` con HTML.

**Se gana**: `UIImpactFeedbackGenerator` directo; `AVAudioSession` con `.duckOthers`; `AVAudioEngine` para la guía
con tiempo exacto; avisos locales siempre; `isIdleTimerDisabled` mientras corre un temporizador; Keychain para la clave.

**Restricciones**:
- Se firma con Apple ID gratis y se renueva cada 7 días (`app/renovar.sh`): **no hay CloudKit, push ni App Groups**.
  Por eso la nube sigue siendo Firestore.
- La web sigue viva para la Mac: mismo formato de datos, mismas rutas de Firestore.

**Para decidir en su momento** (no ahora):
- Firestore con el SDK oficial (Swift Package) o por REST.
- Persistencia local: archivos JSON (lo más parecido a hoy) o SwiftData con conversión a este JSON.

---

## 16. Mapa de `index.html`

| líneas | sección |
|---|---|
| 22–53 | paleta clara y oscura |
| 54–419 | resto del CSS (tamaños, márgenes) |
| 441–508 | constantes: letras, visualización por defecto, pasos del ejercicio, consejos |
| 510–650 | fechas, tipos de día, horas, minutos, `migrateSchedule` |
| 655–760 | estado, `normalizeSettings`, guardado local |
| 762–875 | hojas y preguntas (`ask`) |
| 877–964 | copia: exportar / importar |
| 966–1217 | nube |
| 1219–1318 | sonidos y voz del iPhone |
| 1320–1581 | voz de Gemini |
| 1582–1742 | movimiento, resortes, gestos (web) |
| 1744–1757 | racha |
| 1759–1846 | `letterInfo` (textos de cada carta) |
| 1848–1920 | bloques del día, Ahora, final |
| 1922–1981 | sol |
| 1983–2328 | Escritura, `renderDay`, marcar letras, plegado final |
| 2330–2513 | temporizadores, frases del ejercicio, guía y sus sonidos |
| 2515–2830 | dibujos de los ejercicios |
| 2832–3078 | motor de temporizadores y su interfaz |
| 3080–3180 | lectura |
| 3182–3381 | avisos |
| 3383–3543 | navegación dentro de una pestaña (web) |
| 3545–3729 | Historial |
| 3731–4225 | Horario: hoja del día, página, hojas de hora y minutos, `weekSummary` |
| 4227–4521 | Ajustes |
| 4523–4636 | pestañas, cambio de día, arranque, avisos tocados |

Proyecto iOS actual: `app/ios/App/App/` (`Avisos.swift`, `GoogleLogin.swift`, `campana.caf`, íconos). Worker: `avisos/worker.js`.
