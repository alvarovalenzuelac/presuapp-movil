import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_config.dart';

class MetaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? meta;

  const MetaFormScreen({super.key, this.meta});

  @override
  State<MetaFormScreen> createState() => _MetaFormScreenState();
}

class _MetaFormScreenState extends State<MetaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final storage = const FlutterSecureStorage();
  
  final _nombreController = TextEditingController();
  final _montoController = TextEditingController();
  
  bool _isLoading = false;
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;
  
  // DATOS PARA EL ACORDEÓN
  List<dynamic> _padres = [];
  List<dynamic> _todosHijos = []; // Lista plana de todos los hijos
  
  // Set para guardar IDs seleccionados
  final Set<int> _categoriasSeleccionadas = {};

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    
    if (widget.meta != null) {
      _nombreController.text = widget.meta!['nombre'];
      _montoController.text = double.parse(widget.meta!['monto_limite'].toString()).toStringAsFixed(0);
      _mesSeleccionado = widget.meta!['mes'];
      _anioSeleccionado = widget.meta!['anio'];
      
      if (widget.meta!['categorias'] != null) {
        for (var catId in widget.meta!['categorias']) {
          _categoriasSeleccionadas.add(catId);
        }
      }
    }
  }

  Future<void> _cargarCategorias() async {
    final token = await storage.read(key: 'access_token');
    try {
      final response = await http.get(
        ApiConfig.uri('/api/v1/categorias/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> todas = jsonDecode(response.body); // utf8.decode si hace falta
        setState(() {
          // Separamos Padres e Hijos
          _padres = todas.where((c) => c['categoria_padre'] == null).toList();
          _todosHijos = todas.where((c) => c['categoria_padre'] != null).toList();
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _guardarMeta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final token = await storage.read(key: 'access_token');
    
    final bool esEdicion = widget.meta != null;
    final url = esEdicion
        ? ApiConfig.uri('/api/v1/presupuestos/${widget.meta!['id']}/')
        : ApiConfig.uri('/api/v1/presupuestos/');

    final Map<String, dynamic> bodyData = {
      "nombre": _nombreController.text,
      "monto_limite": _montoController.text,
      "mes": _mesSeleccionado,
      "anio": _anioSeleccionado,
      "categorias": _categoriasSeleccionadas.toList(),
    };

    try {
      final response = esEdicion
          ? await http.patch(url, headers: _headers(token), body: jsonEncode(bodyData))
          : await http.post(url, headers: _headers(token), body: jsonEncode(bodyData));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: ${response.body}"), backgroundColor: Colors.red
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error de conexión")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, String> _headers(String? token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.meta != null ? "Editar Meta" : "Nueva Meta"), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: "Nombre", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Monto Límite", prefixText: "\$ ", border: OutlineInputBorder()),
                validator: (v) => (double.tryParse(v ?? '0') ?? 0) <= 0 ? 'Monto inválido' : null,
              ),
              const SizedBox(height: 16),
              
              // Selector Mes/Año (Simplificado)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _mesSeleccionado,
                      items: List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text("${i+1}"))),
                      onChanged: (v) => setState(() => _mesSeleccionado = v!),
                      decoration: const InputDecoration(labelText: "Mes", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _anioSeleccionado,
                      items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year + i, child: Text("${DateTime.now().year + i}"))),
                      onChanged: (v) => setState(() => _anioSeleccionado = v!),
                      decoration: const InputDecoration(labelText: "Año", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- ACORDEÓN DE CATEGORÍAS ---
              const Text("Categorías (Deja vacío para Global)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              if (_padres.isEmpty) 
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
              else
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: _padres.map((padre) {
                      // Filtramos los hijos que pertenecen a este padre
                      final hijosDelPadre = _todosHijos.where((h) => h['categoria_padre'] == padre['id']).toList();
                      
                      return ExpansionTile(
                        leading: const Icon(Icons.folder_open, color: Colors.green),
                        title: Text(padre['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        children: hijosDelPadre.map((hijo) {
                          final int id = hijo['id'];
                          final bool isSelected = _categoriasSeleccionadas.contains(id);
                          
                          return CheckboxListTile(
                            contentPadding: const EdgeInsets.only(left: 40, right: 20),
                            title: Text(hijo['nombre']),
                            value: isSelected,
                            activeColor: Colors.green,
                            dense: true,
                            onChanged: (bool? valor) {
                              setState(() {
                                if (valor == true) _categoriasSeleccionadas.add(id);
                                else _categoriasSeleccionadas.remove(id);
                              });
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarMeta,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Guardar", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}