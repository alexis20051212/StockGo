import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'core/theme.dart';
import 'repositories/repositories.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  // Si el servidor responde 401, se regresa al inicio de sesión
  ApiClient.onUnauthorized = () => navigatorKey.currentState
      ?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  runApp(const StockGoApp());
}

class StockGoApp extends StatelessWidget {
  const StockGoApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (_, __) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'StockGo',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeController.instance.mode,
        home: FutureBuilder<bool>(
          future: AuthRepository().isLogged(),
          builder: (_, s) {
            if (!s.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            return s.data! ? const HomeScreen() : const LoginScreen();
          },
        ),
      ));
}
