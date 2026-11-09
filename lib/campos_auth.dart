import 'package:flutter/material.dart';

const _panel = Color(0xFF1F2244);
const _dorado = Color(0xFFFFD166);
const _rojo = Color(0xFFFF6B6B);

InputDecoration decoracionCampo(
  String etiqueta,
  IconData icono, {
  Widget? sufijo,
}) {
  OutlineInputBorder borde(Color color, [double ancho = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: ancho),
    );
  }

  return InputDecoration(
    labelText: etiqueta,
    labelStyle: const TextStyle(color: Colors.white70),
    prefixIcon: Icon(icono, color: Colors.white54),
    suffixIcon: sufijo,
    filled: true,
    fillColor: _panel,
    enabledBorder: borde(Colors.transparent),
    focusedBorder: borde(_dorado, 2),
    errorBorder: borde(_rojo),
    focusedErrorBorder: borde(_rojo, 2),
    errorStyle: const TextStyle(color: Color(0xFFFF8A8A)),
  );
}

/// Campo de contraseña con el ojito para mostrarla u ocultarla.
class CampoContrasena extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;
  final String? Function(String?) validador;
  final TextInputAction accion;
  final ValueChanged<String>? alEnviar;

  const CampoContrasena({
    super.key,
    required this.controller,
    required this.validador,
    this.etiqueta = 'Contraseña',
    this.accion = TextInputAction.next,
    this.alEnviar,
  });

  @override
  State<CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<CampoContrasena> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _oculta,
      textInputAction: widget.accion,
      onFieldSubmitted: widget.alEnviar,
      validator: widget.validador,
      decoration: decoracionCampo(
        widget.etiqueta,
        Icons.lock_outline_rounded,
        sufijo: IconButton(
          tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
          onPressed: () => setState(() => _oculta = !_oculta),
          icon: Icon(
            _oculta ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}

/// Error del inicio de sesión o del registro. Si [sinServidor] es true se
/// muestra un aviso amable (el servidor no está disponible); si no, el
/// mensaje en rojo.
class AvisoErrorAuth extends StatelessWidget {
  final String error;
  final bool sinServidor;

  const AvisoErrorAuth({
    super.key,
    required this.error,
    this.sinServidor = false,
  });

  @override
  Widget build(BuildContext context) {
    final mensaje = Text(
      error,
      key: const Key('error-auth'),
      textAlign: TextAlign.center,
      style: TextStyle(color: sinServidor ? Colors.white70 : _rojo),
    );
    if (!sinServidor) {
      return Padding(padding: const EdgeInsets.only(top: 12), child: mensaje);
    }

    return Container(
      key: const Key('aviso-sin-servidor'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _dorado.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: _dorado),
          const SizedBox(height: 6),
          const Text(
            'El servidor no está disponible ahora',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          mensaje,
        ],
      ),
    );
  }
}
