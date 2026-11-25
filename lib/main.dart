import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/tareas_repository.dart';
import 'screens/tareas_page.dart';

void main() {
  runApp(const GestorTareasApp());
}

/// Punto de entrada de la aplicación.
///
/// Crea una sola instancia de la base de datos para toda la app y la cierra
/// cuando el widget se destruye. En pruebas se puede inyectar otra base.
class GestorTareasApp extends StatefulWidget {
  final AppDatabase? database;

  const GestorTareasApp({super.key, this.database});

  @override
  State<GestorTareasApp> createState() => _GestorTareasAppState();
}

class _GestorTareasAppState extends State<GestorTareasApp> {
  late final AppDatabase _db;
  late final TareasRepository _repositorio;

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? AppDatabase();
    _repositorio = TareasRepository(_db);
  }

  @override
  void dispose() {
    // Libera la conexión a SQLite.
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de tareas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TareasPage(repositorio: _repositorio),
    );
  }
}
