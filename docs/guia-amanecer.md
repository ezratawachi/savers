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

- [ ] **1. El método dentro de la app** (en español; los textos pasan al archivo de traducciones en la 2).

  **El título**
  - [ ] **"Amanecer" reemplaza a SAVERS** (`Today/HeroLetters.swift`). La palabra va de borde a borde y se llena de
    ámbar de abajo hacia arriba según los pasos hechos (`doneCount / 6`). El resto queda en `nightLetter`. Corte
    duro, sin degradado.
    - Animación: `Motion.sun`; con Reducir movimiento, fundido.
    - Accesibilidad: "Amanecer, 3 de 6".

  **Los pasos**
  - [ ] **Nombres:** `Letter.name` pasa a Respira, Afirma, Imagina, Muévete, Lee y Escribe.
  - [ ] **Iniciales del círculo:** pasan a R A I M L E. El círculo (`CheckCircle`) sigue mostrando la inicial;
    ahora ninguna se repite.
  - [ ] **Subtítulo de Respira:** por defecto, "Medita, reza o solo respira". Cada persona puede escribir el suyo
    (el tuyo sería "Daily Calm").
    - Es un campo nuevo en ajustes, que se sincroniza.
    - Revisar que el `normalizeSettings` de la web de la Mac no lo borre.

  **Los textos**
  - [ ] **Se cambian:**
    - "Hacer mis SAVERS hoy"
    - "Hoy no toca SAVERS" → "Sunling descansa hoy"
    - "N días seguidos" → "N amaneceres seguidos"
    - "Sin SAVERS"
    - "Registrar mis SAVERS"
    - "N días de SAVERS" (Tu semana)
    - el texto del editor del día
    - la frase de respaldo de la voz (`GeminiVoice`)
  - [ ] **Textos a confirmar contigo al empezar:** el nombre del tipo de día "Sin SAVERS" (¿"Descanso"?) y la línea
    de Tu semana.

  **Tus datos y la IA**
  - [ ] **Tu bloque "SAVERS":** en tu horario, el bloque se llama "SAVERS". Hay que cambiarlo una sola vez a
    "Amanecer". Además, `Schedule/DayEditor.swift` hoy lo encuentra buscando "savers" en el título; tiene que
    encontrarlo con una regla estable, como "el bloque que tiene pasos". Verificar que la web de la Mac lo muestre bien.
  - [ ] **El paquete de la IA** (`Assistant/AIPacket.swift`) explica el método: Amanecer, los seis verbos, frases
    creíbles, e imaginar con obstáculo y plan. Las IA conocen SAVERS de memoria, así que el paquete pide no usarlo.
    - Se acepta el tipo de día nuevo y también "sin savers".
    - El bloque de cambios se llama `sunling`, pero ```` ```savers ```` se sigue aceptando.

  **Cierre**
  - [ ] Probar con `/probar` los escenarios mañana, hechas, día completo, sin amanecer, historial y ajustes.
  - [ ] Instalar en el iPhone.

  *Tú pruebas:* tu mañana normal. Ves "Amanecer" llenarse con cada paso, los nombres nuevos y, en un día libre,
  "Sunling descansa hoy". Abre también la web de la Mac y revisa que tu horario se vea bien.

- [ ] **2. Inglés como idioma base**

  **Configuración**
  - [ ] **El archivo de traducciones:** un `Localizable.xcstrings` con el inglés como idioma de desarrollo y el
    español completo, más `CFBundleDevelopmentRegion` en `en`.

  **Qué se traduce**
  - [ ] **Todos los textos visibles**, incluidos los de los permisos y los avisos.
  - [ ] **Plurales:** "1 sunrise / N sunrises" y "1 amanecer / N amaneceres".
  - [ ] **Fechas y días:** `Weekday.names` y `DayKey` tienen los días en español escritos a mano; tienen que salir
    del idioma del iPhone.
  - [ ] **Los pasos y el título:** Breathe, Affirm, Imagine, Move, Read, Write, con las iniciales B A I M R W. El
    título dice "Sunrise" en inglés y "Amanecer" en español; en cada idioma se ajusta al ancho.
  - [ ] **La IA:** el paquete sale en el idioma de la app. Decidir contigo si las claves del JSON (`horas`,
    `fechas`, `tipo`) aceptan las dos lenguas.

  **Cierre**
  - [ ] Probar el simulador en inglés (`-AppleLanguages (en)`) y en español.
  - [ ] Instalar en el iPhone.

  *Tú pruebas:* nada debería cambiar en tu iPhone, que sigue en español. Si quieres, cambia el idioma del iPhone a
  inglés un rato para verla.

- [ ] **3. Enseñar desde cero**

  **Lo primero que ve alguien nuevo**
  - [ ] **Las 3 pantallas de inicio**, sobre la noche y con Sunling dormido. Solo aparecen en una instalación nueva
    sin datos, nunca a ti.
    1. Qué es, en una frase.
    2. A qué hora despiertas, y 10, 20 o 30 minutos (10 marcado por defecto).
    3. El permiso de avisos, explicando para qué sirve.
  - [ ] **10, 20 o 30 minutos:** los minutos de cada paso para cada opción.
  - [ ] **La rutina corta de Muévete,** de unos 2 minutos, para la versión de 10. Va en `Exercise/`.

  **Lo que va aprendiendo**
  - [ ] **Las notas de primera vez:** dentro de cada carta, qué es, cómo y por qué, más "Saber más". Se van al
    marcarla y vuelven con ⓘ. Decidir si se hacen con TipKit o a mano.
  - [ ] **Afirma con ejemplos:** tres frases creíbles para editar, la línea "Escribe frases que te creas" y el botón
    "Escríbelas con una IA", que abre la página de la IA con la pregunta ya escrita.
  - [ ] **A los 7 amaneceres,** una sola vez: "¿Quieres más tiempo?".

  **La página The method** (en Ajustes)
  - [ ] Still, Aim y Grow, el porqué de cada paso con sus fuentes (de `metodo-sunling.md`), y "Where it comes
    from" con el crédito a Hal y la frase de que no estamos afiliados.

  **Cierre**
  - [ ] Probar como alguien nuevo: app recién instalada en el simulador, en inglés y en español.
  - [ ] Instalar en el iPhone.

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
