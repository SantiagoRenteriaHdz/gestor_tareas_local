# Gestor de tareas local (Flutter + SQLite)

Práctica de *Programación de Dispositivos Móviles*: aplicación Flutter que
administra tareas en una base de datos **SQLite local**, sin servidor ni
conexión a internet, con una sola base de código para Android, iOS, Windows,
Linux, macOS y web.

## Tecnología de persistencia elegida

**Drift + drift_flutter** (sobre `sqlite3`).

| Paquete | Versión | Para qué |
|---|---|---|
| `drift` | 2.35.4 | Definir la tabla en Dart y ejecutar consultas tipadas (INSERT/SELECT/UPDATE/DELETE) |
| `drift_flutter` | 0.3.1 | `driftDatabase()` abre la base en la ruta correcta de cada plataforma y en web |
| `drift_dev` + `build_runner` (dev) | 2.35.3 / 2.17.1 | Generan `app_database.g.dart` a partir de la definición de la tabla |

- Se descartó `sqflite` porque no funciona en web y en escritorio necesita
  paquetes extra; `shared_preferences` no es SQLite.
- La interfaz se actualiza con una **consulta reactiva** (`watch()` → `Stream`):
  tras cualquier escritura, Drift vuelve a emitir la lista sin tener que
  recargarla a mano.

## Diseño de la tabla

```
tareas
├── id          INTEGER PRIMARY KEY AUTOINCREMENT   -- identificador único
├── titulo      TEXT NOT NULL (1..200 caracteres)    -- título sin espacios extremos
└── completada  INTEGER NOT NULL DEFAULT 0           -- booleano (0 = pendiente, 1 = completada)
```

Cada registro se identifica por `id`, generado por SQLite al insertar.
Editar, marcar y eliminar usan siempre ese `id`. Con `AUTOINCREMENT` un id
eliminado no se reutiliza.

## Estructura

```
lib/
├── main.dart                     # Crea una sola AppDatabase y la cierra en dispose()
├── models/tarea.dart             # Modelo usado por la interfaz
├── data/
│   ├── app_database.dart         # Tabla Drift + apertura multiplataforma
│   ├── app_database.g.dart       # Generado por build_runner
│   └── tareas_repository.dart    # Validación + CRUD; la UI solo usa esta clase
└── screens/tareas_page.dart      # Se suscribe al Stream en initState (sin SQL en build)
web/
├── sqlite3.wasm                  # SQLite compilado a WebAssembly
└── drift_worker.js               # Worker de Drift que ejecuta SQLite en el navegador
```

### Dónde se guardan los datos

- **Android / iOS / Windows / Linux / macOS:** archivo `gestor_tareas.sqlite`
  en la carpeta de documentos de la app (`getApplicationDocumentsDirectory()`).
- **Web:** SQLite corre en WebAssembly dentro de un worker; los datos se guardan
  en OPFS o IndexedDB según lo que soporte el navegador (en Edge, sin cabeceras
  COOP/COEP, Drift eligió `sharedIndexedDb`). Los datos son por origen y perfil:
  se pierden en modo privado al cerrar la ventana o al borrar los datos del sitio.

### Archivos web

`web/sqlite3.wasm` y `web/drift_worker.js` se obtuvieron de la release oficial
[`drift-2.35.4`](https://github.com/simolus3/drift/releases/tag/drift-2.35.4),
la misma versión de `drift` que está en `pubspec.lock`. Si se actualiza `drift`,
hay que descargar los dos archivos de la release correspondiente:

```bash
gh release download drift-<versión> -R simolus3/drift -p drift_worker.js -p sqlite3.wasm -D web --clobber
```

## Cómo ejecutar

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # solo si se cambia la tabla
flutter analyze
flutter test
flutter run -d chrome        # o -d edge, -d windows, -d <id de Android>
```

## Pruebas automatizadas (`flutter test`)

13 pruebas, todas pasan:

- `test/tareas_repository_test.dart`
  - **Validación:** rechaza títulos vacíos, de solo espacios, `null` o de más de
    200 caracteres, y recorta espacios.
  - **CRUD en SQLite en memoria:** INSERT/SELECT con ids únicos, un título vacío
    no se inserta, UPDATE de título y estado, una edición inválida no modifica
    el registro, DELETE por id borra solo esa tarea, el `Stream` emite tras escribir.
  - **Persistencia en archivo:** crea, marca, edita y elimina en un archivo
    `.sqlite`, **cierra la base y la vuelve a abrir** y comprueba el resultado
    (equivalente automatizado de P1–P4 con el SQLite nativo de la máquina).
- `test/widget_test.dart`: la pantalla inicial abre, un título de espacios
  muestra error sin crear tarea, y agregar una tarea la muestra en la lista.

## Plataformas y resultados de P1–P6

| Plataforma | Estado |
|---|---|
| Web (Microsoft Edge 158, `flutter build web` servido en `localhost`) | **Probada:** P1–P6 correctas |
| Windows (pruebas `flutter test` con SQLite nativo vía FFI) | **Probada la capa de datos** (prueba de cerrar/reabrir archivo). La app de escritorio no se compiló: falta Visual Studio con “Desarrollo de escritorio con C++”. |
| Android | Prevista; ver nota de compilación abajo |
| iOS, macOS, Linux | Previstas (mismo código; requieren Mac o Linux para compilar) |

| ID | Acción | Resultado en web |
|---|---|---|
| P1 | Agregar tres tareas, recargar | Permanecen las tres |
| P2 | Marcar una como completada y recargar | Se conserva el estado |
| P3 | Cambiar un título y recargar | Aparece el nuevo título |
| P4 | Eliminar una tarea y recargar | No reaparece |
| P5 | Agregar un título vacío o de espacios | Muestra “El título no puede estar vacío.” y no se guarda |
| P6 | Recargar y cerrar/abrir la pestaña (mismo origen y perfil) | Los datos permanecen |
