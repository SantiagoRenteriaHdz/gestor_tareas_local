import 'package:drift/drift.dart';

import '../models/tarea.dart';
import 'app_database.dart';

/// Error de validación con un mensaje que se puede mostrar al usuario.
class TituloInvalidoException implements Exception {
  final String mensaje;
  const TituloInvalidoException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Longitud máxima permitida para un título (coincide con la tabla).
const int longitudMaximaTitulo = 200;

/// Limpia y valida un título. Devuelve el título sin espacios extremos o
/// lanza [TituloInvalidoException].
String validarTitulo(String? titulo) {
  final limpio = (titulo ?? '').trim();
  if (limpio.isEmpty) {
    throw const TituloInvalidoException('El título no puede estar vacío.');
  }
  if (limpio.length > longitudMaximaTitulo) {
    throw const TituloInvalidoException(
      'El título no puede superar $longitudMaximaTitulo caracteres.',
    );
  }
  return limpio;
}

/// Capa de acceso a datos: la interfaz solo habla con esta clase y nunca
/// ejecuta SQL directamente.
class TareasRepository {
  final AppDatabase _db;

  TareasRepository(this._db);

  /// SELECT reactivo: emite la lista cada vez que la tabla cambia.
  Stream<List<Tarea>> observarTareas() {
    final consulta = _db.select(_db.tareas)
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return consulta.watch().map((filas) => filas.map(_aModelo).toList());
  }

  /// SELECT único (útil en pruebas).
  Future<List<Tarea>> obtenerTareas() async {
    final consulta = _db.select(_db.tareas)
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    final filas = await consulta.get();
    return filas.map(_aModelo).toList();
  }

  /// INSERT. Devuelve el id generado por SQLite.
  Future<int> agregar(String titulo) {
    final limpio = validarTitulo(titulo);
    return _db.into(_db.tareas).insert(TareasCompanion.insert(titulo: limpio));
  }

  /// UPDATE del título por id. Devuelve true si se modificó un registro.
  Future<bool> editarTitulo(int id, String nuevoTitulo) async {
    final limpio = validarTitulo(nuevoTitulo);
    final filas = await (_db.update(_db.tareas)..where((t) => t.id.equals(id)))
        .write(TareasCompanion(titulo: Value(limpio)));
    return filas > 0;
  }

  /// UPDATE del estado por id.
  Future<bool> cambiarEstado(int id, bool completada) async {
    final filas = await (_db.update(_db.tareas)..where((t) => t.id.equals(id)))
        .write(TareasCompanion(completada: Value(completada)));
    return filas > 0;
  }

  /// DELETE por id. Devuelve true si se eliminó un registro.
  Future<bool> eliminar(int id) async {
    final filas =
        await (_db.delete(_db.tareas)..where((t) => t.id.equals(id))).go();
    return filas > 0;
  }

  Tarea _aModelo(TareaRegistro r) =>
      Tarea(id: r.id, titulo: r.titulo, completada: r.completada);
}
