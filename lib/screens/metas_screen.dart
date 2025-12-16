import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_config.dart';
import 'meta_form_screen.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  final storage = const FlutterSecureStorage();
  late Future<List<dynamic>> _metasFuture;

  @override
  void initState() {
    super.initState();
    _recargarLista();
  }

  void _recargarLista() {
    setState(() {
      _metasFuture = _fetchMetas();
    });
  }

  Future<List<dynamic>> _fetchMetas() async {
    final token = await storage.read(key: 'access_token');
    final url = ApiConfig.uri('/api/v1/presupuestos/');
    
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error cargando metas');
    }
  }

  Future<void> _eliminarMeta(int id) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Meta?"),
        content: const Text("Esto no borrará tus gastos, solo el presupuesto."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      final token = await storage.read(key: 'access_token');
      await http.delete(
        ApiConfig.uri('/api/v1/presupuestos/$id/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      _recargarLista();
    }
  }

  void _irAlFormulario({Map<String, dynamic>? meta}) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MetaFormScreen(meta: meta)),
    );
    if (res == true) _recargarLista();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<List<dynamic>>(
        future: _metasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No tienes metas definidas."));
          }

          final metas = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: metas.length,
            itemBuilder: (context, index) {
              final meta = metas[index];
              
              // --- CORRECCIÓN AQUÍ ---
              // Usamos double.parse(...) y toString() para asegurar que funcione 
              // venga como String ("25000.00") o como número (25000)
              final double gastado = double.tryParse(meta['gastado'].toString()) ?? 0.0;
              final double limite = double.tryParse(meta['monto_limite'].toString()) ?? 0.0;
              final int porcentaje = meta['porcentaje'] ?? 0;
              
              // Color dinámico según el consumo
              Color colorBarra = Colors.green;
              if (porcentaje > 80) colorBarra = Colors.orange;
              if (porcentaje >= 100) colorBarra = Colors.red;

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              meta['nombre'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200)
                            ),
                            child: Text(
                              "${meta['mes']}/${meta['anio']}",
                              style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Barra de Progreso
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (porcentaje / 100).clamp(0.0, 1.0), // Asegurar que no pase de 1.0 visualmente
                          minHeight: 12,
                          backgroundColor: Colors.grey[200],
                          color: colorBarra,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Textos de montos
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Gastado: \$${gastado.toStringAsFixed(0)}", 
                               style: TextStyle(color: colorBarra, fontWeight: FontWeight.bold)),
                          Text("Meta: \$${limite.toStringAsFixed(0)}", 
                               style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Lista de categorías (chips)
                      if (meta['categorias_detalle'] != null && (meta['categorias_detalle'] as List).isNotEmpty)
                        Wrap(
                          spacing: 6,
                          children: (meta['categorias_detalle'] as List).take(3).map<Widget>((cat) {
                            return Chip(
                              label: Text(cat['nombre'], style: const TextStyle(fontSize: 10)),
                              backgroundColor: Colors.grey.shade200,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text("🌍 Presupuesto Global", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        ),

                      const Divider(height: 24),
                      
                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _irAlFormulario(meta: meta), 
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text("Editar"),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _eliminarMeta(meta['id']), 
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            label: const Text("Borrar", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _irAlFormulario(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}