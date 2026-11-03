import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';
import 'auth_repository.dart';
import 'buscar_partida_screen.dart';
import 'login_screen.dart';

void main() {
  runApp(const BrilliantApp());
}

class BrilliantApp extends StatelessWidget {
  /// Dónde viven las cuentas. Por defecto, en memoria.
  final AuthRepository? repositorio;

  const BrilliantApp({super.key, this.repositorio});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(repositorio ?? InMemoryAuthRepository()),
      child: MaterialApp(
        title: 'Brilliant',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8E5CF0),
            brightness: Brightness.dark,
          ),
        ),
        home: const _Puerta(),
      ),
    );
  }
}

/// Sin sesión muestra el inicio de sesión; con sesión, Buscar partida.
class _Puerta extends StatelessWidget {
  const _Puerta();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthEstado>(
      builder: (context, estado) {
        if (estado is AuthConSesion) {
          return BuscarPartidaScreen(
            usuario: estado.usuario,
            alCerrarSesion: () => context.read<AuthCubit>().cerrarSesion(),
          );
        }
        return const LoginScreen();
      },
    );
  }
}