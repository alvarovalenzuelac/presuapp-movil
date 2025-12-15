import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'gastos_screen.dart'; // <--- Importamos tu nueva pantalla
import 'categorias_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Controla qué pestaña está activa (0: Inicio, 1: Gastos...)

  // AQUÍ ESTÁ LA LISTA DE PANTALLAS
  final List<Widget> _screens = [
    const Center(child: Text("Dashboard (Próximamente)")), // Index 0
    const GastosScreen(),                                   // Index 1: TU PANTALLA DE GASTOS REAL
    const Center(child: Text("Presupuestos (Próximamente)")), // Index 2
    const CategoriasScreen(),   // Index 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PresuApp", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Botón Salir
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await AuthService().logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (context) => const LoginScreen())
                );
              }
            },
          )
        ],
      ),
      
      // EL CUERPO CAMBIA SEGÚN LA PESTAÑA SELECCIONADA
      body: _screens[_currentIndex],

      // BARRA DE NAVEGACIÓN INFERIOR
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green, // Color del ícono activo
        unselectedItemColor: Colors.grey, // Color de inactivos
        type: BottomNavigationBarType.fixed, // Necesario si hay más de 3 items
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Inicio",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long), // Icono de recibo para Gastos
            label: "Gastos",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.savings),
            label: "Metas",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: "Categ.",
          ),
        ],
      ),
    );
  }
}