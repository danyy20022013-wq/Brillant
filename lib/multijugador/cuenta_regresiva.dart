import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Segundos que quedan de [total], contados desde [desde].
int segundosRestantes(Duration total, DateTime desde, DateTime ahora) {
  final falta = total - ahora.difference(desde);
  return max(0, (falta.inMilliseconds / 1000).ceil());
}

/// "42 s" o "14:59".
String formatoSegundos(int segundos) {
  if (segundos < 60) return '$segundos s';
  final m = segundos ~/ 60;
  final s = (segundos % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Cuenta regresiva que se actualiza sola cada segundo. Parte de lo que
/// dijo el servidor ([total] desde [desde], el momento en que llegó) y no
/// depende del reloj del servidor.
class CuentaRegresiva extends StatefulWidget {
  final Duration total;
  final DateTime desde;
  final DateTime Function() reloj;
  final Widget Function(BuildContext context, int segundos) constructor;

  const CuentaRegresiva({
    super.key,
    required this.total,
    required this.desde,
    required this.reloj,
    required this.constructor,
  });

  @override
  State<CuentaRegresiva> createState() => _CuentaRegresivaState();
}

class _CuentaRegresivaState extends State<CuentaRegresiva> {
  Timer? _timer;
  late int _segundos;

  int _calcular() =>
      segundosRestantes(widget.total, widget.desde, widget.reloj());

  @override
  void initState() {
    super.initState();
    _segundos = _calcular();
    _programar();
  }

  @override
  void didUpdateWidget(CuentaRegresiva anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.total != widget.total || anterior.desde != widget.desde) {
      _segundos = _calcular();
      _programar();
    }
  }

  void _programar() {
    _timer?.cancel();
    if (_segundos <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final nuevo = _calcular();
      if (nuevo != _segundos) setState(() => _segundos = nuevo);
      if (nuevo <= 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.constructor(context, _segundos);
}
