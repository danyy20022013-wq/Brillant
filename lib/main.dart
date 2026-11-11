import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'almacen_sesion.dart';
import 'api_auth_repository.dart';
import 'auth_cubit.dart';
import 'auth_repository.dart';
import 'buscar_partida_screen.dart';
import 'login_screen.dart';
import 'multijugador/canal_ws.dart';
import 'multijugador/conexion_multijugador.dart';
import 'multijugador/multijugador_cubit.dart';
import 'multijugador/pantalla_sala.dart';

void main() {
  runApp(const BrilliantApp());
}

/// Multijugador contra el servidor real: el WebSocket va a la misma
/// dirección que las cuentas y se autentica con el token de la sesión.
AbrirSala abrirSalaConServidor(ApiAuthRepository repositorio) =>
    (accion) => MultijugadorCubit(
      conexion: ConexionMultijugador(
        url: urlWebSocket(repositorio.urlBase),
        token: () async => repositorio.tokenActual,
      ),
      accionInicial: accion,
    );

class BrilliantApp extends StatefulWidget {
  /// Dónde viven las cuentas. Por defecto, el servidor de Brilliant (la
  /// dirección sale de --dart-define=API_URL) con la sesión guardada en
  /// flutter_secure_storage. Las pruebas pasan InMemoryAuthRepository.
  final AuthRepository? repositorio;

  /// Cómo abrir una sala en línea. Por defecto, con el servidor real si el
  /// repositorio es el del servidor; las pruebas pasan uno falso. Sin él no
  /// aparecen las opciones en línea.
  final AbrirSala? abrirSala;

  const BrilliantApp({super.key, this.repositorio, this.abrirSala});

  @override
  State<BrilliantApp> createState() => _BrilliantAppState();
}

class _BrilliantAppState extends State<BrilliantApp> {
  late final AuthRepository _repositorio =
      widget.repositorio ?? ApiAuthRepository(almacen: AlmacenSesionSegura());

  late final AbrirSala? _abrirSala =
      widget.abrirSala ??
      switch (_repositorio) {
        final ApiAuthRepository api => abrirSalaConServidor(api),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Al abrir, se comprueba si hay una sesión guardada.
      create: (_) => AuthCubit(_repositorio)..iniciar(),
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
        home: _Puerta(abrirSala: _abrirSala),
      ),
    );
  }
}

/// Mientras se comprueba la sesión muestra una espera; sin sesión, el inicio
/// de sesión; con sesión, Buscar partida.
class _Puerta extends StatelessWidget {
  final AbrirSala? abrirSala;

  const _Puerta({required this.abrirSala});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthEstado>(
      builder: (context, estado) {
        return switch (estado) {
          AuthComprobando() => const PantallaComprobandoSesion(),
          AuthConSesion(:final usuario) => BuscarPartidaScreen(
            usuario: usuario,
            alCerrarSesion: () => context.read<AuthCubit>().cerrarSesion(),
            alEliminarCuenta: context.read<AuthCubit>().borrarCuenta,
            abrirSala: abrirSala,
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
