import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/main.dart';

/// Monta la app con una base SQLite en memoria (no depende de path_provider).
Future<void> montarApp(WidgetTester tester) async {
  await tester.pumpWidget(
    GestorTareasApp(database: AppDatabase(NativeDatabase.memory())),
  );
  // Deja que la consulta inicial del Stream termine.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

/// Desmonta la app para que se cierre la base. Drift programa un Timer de
/// duración cero al cancelar el Stream; se deja avanzar el reloj falso para
/// que no quede pendiente al terminar la prueba.
Future<void> desmontarApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('La pantalla inicial se muestra sin errores', (tester) async {
    await montarApp(tester);
    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);
    await desmontarApp(tester);
  });

  testWidgets('Un título con solo espacios muestra error y no se guarda', (
    tester,
  ) async {
    await montarApp(tester);
    await tester.enterText(find.byType(TextField), '    ');
    await tester.tap(find.text('Agregar tarea'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('El título no puede estar vacío.'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await desmontarApp(tester);
  });

  testWidgets('Agregar una tarea la muestra en la lista', (tester) async {
    await montarApp(tester);
    await tester.enterText(find.byType(TextField), 'Estudiar Drift');
    await tester.tap(find.text('Agregar tarea'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.widgetWithText(ListTile, 'Estudiar Drift'), findsOneWidget);
    // El campo se limpia después de guardar.
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.controller!.text, isEmpty);
    await desmontarApp(tester);
  });
}
