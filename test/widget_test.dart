import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/main.dart';

void main() {
  testWidgets('La pantalla inicial se muestra sin errores', (tester) async {
    // Base en memoria para no depender de path_provider en las pruebas.
    await tester.pumpWidget(
      GestorTareasApp(database: AppDatabase(NativeDatabase.memory())),
    );
    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Desmonta la app para que se cierre la base y no queden timers.
    // Drift programa un Timer de duración cero al cancelar el Stream; se deja
    // avanzar el reloj falso para que no quede pendiente.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
