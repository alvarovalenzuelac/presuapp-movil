import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../services/api_config.dart';

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
  
  // LISTAS DE DATOS
  List<dynamic> _padres = [];              // Solo categorías Padre
  List<dynamic> _todasSubcategorias = [];  // Todas las hijas disponibles
  List<dynamic> _subcategoriasFiltradas = []; // Las que mostramos en el 2do dropdown

  // SELECCIONES
  String? _selectedPadreId;
  String? _selectedSubcategoriaId;

  @override
  void initState() {
    super.initState();
    _fechaController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _cargarDatosIniciales();
  }

  // 1. Cargar Categorías y separar Padres/Hijos
  Future<void> _cargarDatosIniciales() async {
    final token = await storage.read(key: 'access_token');
    try {
      final response = await http.get(
        ApiConfig.uri('/api/v1/categorias/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> datos = jsonDecode(response.body); // utf8 si es necesario
        
        setState(() {
          // A. Filtramos los Padres (categoria_padre == null)
          _padres = datos.where((c) => c['categoria_padre'] == null).toList();
          
          // B. Guardamos todas las Hijas (categoria_padre != null) para filtrar después
          _todasSubcategorias = datos.where((c) => c['categoria_padre'] != null).toList();
        });
      }
    } catch (e) {
      debugPrint("Error cargando categorías: $e");
    }
  }

  // 2. Lógica al seleccionar un Padre
  void _onPadreChanged(String? nuevoPadreId) {
    setState(() {
      _selectedPadreId = nuevoPadreId;
      
      // Reiniciamos la subcategoría porque cambió el grupo
      _selectedSubcategoriaId = null;
      
      // Filtramos: Mostramos solo las hijas que pertenezcan a este padre ID
      if (nuevoPadreId != null) {
        _subcategoriasFiltradas = _todasSubcategorias.where((hijo) {
          // La API devuelve números, convertimos a String para comparar seguro
          return hijo['categoria_padre'].toString() == nuevoPadreId;
        }).toList();
      } else {
        _subcategoriasFiltradas = [];
      }
    });
  }

  // 3. Guardar Gasto
  Future<void> _guardarGasto() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedSubcategoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar una subcategoría final'))
      );
      return;
    }

    setState(() => _isLoading = true);
    final token = await storage.read(key: 'access_token');

    final bodyData = {
      "tipo": "GASTO",
      "monto": _montoController.text,
      "descripcion": _descController.text,
      "fecha": _fechaController.text,
      "categoria": _selectedSubcategoriaId // Enviamos el ID de la hija
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
        if (mounted) Navigator.pop(context, true);
      } else {
        // Manejo de error simple
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error: ${response.body}"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Error de conexión"))
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Gasto"), 
        backgroundColor: Colors.green, 
        foregroundColor: Colors.white
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --- MONTO ---
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
                  if (double.tryParse(value)! <= 0) return 'El monto debe ser positivo';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- FECHA ---
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

              // --- DROPDOWN 1: CATEGORÍA PADRE (Filtro) ---
              DropdownButtonFormField<String>(
                value: _selectedPadreId,
                decoration: const InputDecoration(
                  labelText: "Categoría Principal",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                ),
                hint: const Text("Ej: Comida, Vivienda..."),
                items: _padres.map<DropdownMenuItem<String>>((cat) {
                  return DropdownMenuItem(
                    value: cat['id'].toString(),
                    child: Text(cat['nombre']),
                  );
                }).toList(),
                onChanged: _onPadreChanged, // Llamamos a nuestra función de filtro
              ),
              const SizedBox(height: 16),

              // --- DROPDOWN 2: SUBCATEGORÍA (Selección Final) ---
              DropdownButtonFormField<String>(
                value: _selectedSubcategoriaId,
                // Si no hay padre seleccionado, deshabilitamos este campo visualmente
                decoration: InputDecoration(
                  labelText: "Subcategoría",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                  enabled: _selectedPadreId != null, // Deshabilitado si es null
                  filled: _selectedPadreId == null,
                  fillColor: Colors.grey[200],
                ),
                hint: Text(_selectedPadreId == null 
                    ? "Selecciona primero la principal" 
                    : "Selecciona una opción..."),
                // Usamos la lista FILTRADA
                items: _subcategoriasFiltradas.map<DropdownMenuItem<String>>((cat) {
                  return DropdownMenuItem(
                    value: cat['id'].toString(),
                    child: Text(cat['nombre']),
                  );
                }).toList(),
                onChanged: _selectedPadreId == null 
                    ? null // Bloqueamos interacción si no hay padre
                    : (val) => setState(() => _selectedSubcategoriaId = val),
              ),
              const SizedBox(height: 16),

              // --- DESCRIPCIÓN ---
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: "Descripción (Opcional)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 24),

              // --- BOTÓN ---
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