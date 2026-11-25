import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';

void main() {
  // Varias pruebas abren más de una base; se desactiva el aviso de Drift.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('validarTitulo', () {
    test('rechaza títulos vacíos o solo con espacios', () {
      expect(() => validarTitulo(''), throwsA(isA<TituloInvalidoException>()));
      expect(
        () => validarTitulo('   \t  '),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect(
        () => validarTitulo(null),
        throwsA(isA<TituloInvalidoException>()),
      );
    });

    test('rechaza títulos demasiado largos', () {
      expect(
        () => validarTitulo('a' * (longitudMaximaTitulo + 1)),
        throwsA(isA<TituloInvalidoException>()),
      );
    });

    test('quita espacios al inicio y al final', () {
      expect(validarTitulo('  Comprar pan  '), 'Comprar pan');
    });
  });

  group('TareasRepository (SQLite en memoria)', () {
    late AppDatabase db;
    late TareasRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TareasRepository(db);
    });

    tearDown(() => db.close());

    test('INSERT y SELECT: agrega tareas pendientes con id único', () async {
      final id1 = await repo.agregar('Primera');
      final id2 = await repo.agregar('  Segunda  ');

      final tareas = await repo.obtenerTareas();
      expect(tareas.map((t) => t.id), [id1, id2]);
      expect(tareas.map((t) => t.titulo), ['Primera', 'Segunda']);
      expect(tareas.every((t) => !t.completada), isTrue);
    });

    test('un título vacío no se inserta', () async {
      await expectLater(
        repo.agregar('   '),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect(await repo.obtenerTareas(), isEmpty);
    });

    test('UPDATE de título y de estado', () async {
      final id = await repo.agregar('Original');

      expect(await repo.editarTitulo(id, 'Editada'), isTrue);
      expect(await repo.cambiarEstado(id, true), isTrue);

      final tarea = (await repo.obtenerTareas()).single;
      expect(tarea.titulo, 'Editada');
      expect(tarea.completada, isTrue);

      await repo.cambiarEstado(id, false);
      expect((await repo.obtenerTareas()).single.completada, isFalse);
    });

    test('editar con título inválido no modifica el registro', () async {
      final id = await repo.agregar('Original');
      await expectLater(
        repo.editarTitulo(id, ''),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect((await repo.obtenerTareas()).single.titulo, 'Original');
    });

    test('DELETE por id elimina solo esa tarea', () async {
      final id1 = await repo.agregar('Conservar');
      final id2 = await repo.agregar('Borrar');

      expect(await repo.eliminar(id2), isTrue);
      expect(await repo.eliminar(id2), isFalse); // Ya no existe.

      final tareas = await repo.obtenerTareas();
      expect(tareas.map((t) => t.id), [id1]);
    });

    test('el Stream emite la lista actualizada tras cada escritura', () async {
      final emisiones = repo.observarTareas().map(
        (lista) => lista.map((t) => t.titulo).toList(),
      );
      final esperado = expectLater(
        emisiones,
        emitsInOrder([
          <String>[],
          ['A'],
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      await repo.agregar('A');
      await esperado;
    });
  });

  group('Persistencia en archivo SQLite (P1-P4)', () {
    late Directory carpeta;
    late File archivo;

    setUp(() async {
      carpeta = await Directory.systemTemp.createTemp('gestor_tareas_test');
      archivo = File('${carpeta.path}/tareas.sqlite');
    });

    tearDown(() async {
      if (await carpeta.exists()) await carpeta.delete(recursive: true);
    });

    test('los cambios sobreviven a cerrar y reabrir la base', () async {
      // Primera "ejecución" de la app.
      var db = AppDatabase(NativeDatabase(archivo));
      var repo = TareasRepository(db);
      final a = await repo.agregar('Tarea A');
      final b = await repo.agregar('Tarea B');
      final c = await repo.agregar('Tarea C');
      await repo.cambiarEstado(a, true);
      await repo.editarTitulo(b, 'Tarea B editada');
      await repo.eliminar(c);
      await db.close();

      // Segunda "ejecución": se abre el mismo archivo desde cero.
      db = AppDatabase(NativeDatabase(archivo));
      repo = TareasRepository(db);
      final tareas = await repo.obtenerTareas();
      await db.close();

      expect(tareas.length, 2);
      expect(tareas[0].id, a);
      expect(tareas[0].completada, isTrue);
      expect(tareas[1].titulo, 'Tarea B editada');
      expect(tareas.any((t) => t.id == c), isFalse);
    });
  });
}
