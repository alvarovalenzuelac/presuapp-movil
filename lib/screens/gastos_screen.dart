import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Importamos la configuración centralizada y la pantalla de formulario
import '../services/api_config.dart'; 
import 'gasto_form_screen.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final storage = const FlutterSecureStorage();
  
  // Variable para guardar el futuro (la promesa de datos)
  late Future<List<dynamic>> _gastosFuture;

  @override
  void initState() {
    super.initState();
    _gastosFuture = _fetchGastos();
  }

  // Función para obtener los gastos desde la API
  Future<List<dynamic>> _fetchGastos() async {
    final token = await storage.read(key: 'access_token');
    
    // Usamos ApiConfig para la URL
    final url = ApiConfig.uri('/api/v1/transacciones/');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al cargar gastos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // --- NUEVA FUNCIÓN: Navegar a la pantalla de agregar ---
  void _navegarAgregarGasto() async {
    // Navigator.push espera a que la pantalla nueva se cierre
    // y guarda lo que esa pantalla devuelva en 'resultado'
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GastoFormScreen()),
    );

    // Si la pantalla devolvió 'true' (éxito), recargamos la lista
    if (resultado == true) {
      setState(() {
        _gastosFuture = _fetchGastos();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gasto registrado correctamente"),
            backgroundColor: Colors.green,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<List<dynamic>>(
        future: _gastosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("Ocurrió un error: ${snapshot.error}", textAlign: TextAlign.center),
              )
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No hay movimientos aún"),
                ],
              ),
            );
          }

          final gastos = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: gastos.length,
            itemBuilder: (context, index) {
              final item = gastos[index];
              final esGasto = item['tipo'] == 'GASTO';
              
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esGasto ? Colors.red.shade50 : Colors.green.shade50,
                    child: Icon(
                      esGasto ? Icons.arrow_downward : Icons.arrow_upward,
                      color: esGasto ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(
                    item['descripcion'] != null && item['descripcion'].toString().isNotEmpty 
                        ? item['descripcion'] 
                        : 'Sin descripción',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${item['fecha']} • ${item['categoria_nombre'] ?? 'General'}",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Text(
                    "${esGasto ? '-' : ''}\$${item['monto']}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: esGasto ? Colors.red[700] : Colors.green[700],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      
      // --- BOTÓN ACTUALIZADO ---
      floatingActionButton: FloatingActionButton(
        onPressed: _navegarAgregarGasto, // Llamamos a la función nueva
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}