import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tipo.dart';

/// Caracteres de los códigos de sala, los mismos que usa el servidor: sin
/// 0, O, 1, I ni L, que se confunden.
const alfabetoCodigoSala = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const largoCodigoSala = 6;

/// Pasa a mayúsculas, quita lo que no es válido y corta en 6 caracteres.
class FormateadorCodigoSala extends TextInputFormatter {
  const FormateadorCodigoSala();

  static String limpiar(String texto) {
    final buffer = StringBuffer();
    for (final c in texto.toUpperCase().split('')) {
      if (buffer.length == largoCodigoSala) break;
      if (alfabetoCodigoSala.contains(c)) buffer.write(c);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final limpio = limpiar(nuevo.text);
    return TextEditingValue(
      text: limpio,
      selection: TextSelection.collapsed(offset: limpio.length),
    );
  }
}

bool codigoSalaCompleto(String codigo) =>
    codigo.length == largoCodigoSala &&
    FormateadorCodigoSala.limpiar(codigo) == codigo;

/// Pregunta para cuántos jugadores es la sala del [mapa]. Devuelve el
/// máximo (2 a 4) o null si se cancela.
Future<int?> mostrarDialogoCrearSala(BuildContext context, Nivel mapa) {
  return showDialog<int>(
    context: context,
    builder: (_) => _DialogoCrearSala(mapa: mapa),
  );
}

class _DialogoCrearSala extends StatefulWidget {
  final Nivel mapa;

  const _DialogoCrearSala({required this.mapa});

  @override
  State<_DialogoCrearSala> createState() => _DialogoCrearSalaState();
}

class _DialogoCrearSalaState extends State<_DialogoCrearSala> {
  int _maximo = 2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear sala'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mapa ${widget.mapa.numero}',
            key: const Key('crear-sala-mapa'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('Cambia el mapa en Buscar partida antes de crearla.'),
          const SizedBox(height: 16),
          const Text('¿Cuántos jugadores?'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            key: const Key('crear-sala-jugadores'),
            segments: const [
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
              ButtonSegment(value: 4, label: Text('4')),
            ],
            selected: {_maximo},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _maximo = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar-crear-sala'),
          onPressed: () => Navigator.of(context).pop(_maximo),
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

/// Pide el código de una sala. Devuelve el código (6 caracteres válidos) o
/// null si se cancela.
Future<String?> mostrarDialogoUnirse(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _DialogoUnirse(),
  );
}

class _DialogoUnirse extends StatefulWidget {
  const _DialogoUnirse();

  @override
  State<_DialogoUnirse> createState() => _DialogoUnirseState();
}

class _DialogoUnirseState extends State<_DialogoUnirse> {
  final _codigo = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _aceptar() {
    if (codigoSalaCompleto(_codigo.text)) {
      Navigator.of(context).pop(_codigo.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unirme con código'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Escribe el código de 6 caracteres que te compartieron.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo-codigo-sala'),
            controller: _codigo,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: const [FormateadorCodigoSala()],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _aceptar(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              hintText: 'ABC234',
              counterText: '${_codigo.text.length}/$largoCodigoSala',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar-unirse'),
          onPressed: codigoSalaCompleto(_codigo.text) ? _aceptar : null,
          child: const Text('Unirme'),
        ),
      ],
    );
  }
}
