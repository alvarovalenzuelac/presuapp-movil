import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_config.dart';

class CategoriaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? categoria; // Si viene llena, es EDITAR. Si es null, es CREAR.
  final int? padreId; // Si viene lleno, estamos creando una HIJA.

  const CategoriaFormScreen({super.key, this.categoria, this.padreId});

  @override
  State<CategoriaFormScreen> createState() => _CategoriaFormScreenState();
}

class _CategoriaFormScreenState extends State<CategoriaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final storage = const FlutterSecureStorage();
  
  // ⚠️ TU URL BASE
  final String baseUrl = ApiConfig.baseUrl; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Si estamos editando, rellenamos el campo con el nombre actual
    if (widget.categoria != null) {
      _nombreController.text = widget.categoria!['nombre'];
    }
  }

  Future<void> _guardarCategoria() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final token = await storage.read(key: 'access_token');
    
    final bool esEdicion = widget.categoria != null;
    
    final url = esEdicion 
      ? Uri.parse('$baseUrl/api/v1/categorias/${widget.categoria!['id']}/')
      : Uri.parse('$baseUrl/api/v1/categorias/');

    final Map<String, dynamic> bodyData = {
      "nombre": _nombreController.text,
      "categoria_padre": esEdicion ? widget.categoria!['categoria_padre'] : widget.padreId,
      "tipo": "GASTO" 
    };

    try {
      final response = esEdicion
          ? await http.patch(url, headers: _headers(token), body: jsonEncode(bodyData))
          : await http.post(url, headers: _headers(token), body: jsonEncode(bodyData));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // --- MEJORA: Decodificar el error del backend ---
        // Django suele responder: {"nombre": ["El mensaje de error"]}
        String mensajeError = "Ocurrió un error al guardar";
        
        try {
          final errors = jsonDecode(utf8.decode(response.bodyBytes)); // utf8 para acentos
          if (errors is Map) {
            // Buscamos si hay error en el campo 'nombre' o error general
            if (errors.containsKey('nombre')) {
              mensajeError = errors['nombre'][0];
            } else if (errors.containsKey('non_field_errors')) {
              mensajeError = errors['non_field_errors'][0];
            } else if (errors.containsKey('detail')) {
              mensajeError = errors['detail'];
            }
          }
        } catch (_) {
          mensajeError = "Error: ${response.statusCode}";
        }
        
        _mostrarError(mensajeError);
      }
    } catch (e) {
      _mostrarError("Error de conexión: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, String> _headers(String? token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.categoria != null;
    final esHija = widget.padreId != null || (esEdicion && widget.categoria!['categoria_padre'] != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? "Editar Categoría" : (esHija ? "Nueva Subcategoría" : "Nueva Categoría")),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre de la categoría",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Por favor ingresa un nombre';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarCategoria,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Guardar", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}