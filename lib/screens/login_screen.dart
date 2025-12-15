import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart'; // Crearemos esto en el siguiente mensaje

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores para leer lo que escribe el usuario
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);

    // Llamamos a tu API en la nube
    bool success = await _authService.login(
      _emailController.text, 
      _passController.text
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      // Si funcionó, vamos al Home
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const HomeScreen())
      );
    } else if (mounted) {
      // Si falló, mostramos alerta
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credenciales incorrectas o error de conexión'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50, // Fondo verde suave
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono
                const Icon(Icons.account_balance_wallet, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                
                // Título
                Text(
                  "PresuApp Móvil", 
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.green.shade800
                  )
                ),
                const SizedBox(height: 40),

                // Campo Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Correo Electrónico",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                    filled: true,
                    fillColor: Colors.white
                  ),
                ),
                const SizedBox(height: 20),

                // Campo Password
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Contraseña",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    filled: true,
                    fillColor: Colors.white
                  ),
                ),
                const SizedBox(height: 30),

                // Botón Ingresar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, // Botón verde
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        child: const Text(
                          "Ingresar", 
                          style: TextStyle(fontSize: 18, color: Colors.white)
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}