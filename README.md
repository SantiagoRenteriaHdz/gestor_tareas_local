# Gestor de tareas local (Flutter + SQLite)

Práctica de *Programación de Dispositivos Móviles*: aplicación Flutter que
administra tareas en una base de datos **SQLite local**, sin servidor ni
conexión a internet, con una sola base de código para Android, iOS, Windows,
Linux, macOS y web.

## Tecnología de persistencia elegida

**Drift + drift_flutter** (sobre `sqlite3`).

- Drift es un ORM/consultor tipado para SQLite en Dart: las tablas se declaran
  en Dart y `build_runner` genera las clases de datos y los métodos de acceso.
- `drift_flutter` ofrece `driftDatabase(...)`, que abre la base en la ruta
  correcta de cada plataforma (carpeta de documentos de la app en
  Android/iOS/escritorio) y, en web, usa SQLite compilado a WebAssembly
  guardando los datos en OPFS o IndexedDB.
- Se descartó `sqflite` porque no soporta web ni escritorio sin paquetes
  adicionales, y `shared_preferences` porque no es SQLite.

## Diseño de la tabla

```
tareas
├── id          INTEGER PRIMARY KEY AUTOINCREMENT   -- identificador único
├── titulo      TEXT NOT NULL (1..200 caracteres)    -- título sin espacios extremos
└── completada  INTEGER NOT NULL DEFAULT 0           -- booleano (0 = pendiente, 1 = completada)
```

Cada registro se identifica por `id`, generado por SQLite al insertar.
Editar, marcar y eliminar usan siempre ese `id`.
