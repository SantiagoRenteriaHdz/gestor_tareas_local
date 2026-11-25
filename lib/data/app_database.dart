import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Tabla `tareas` en SQLite.
///
/// - `id`: INTEGER PRIMARY KEY AUTOINCREMENT, lo genera SQLite.
/// - `titulo`: TEXT NOT NULL, entre 1 y 200 caracteres.
/// - `completada`: SQLite no tiene tipo booleano; Drift lo guarda como
///   INTEGER con restricción CHECK (0 = pendiente, 1 = completada).
@DataClassName('TareaRegistro')
class Tareas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titulo => text().withLength(min: 1, max: 200)();
  BoolColumn get completada => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Tareas])
class AppDatabase extends _$AppDatabase {
  /// Sin argumentos abre la base persistente de la plataforma.
  /// En pruebas se puede pasar un [QueryExecutor] en memoria.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? _abrirConexionPersistente());

  @override
  int get schemaVersion => 1;

  /// `driftDatabase` elige la implementación según la plataforma:
  /// - Android/iOS/Windows/Linux/macOS: archivo `gestor_tareas.sqlite` en la
  ///   carpeta de documentos de la aplicación (path_provider).
  /// - Web: SQLite compilado a WebAssembly (`web/sqlite3.wasm`) ejecutado en
  ///   un worker (`web/drift_worker.js`), con datos en OPFS o IndexedDB.
  static QueryExecutor _abrirConexionPersistente() {
    return driftDatabase(
      name: 'gestor_tareas',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
