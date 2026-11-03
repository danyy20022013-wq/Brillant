import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';
import 'campos_auth.dart';
import 'validaciones.dart';

const _fondo = Color(0xFF14162B);

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthCubit>().registrar(
          nombre: _nombre.text.trim(),
          correo: _correo.text.trim(),
          contrasena: _contrasena.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthEstado>(
      // Al crear la cuenta se inicia sesión: se cierra esta pantalla y la
      // puerta de la app muestra Buscar partida.
      listenWhen: (anterior, actual) => actual is AuthConSesion,
      listener: (context, _) =>
          Navigator.of(context).popUntil((ruta) => ruta.isFirst),
      child: Scaffold(
        backgroundColor: _fondo,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocBuilder<AuthCubit, AuthEstado>(
                  builder: (context, estado) {
                    final cargando =
                        estado is AuthSinSesion && estado.cargando;
                    final error =
                        estado is AuthSinSesion ? estado.error : null;

                    return Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'BRILLIANT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Registro',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            key: const Key('campo-nombre'),
                            controller: _nombre,
                            textInputAction: TextInputAction.next,
                            validator: validarNombre,
                            decoration: decoracionCampo(
                              'Nombre de usuario',
                              Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('campo-correo'),
                            controller: _correo,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: validarCorreo,
                            decoration: decoracionCampo(
                              'Correo',
                              Icons.mail_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CampoContrasena(
                            key: const Key('campo-contrasena'),
                            controller: _contrasena,
                            validador: validarContrasena,
                          ),
                          const SizedBox(height: 14),
                          CampoContrasena(
                            key: const Key('campo-confirmacion'),
                            controller: _confirmacion,
                            etiqueta: 'Repite la contraseña',
                            validador: (valor) =>
                                validarConfirmacion(valor, _contrasena.text),
                            accion: TextInputAction.done,
                            alEnviar: (_) => _enviar(),
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                error,
                                key: const Key('error-auth'),
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(color: Color(0xFFFF6B6B)),
                              ),
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: cargando ? null : _enviar,
                              child: cargando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text('Registrarme'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: cargando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Ya tengo cuenta'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}