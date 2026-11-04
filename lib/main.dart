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
      // Al abrir, se comprueba si hay una sesión guardada.
      create: (_) =>
          AuthCubit(repositorio ?? InMemoryAuthRepository())..iniciar(),
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

/// Mientras se comprueba la sesión muestra una espera; sin sesión, el inicio
/// de sesión; con sesión, Buscar partida.
class _Puerta extends StatelessWidget {
  const _Puerta();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthEstado>(
      builder: (context, estado) {
        return switch (estado) {
          AuthComprobando() => const PantallaComprobandoSesion(),
          AuthConSesion(:final usuario) => BuscarPartidaScreen(
            usuario: usuario,
            alCerrarSesion: () => context.read<AuthCubit>().cerrarSesion(),
          ),
          AuthSinSesion() => const LoginScreen(),
        };
      },
    );
  }
}

/// Pantalla breve al abrir la app, mientras se comprueba la sesión guardada.
class PantallaComprobandoSesion extends StatelessWidget {
  const PantallaComprobandoSesion({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF14162B),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Comprobando tu sesión…',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
