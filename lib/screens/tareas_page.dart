import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/tarea.dart';

/// Pantalla principal. La lista se obtiene de SQLite mediante un Stream que
/// se suscribe una sola vez en initState (no hay consultas dentro de build()).
class TareasPage extends StatefulWidget {
  final TareasRepository repositorio;

  const TareasPage({super.key, required this.repositorio});

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final TextEditingController _tituloController = TextEditingController();
  StreamSubscription<List<Tarea>>? _suscripcion;

  List<Tarea> _tareas = [];
  bool _cargando = true;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _suscripcion = widget.repositorio.observarTareas().listen(
      (tareas) {
        if (!mounted) return;
        setState(() {
          _tareas = tareas;
          _cargando = false;
          _errorCarga = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _errorCarga = 'No se pudo leer la base de datos: $error';
        });
      },
    );
  }

  Future<void> _agregarTarea() async {
    try {
      await widget.repositorio.agregar(_tituloController.text);
      _tituloController.clear();
    } on TituloInvalidoException catch (e) {
      _mostrarMensaje(e.mensaje);
    } catch (e) {
      _mostrarMensaje('No se pudo guardar la tarea: $e');
    }
  }

  Future<void> _alternarCompletada(Tarea tarea, bool completada) async {
    try {
      await widget.repositorio.cambiarEstado(tarea.id, completada);
    } catch (e) {
      _mostrarMensaje('No se pudo actualizar la tarea: $e');
    }
  }

  Future<void> _editarTarea(Tarea tarea) async {
    final nuevoTitulo = await showDialog<String>(
      context: context,
      builder: (_) => _EditarTituloDialog(tituloInicial: tarea.titulo),
    );
    if (nuevoTitulo == null) return; // Cancelado.
    try {
      await widget.repositorio.editarTitulo(tarea.id, nuevoTitulo);
    } on TituloInvalidoException catch (e) {
      _mostrarMensaje(e.mensaje);
    } catch (e) {
      _mostrarMensaje('No se pudo editar la tarea: $e');
    }
  }

  Future<void> _eliminarTarea(Tarea tarea) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Eliminar "${tarea.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await widget.repositorio.eliminar(tarea.id);
      _mostrarMensaje('Tarea eliminada');
    } catch (e) {
      _mostrarMensaje('No se pudo eliminar la tarea: $e');
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _tituloController.dispose();
    super.dispose();
  }

  Widget _contenidoLista() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCarga != null) {
      return Center(child: Text(_errorCarga!, textAlign: TextAlign.center));
    }
    if (_tareas.isEmpty) {
      return const Center(child: Text('Todavía no hay tareas guardadas'));
    }
    return ListView.builder(
      itemCount: _tareas.length,
      itemBuilder: (context, index) {
        final tarea = _tareas[index];
        return Card(
          child: ListTile(
            leading: Checkbox(
              value: tarea.completada,
              onChanged: (valor) {
                if (valor != null) {
                  _alternarCompletada(tarea, valor);
                }
              },
            ),
            title: Text(
              tarea.titulo,
              style: tarea.completada
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: Text('ID: ${tarea.id}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editarTarea(tarea),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _eliminarTarea(tarea),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestor de tareas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              maxLength: longitudMaximaTitulo,
              decoration: const InputDecoration(
                labelText: 'Nueva tarea',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _agregarTarea(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _agregarTarea,
              icon: const Icon(Icons.add),
              label: const Text('Agregar tarea'),
            ),
            const SizedBox(height: 12),
            const Text('Mis tareas', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(child: _contenidoLista()),
          ],
        ),
      ),
    );
  }
}

/// Diálogo con su propio controlador para que se libere al cerrarse.
class _EditarTituloDialog extends StatefulWidget {
  final String tituloInicial;

  const _EditarTituloDialog({required this.tituloInicial});

  @override
  State<_EditarTituloDialog> createState() => _EditarTituloDialogState();
}

class _EditarTituloDialogState extends State<_EditarTituloDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.tituloInicial);
  String? _error;

  void _guardar() {
    try {
      Navigator.pop(context, validarTitulo(_controller.text));
    } on TituloInvalidoException catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar título'),
      content: TextField(
        key: const Key('campoEditarTitulo'),
        controller: _controller,
        autofocus: true,
        maxLength: longitudMaximaTitulo,
        decoration: InputDecoration(
          labelText: 'Título',
          errorText: _error,
        ),
        onSubmitted: (_) => _guardar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
