import 'package:flutter/material.dart';

import 'campos_auth.dart';

const _rojo = Color(0xFFFF6B6B);

/// Borra la cuenta con la contraseña. Devuelve null si la sesión terminó
/// (el diálogo se cierra) o el mensaje de error si la sesión sigue.
typedef EliminarCuenta = Future<String?> Function(String contrasena);

/// Abre el diálogo de "Eliminar cuenta". Devuelve true si se cerró porque
/// la sesión terminó (cuenta borrada).
Future<bool> mostrarDialogoEliminarCuenta(
  BuildContext context,
  EliminarCuenta alEliminar,
) async {
  final resultado = await showDialog<bool>(
    context: context,
    // No se cierra tocando fuera para no perder lo escrito por accidente.
    barrierDismissible: false,
    builder: (_) => DialogoEliminarCuenta(alEliminar: alEliminar),
  );
  return resultado ?? false;
}

/// Explica que es permanente y exige escribir la contraseña.
class DialogoEliminarCuenta extends StatefulWidget {
  final EliminarCuenta alEliminar;

  const DialogoEliminarCuenta({super.key, required this.alEliminar});

  @override
  State<DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<DialogoEliminarCuenta> {
  final _contrasena = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contrasena.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contrasena.dispose();
    super.dispose();
  }

  bool get _puedeEliminar => !_cargando && _contrasena.text.isNotEmpty;

  Future<void> _eliminar() async {
    if (!_puedeEliminar) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    final error = await widget.alEliminar(_contrasena.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _cargando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Esta acción es permanente: se borrará tu cuenta y no se puede '
            'deshacer.',
          ),
          const SizedBox(height: 8),
          const Text('Escribe tu contraseña para confirmar.'),
          const SizedBox(height: 12),
          CampoContrasena(
            key: const Key('campo-contrasena-eliminar'),
            controller: _contrasena,
            validador: (_) => null,
            accion: TextInputAction.done,
            alEnviar: (_) => _eliminar(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('error-eliminar'),
              style: const TextStyle(color: _rojo),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cargando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton-eliminar-cuenta'),
          style: FilledButton.styleFrom(
            backgroundColor: _rojo,
            foregroundColor: Colors.black,
          ),
          onPressed: _puedeEliminar ? _eliminar : null,
          child: _cargando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Eliminar'),
        ),
      ],
    );
  }
}
