import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';
import 'campos_auth.dart';
import 'registro_screen.dart';
import 'validaciones.dart';

const _fondo = Color(0xFF14162B);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthCubit>().iniciarSesion(
      correo: _correo.text.trim(),
      contrasena: _contrasena.text,
    );
  }

  void _irARegistro() {
    final cubit = context.read<AuthCubit>();
    cubit.limpiarError();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegistroScreen()))
        .then((_) => cubit.limpiarError());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BlocBuilder<AuthCubit, AuthEstado>(
                builder: (context, estado) {
                  final cargando = estado is AuthSinSesion && estado.cargando;
                  final error = estado is AuthSinSesion ? estado.error : null;

                  return Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'BRILLIANT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Entra para buscar una partida',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          key: const Key('campo-correo'),
                          controller: _correo,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
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
                          accion: TextInputAction.done,
                          alEnviar: (_) => _enviar(),
                        ),
                        if (error != null)
                          AvisoErrorAuth(
                            error: error,
                            sinServidor:
                                estado is AuthSinSesion && estado.sinServidor,
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
                                : const Text('Iniciar sesión'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              '¿No tienes cuenta?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextButton(
                              onPressed: cargando ? null : _irARegistro,
                              child: const Text('Crear cuenta'),
                            ),
                          ],
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
    );
  }
}
