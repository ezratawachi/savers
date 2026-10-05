---
paths:
  - "swift/SAVERS/Schedule/**"
  - "swift/SAVERS/Model/**"
  - "swift/SAVERS/Domain/**"
---

# Horario y tipos de día

- El pasado nunca cambia: un cambio de semana o un tipo borrado se guarda en `Schedule.pastWeeks` (semanas con fecha
  `until`); nunca se reescriben los días.
- Los ids `normal`, `gym`, `off` y `shabbat` y las claves de los pasos (`silencio`…) no se renombran: están en la nube.
- Lo que falte en los ajustes (tipos, días de la semana) lo pone `AppSettings` → `migrate` al leer. No dar por hecho
  que la nube trae todo.
- `DayType` es igual por id: un `Picker` cuyo contenido solo depende de tipos no se redibuja al renombrar uno. Darle
  `.id(r.types.map(\.name))`, y lo mismo en vistas nuevas.
- Horas y minutos tienen 3 niveles (tipo, día de la semana, fecha); gana el más específico y una fecha guarda solo lo
  que se tocó.
