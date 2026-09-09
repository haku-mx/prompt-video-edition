# Haku iOS (SwiftUI)

App nativa que es la **interfaz principal de Haku**. Es un cliente delgado del
servidor FastAPI (`server/`): consume el mismo contrato de API, **nunca** corre
visión ni toca video. La frontera batch/interactivo del proyecto se mantiene
(ver [../PLAN.md](../PLAN.md) → "Track iOS").

## Requisitos

- Xcode 26+ (probado en Xcode 26.3, Swift 6.2).
- **iOS 26+** (simulador o dispositivo). La chrome usa **Liquid Glass**
  (`.glassEffect` / `GlassEffectContainer`), API de iOS 26; por eso el
  deployment target es 26.0 y no hay ramas de disponibilidad.

## Correr

1. Arranca el backend desde la raíz del repo:
   ```bash
   uvicorn server.main:app --reload
   ```
   Para esta pantalla (Biblioteca) **no hace falta AWS**: solo usa `/api/videos`,
   que no llama a Bedrock. (Si vas a cortar más adelante, usa
   `HAKU_DECIDE_BACKEND=fake` o credenciales reales.)

2. Abre `ios/Haku.xcodeproj` en Xcode y corre el target **Haku** en un simulador
   de iPhone. El simulador comparte la red del Mac, así que se conecta a
   `http://127.0.0.1:8000` directo (el `Info.plist` habilita ATS para red local).

   O por línea de comandos:
   ```bash
   xcodebuild -project ios/Haku.xcodeproj -scheme Haku \
     -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
   ```

La URL base del backend vive en `HakuAPI.localhost` (`Services/HakuAPI.swift`).
Cámbiala para apuntar a un backend remoto sin tocar nada más.

## Estructura

```
Haku/
  HakuApp.swift              entrada @main → LibraryView
  Info.plist                 ATS para localhost / red local
  Assets.xcassets/           AppIcon + AccentColor
  DesignSystem/
    HakuTheme.swift          tokens: color (blanco/haku), tipografía, espaciado, radios, layout
    PlaceholderThumbnail.swift  portada de gradiente determinista por video_id
    Interactions.swift       pressable, shimmer y esqueleto de carga
  Models/
    Video.swift              Video + VideosResponse (decodifican /api/videos)
    LibraryFolder.swift      modelo de carpeta (enriquecible) + Enrichment + árbol MOCK
  Services/
    HakuAPI.swift            único punto que habla con el backend (async/await)
  Features/Library/
    LibraryView.swift        pestañas (Biblioteca/Calendario) + chrome flotante + Buscar
    FolderScreen.swift       ventana única: carpetas + rejilla con zoom por gestos + notas
    CalendarView.swift       calendario mensual con los videos por día
    SearchSheet.swift        buscar por título/etiqueta + filtros y etiquetas sugeridas
    GalleryViewModel.swift   carga de media real + GalleryGrouping (Año/Mes/Día)
    Components/
      VideoTile.swift, FolderCard.swift, AddSheet.swift, NoteSheet.swift,
      FloatingChrome.swift   botonera (Biblioteca/Calendario) + búsqueda (abajo)
```

## Un solo concepto: la colección
**Álbum = colección = carpeta**: una unidad enriquecible que agrupa videos y
puede anidar sub-colecciones. Es `LibraryFolder`; en la UI se llama "Colección".
El enriquecimiento (música, lugar, nota, voz, enlaces) aplica **a nivel colección
y a nivel video**.

## Pestañas, Buscar, Notas y Calendario
- **Pestañas** en la botonera flotante: **Biblioteca** (explorador de colecciones)
  y **Calendario**. **Buscar** es el botón flotante independiente (abajo der.).
- **Buscar** (`SearchSheet`): campo por título/etiqueta, filtros (con ×), etiquetas
  sugeridas y **resultados seleccionables** → "Crear colección (N)" abre
  `NewCollectionSheet` (nombre + videos + enriquecer). Mock.
- **Crear colección** (`NewCollectionSheet`): desde Buscar (con selección) o desde
  el "+" (vacía). Nombre, videos incluidos y enriquecimiento. Mock.
- **Notas / enriquecimiento** (`NoteSheet`): en un **video** (tocar su tile) y en
  una **colección-recuerdo** (tarjeta "Nota del recuerdo"). Miniatura + fila de
  enriquecer (música/lugar/voz/enlace) + texto + campo tipo "preguntar". Mock.
- **Calendario** (`CalendarView`): rejilla mensual; los días con video muestran
  miniatura + check/conteo; navegación mes a mes.
- **Subir** (`UploadSheet`): Desde Fotos / Desde Archivos. Solo UX.

## Biblioteca unificada (una sola ventana)

Galería y Colecciones se fusionaron en un **explorador de carpetas** con la
rejilla de media integrada (`FolderScreen`):
- **Todo es carpetas**, enriquecibles: una carpeta puede ser un "recuerdo" con
  música/lugar/notas/voz (íconos en la portada).
- **Navegación drill-in**: tocar una carpeta entra (barra del sistema, Liquid
  Glass en iOS 26: título + atrás + "+").
- **Zoom temporal por gestos** (sin control de segmentos): **pinch** (como Fotos)
  y **swipe horizontal** alternan Año / Mes / Día; un indicador flotante confirma.
- **"+"** (arriba der.): menú Nueva carpeta / Subir archivos → `AddSheet`
  (iOS-M1: solo UX, nada se guarda ni se sube).

## Chrome (Liquid Glass, tema blanco)

La navegación no usa barras opacas: son piezas de vidrio. La **botonera**
(Biblioteca activa; Editar futuro) y **Buscar** flotan abajo y **persisten**
mientras se navega entre carpetas. Las vistas dejan `HakuLayout.bottomInset`
abajo para no quedar tapadas.

## Estado de datos
- **Raíz**: la media es real (`GET /api/videos`); las carpetas son mock.
- **Subcarpetas**: media mock con fechas variadas (para poblar el zoom).
- Carpetas y subida: **mock / UX** (sin persistencia ni endpoint todavía).

## Lo que sigue (iOS-M2+)

Detalle/reproducción de video, indexar desde la app, **subida real** (endpoint +
PhotosPicker), **carpetas persistentes** (SwiftData) y captura real de
enriquecimiento (grabación de voz, MapKit), prompt→corte.

El proyecto Xcode usa *file-system synchronized groups*: agregar un archivo
`.swift` bajo `Haku/` lo incluye automáticamente, sin editar el `.pbxproj`.
