---
paths:
  - "swift/**/*.swift"
---

# SwiftUI en Sunling

- Listas: `AppList` (en `Design/`) en vez de `List`; páginas de Ajustes con `CardSections`.
- `Binding($optional)` para editar crashea al poner nil: usar un Bool aparte.
- En un `LazyVGrid`, varios `ForEach` con ids Int (cabeceras, huecos, días) chocan y desaparecen celdas: usar ids de
  texto distintos.
- Al unir trazo y disco en un `Path`, usar `.union`; si no, se cancelan y quedan huecos.
- Al desvanecer algo con capas (Sunling, la cortina de apertura), `.compositingGroup()` para que no se vean las capas
  de abajo.
