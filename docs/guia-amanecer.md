# Guía: de SAVERS a Amanecer, en 3 sesiones

El porqué y todo lo decidido están en [metodo-sunling.md](metodo-sunling.md) (grill del 2026-10-02).

## Cómo empezar cada sesión

Abre una conversación nueva y escribe solo:

> **Seguimos con Amanecer**

Claude lee esta guía y el método, ve cuál es la primera sesión sin marcar y la hace. Al terminar, la marca aquí con
una nota de qué quedó.

Reglas para todas las sesiones:

- **Cómo se prueba:** con `/probar` (escenarios con datos inventados), nunca con tus datos reales. Se instala con
  `app/renovar.sh ya`.
- **Qué no se toca:** lo interno. Las claves `savers:`, las letras en el JSON (`silencio`, `afirmaciones`…), el
  bundle id y Firestore se quedan igual.
- **Medidas:** las de `Design/CardLayout.swift`. Nada de números sueltos.
- **Skills:** `swiftui-pro` siempre, y `apple-design` para la animación del título.

---

## Las sesiones

- [x] **1. El método dentro de la app** (en español; los textos pasan al archivo de traducciones en la 2).

  > **Hecha el 2026-10-02.** El título dice **AMANECER** en mayúsculas: así cada sexto de altura es un sexto de la
  > palabra (en minúsculas, las letras bajas se llenaban antes que la A). El tipo de día se llama **Descanso** y Tu
  > semana dice "5 amaneceres · 2 de gym" (los dos confirmados contigo). El subtítulo de Respira se escribe en
  > Ajustes › Respira (`breatheNote`), y la web de la Mac ya lo guarda. Tu bloque "SAVERS" pasa a "Amanecer" al
  > abrir la app y se guarda en la nube; el bloque se reconoce por tener más pasos. Los nombres de bloque "Lectura"
  > siguen igual, porque son tuyos. Algunos textos usan todavía "lectura" o "visualización" como sustantivos
  > ("Lectura terminada"); se revisan en la 2, al pasar al archivo de traducciones. Para probar el paquete de la IA
  > existe `-paquete archivo` (ver `/probar`).

  **El título**
  - [x] **"Amanecer" reemplaza a SAVERS** (`Today/HeroWord.swift`, antes `HeroLetters`). La palabra va de borde a borde y se llena de
    ámbar de abajo hacia arriba según los pasos hechos (`doneCount / 6`). El resto queda en `nightLetter`. Corte
    duro, sin degradado.
    - Animación: `Motion.sun`; con Reducir movimiento, fundido.
    - Accesibilidad: "Amanecer, 3 de 6".

  **Los pasos**
  - [x] **Nombres:** `Letter.name` pasa a Respira, Afirma, Imagina, Muévete, Lee y Escribe.
  - [x] **Iniciales del círculo:** pasan a R A I M L E. El círculo (`CheckCircle`) sigue mostrando la inicial;
    ahora ninguna se repite.
  - [x] **Subtítulo de Respira:** por defecto, "Medita, reza o solo respira". Cada persona puede escribir el suyo
    (el tuyo sería "Daily Calm").
    - Es un campo nuevo en ajustes, que se sincroniza.
    - Revisar que el `normalizeSettings` de la web de la Mac no lo borre.

  **Los textos**
  - [x] **Se cambian:**
    - "Hacer mis SAVERS hoy"
    - "Hoy no toca SAVERS" → "Sunling descansa hoy"
    - "N días seguidos" → "N amaneceres seguidos"
    - "Sin SAVERS"
    - "Registrar mis SAVERS"
    - "N días de SAVERS" (Tu semana)
    - el texto del editor del día
    - la frase de respaldo de la voz (`GeminiVoice`)
  - [x] **Textos a confirmar contigo al empezar:** el nombre del tipo de día "Sin SAVERS" (¿"Descanso"?) y la línea
    de Tu semana.

  **Tus datos y la IA**
  - [x] **Tu bloque "SAVERS":** en tu horario, el bloque se llama "SAVERS". Hay que cambiarlo una sola vez a
    "Amanecer". Además, `Schedule/DayEditor.swift` hoy lo encuentra buscando "savers" en el título; tiene que
    encontrarlo con una regla estable, como "el bloque que tiene pasos". Verificar que la web de la Mac lo muestre bien.
  - [x] **El paquete de la IA** (`Assistant/AIPacket.swift`) explica el método: Amanecer, los seis verbos, frases
    creíbles, e imaginar con obstáculo y plan. Las IA conocen SAVERS de memoria, así que el paquete pide no usarlo.
    - Se acepta el tipo de día nuevo y también "sin savers".
    - El bloque de cambios se llama `sunling`, pero ```` ```savers ```` se sigue aceptando.

  **Cierre**
  - [x] Probar con `/probar` los escenarios mañana, hechas, día completo, sin amanecer, historial y ajustes.
  - [x] Instalar en el iPhone.

  *Tú pruebas:* tu mañana normal. Ves "Amanecer" llenarse con cada paso, los nombres nuevos y, en un día libre,
  "Sunling descansa hoy". Abre también la web de la Mac y revisa que tu horario se vea bien.

- [x] **2. Inglés como idioma base**

  > **Hecha el 2026-10-02.** El código está en inglés y `SAVERS/Resources/Localizable.xcstrings` tiene el español
  > de los 452 textos, con plurales ("1 sunrise / 6 sunrises", "1 amanecer / 6 amaneceres"). En español la app
  > dice exactamente lo mismo que antes, y las frases de la voz no cambiaron, así que Gemini no rehace nada.
  > Los días y las fechas salen del idioma del iPhone ("Friday, Oct 2"); en español se conservan los formatos de
  > siempre ("Viernes 2 oct"). La voz del iPhone y el acento que se le pide a Gemini siguen el idioma de la app.
  > La IA: decidido contigo que el JSON va en el idioma de la app ("hours", "dates", "type" en inglés) y que al
  > pegar se entienden las dos lenguas. Para revisar traducciones después de compilar:
  > `python3 swift/tools/traducciones.py` (dice qué texto no tiene español y cuál sobra). `/probar` abre en
  > español como tu iPhone; con `--en` abre en inglés, con datos inventados en inglés.

  **Configuración**
  - [x] **El archivo de traducciones:** un `Localizable.xcstrings` con el inglés como idioma de desarrollo y el
    español completo, más `CFBundleDevelopmentRegion` en `en`.

  **Qué se traduce**
  - [x] **Todos los textos visibles**, incluidos los de los permisos y los avisos.
  - [x] **Plurales:** "1 sunrise / N sunrises" y "1 amanecer / N amaneceres".
  - [x] **Fechas y días:** `Weekday.names` y `DayKey` tienen los días en español escritos a mano; tienen que salir
    del idioma del iPhone.
  - [x] **Los pasos y el título:** Breathe, Affirm, Imagine, Move, Read, Write, con las iniciales B A I M R W. El
    título dice "Sunrise" en inglés y "Amanecer" en español; en cada idioma se ajusta al ancho.
  - [x] **La IA:** el paquete sale en el idioma de la app. Decidir contigo si las claves del JSON (`horas`,
    `fechas`, `tipo`) aceptan las dos lenguas.

  **Cierre**
  - [x] Probar el simulador en inglés (`-AppleLanguages (en)`) y en español.
  - [x] Instalar en el iPhone.

  *Tú pruebas:* nada debería cambiar en tu iPhone, que sigue en español. Si quieres, cambia el idioma del iPhone a
  inglés un rato para verla.

- [x] **3. Enseñar desde cero**

  > **Hecha el 2026-10-02.** En una instalación nueva, sin datos ni cuenta, aparecen 3 pantallas sobre la noche
  > del arranque, con Sunling dormido en el horizonte; se despierta un poco en cada una y al final baja a Hoy
  > como en cualquier apertura. La 1 dice qué es y muestra Calma, Rumbo y Crecer, y trae "Ya uso Sunling" para
  > entrar con Google. La 2 crea un horario con un solo bloque Amanecer a la hora en que despiertas, todos los
  > días Normal salvo Shabbat. La 3 muestra dos avisos de ejemplo.
  > Minutos que decidí yo (`Model/SunriseLength.swift`, el campo `length`, que la web de la Mac ya guarda):
  > 10 = Respira 2 · Afirma 2 · Imagina 2 · Muévete 2 · Lee 1 · Escribe 1; 20 = 5 · 2 · 3 · 2 · 6 · 2;
  > 30 = 8 · 2 · 3 · 8 · 7 · 2. Imagina da 40 s por pregunta en el de 10. Muévete tiene una rutina corta de unos
  > 2 min (marcha, los 4 ejercicios una vez y respirar); la de 8 queda para 30. Lo que pongas a mano en Horario
  > gana. Tus datos no tienen `length`, así que tus minutos no cambian.
  > Las notas de primera vez están hechas a mano, no con TipKit: TipKit no deja volver a mostrar una nota con la
  > ⓘ, y así la regla es simple: la nota sale mientras ese paso no se ha marcado nunca. A ti no te sale ninguna;
  > solo ves una ⓘ chica en la carta Ahora. "Saber más" abre El método en una hoja.
  > Afirma trae 3 frases de ejemplo con "Hacerlas mías"; el editor dice "Escribe frases que te creas" y tiene
  > "Escríbelas con una IA", que abre Hablar con una IA con la pregunta escrita. "¿Quieres más tiempo?" sale una
  > vez, en el día completo, desde el séptimo amanecer completo. Escenarios nuevos de `/probar`: `nuevo` y `siete`.
  > También: el botón lleno, sobre la noche, lleva el texto azul noche (el blanco no se leía).

  **Lo primero que ve alguien nuevo**
  - [x] **Las 3 pantallas de inicio**, sobre la noche y con Sunling dormido. Solo aparecen en una instalación nueva
    sin datos, nunca a ti.
    1. Qué es, en una frase.
    2. A qué hora despiertas, y 10, 20 o 30 minutos (10 marcado por defecto).
    3. El permiso de avisos, explicando para qué sirve.
  - [x] **10, 20 o 30 minutos:** los minutos de cada paso para cada opción.
  - [x] **La rutina corta de Muévete,** de unos 2 minutos, para la versión de 10. Va en `Exercise/`.

  **Lo que va aprendiendo**
  - [x] **Las notas de primera vez:** dentro de cada carta, qué es, cómo y por qué, más "Saber más". Se van al
    marcarla y vuelven con ⓘ. Decidir si se hacen con TipKit o a mano.
  - [x] **Afirma con ejemplos:** tres frases creíbles para editar, la línea "Escribe frases que te creas" y el botón
    "Escríbelas con una IA", que abre la página de la IA con la pregunta ya escrita.
  - [x] **A los 7 amaneceres,** una sola vez: "¿Quieres más tiempo?".

  **La página The method** (en Ajustes)
  - [x] Still, Aim y Grow, el porqué de cada paso con sus fuentes (de `metodo-sunling.md`), y "Where it comes
    from" con el crédito a Hal y la frase de que no estamos afiliados.

  **Cierre**
  - [x] Probar como alguien nuevo: app recién instalada en el simulador, en inglés y en español.
  - [x] Instalar en el iPhone.

  *Tú pruebas:* abrir The method y leerla. Si quieres verte como alguien nuevo, se hace en el simulador, nunca
  borrando tu app.

---

## Para después (no es parte de esta guía)

- **Lo personal fijo en el código:**
  - Shabbat el sábado;
  - "Gym con tu entrenador" y "Con tu café";
  - entrar con Google obligatorio;
  - la clave de Gemini.
- **Fuera de la app:** la web de la Mac con el método nuevo.
- **Antes de publicar:**
  - la política de privacidad;
  - una consulta con un abogado de marcas;
  - revisar la marca "Sunling" (hay una de joyería, de otro dueño).
