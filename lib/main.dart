import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // 1. Aseguramos que los motores de Flutter estén listos antes de ejecutar lógica
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  // 2. Revisamos si existe un token guardado
  const storage = FlutterSecureStorage();
  String? token = await storage.read(key: 'access_token');

  // 3. Decidimos qué pantalla mostrar
  Widget pantallaInicial = (token != null) ? const HomeScreen() : const LoginScreen();

  runApp(MyApp(pantallaInicial: pantallaInicial));
}

class MyApp extends StatelessWidget {
  final Widget pantallaInicial;

  const MyApp({super.key, required this.pantallaInicial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PresuApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      // Aquí usamos la pantalla que decidimos en el main
      home: pantallaInicial,
    );
  }
}