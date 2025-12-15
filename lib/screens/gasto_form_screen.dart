// lib/screens/gasto_form_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart'; // Agrega intl: ^0.18.0 en pubspec.yaml si no lo tienes
import '../services/api_config.dart'; // Importa tu nueva config

class GastoFormScreen extends StatefulWidget {
  const GastoFormScreen({super.key});

  @override
  State<GastoFormScreen> createState() => _GastoFormScreenState();
}

class _GastoFormScreenState extends State<GastoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _descController = TextEditingController();
  final _fechaController = TextEditingController();
  
  final storage = const FlutterSecureStorage();
  
  bool _isLoading = false;
  List<dynamic> _subcategorias = []; // Solo guardaremos hijas aquí
  String? _selectedCategoriaId;

  @override
  void initState() {
    super.initState();
    // Fecha de hoy por defecto
    _fechaController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _cargarSubcategorias();
  }

  // 1. Cargar Categorías desde la API
  Future<void> _cargarSubcategorias() async {
    final token = await storage.read(key: 'access_token');
    try {
      final response = await http.get(
        ApiConfig.uri('/api/v1/categorias/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> todas = jsonDecode(response.body);
        setState(() {
          // FILTRO: Solo mostramos las que tienen padre (Hijas)
          // Esto evita que el usuario seleccione "Comida" en general, forzando "Comida > Supermercado"
          _subcategorias = todas.where((c) => c['categoria_padre'] != null).toList();
        });
      }
    } catch (e) {
      print("Error cargando categorías: $e");
    }
  }

  // 2. Guardar Gasto
  Future<void> _guardarGasto() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una categoría'))
      );
      return;
    }

    setState(() => _isLoading = true);
    final token = await storage.read(key: 'access_token');

    final bodyData = {
      "tipo": "GASTO", // Por ahora fijo, luego puedes poner un switch Gasto/Ingreso
      "monto": _montoController.text,
      "descripcion": _descController.text,
      "fecha": _fechaController.text,
      "categoria": _selectedCategoriaId // Enviamos el ID
    };

    try {
      final response = await http.post(
        ApiConfig.uri('/api/v1/transacciones/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 201) {
        if (mounted) Navigator.pop(context, true); // Regresar con éxito
      } else {
        final err = jsonDecode(response.body);
        // Aquí mostramos el error que manda Django (ej: "Monto debe ser positivo")
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error: $err"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Error de conexión: $e"))
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Gasto"), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // CAMPO MONTO
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Monto",
                  prefixText: "\$ ",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa un monto';
                  // VALIDACIÓN FRONTEND: No permitir negativos
                  if (double.tryParse(value)! <= 0) return 'El monto debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SELECTOR DE FECHA
              TextFormField(
                controller: _fechaController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Fecha",
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    _fechaController.text = DateFormat('yyyy-MM-dd').format(picked);
                  }
                },
              ),
              const SizedBox(height: 16),

              // DROPDOWN CATEGORÍAS
              DropdownButtonFormField<String>(
                value: _selectedCategoriaId,
                decoration: const InputDecoration(
                  labelText: "Subcategoría",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _subcategorias.map<DropdownMenuItem<String>>((cat) {
                  return DropdownMenuItem(
                    value: cat['id'].toString(),
                    child: Text(cat['nombre']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoriaId = val),
              ),
              const SizedBox(height: 16),

              // CAMPO DESCRIPCIÓN
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: "Descripción (Opcional)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 24),

              // BOTÓN GUARDAR
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarGasto,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Guardar Gasto", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}