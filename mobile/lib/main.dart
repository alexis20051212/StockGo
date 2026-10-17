import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'core/theme.dart';
import 'repositories/repositories.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Si el servidor responde 401, se regresa al inicio de sesión
  ApiClient.onUnauthorized = () => navigatorKey.currentState
      ?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  runApp(const StockGoApp());
}

class StockGoApp extends StatelessWidget {
  const StockGoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'StockGo',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: FutureBuilder<bool>(
          future: AuthRepository().isLogged(),
          builder: (_, s) {
            if (!s.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            return s.data! ? const HomeScreen() : const LoginScreen();
          },
        ),
      );
}
