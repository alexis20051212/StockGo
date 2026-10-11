import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'repositories/repositories.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() => runApp(const StockGoApp());

class StockGoApp extends StatelessWidget {
  const StockGoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
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
