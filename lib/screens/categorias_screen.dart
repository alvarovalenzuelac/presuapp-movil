import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'categoria_form_screen.dart'; // Asegúrate de que este archivo existe en tu carpeta screens
import '../services/api_config.dart';

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final storage = const FlutterSecureStorage();
  
  // ⚠️ TU URL DE GOOGLE CLOUD
  final String baseUrl = ApiConfig.baseUrl; 
  
  late Future<List<dynamic>> _categoriasFuture;

  @override
  void initState() {
    super.initState();
    _recargarLista();
  }

  void _recargarLista() {
    setState(() {
      _categoriasFuture = _fetchCategorias();
    });
  }

  Future<List<dynamic>> _fetchCategorias() async {
    final token = await storage.read(key: 'access_token');
    final url = Uri.parse('$baseUrl/api/v1/categorias/');
    
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
      throw Exception('Error al cargar categorías');
    }
  }

  // --- LÓGICA PARA ELIMINAR ---
  Future<void> _eliminarCategoria(int id) async {
    final confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar categoría?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text("Cancelar")
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Eliminar", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final token = await storage.read(key: 'access_token');
      final url = Uri.parse('$baseUrl/api/v1/categorias/$id/');
      
      try {
        final response = await http.delete(
          url, 
          headers: {'Authorization': 'Bearer $token'}
        );

        if (response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Eliminado correctamente"))
          );
          _recargarLista();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al eliminar. Código: ${response.statusCode}"))
          );
        }
      } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error de conexión: $e"))
          );
      }
    }
  }

  // --- NAVEGACIÓN AL FORMULARIO ---
  void _irAlFormulario({Map<String, dynamic>? categoria, int? padreId}) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoriaFormScreen(
          categoria: categoria, 
          padreId: padreId
        ),
      ),
    );

    if (resultado == true) {
      _recargarLista();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Guardado exitosamente"))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<List<dynamic>>(
        future: _categoriasFuture,
        builder: (context, snapshot) {
          // 1. Estado de Carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          } 
          // 2. Estado de Error
          else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } 
          // 3. Estado Vacío
          else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No hay categorías disponibles"));
          }

          // 4. Procesamiento de Datos
          final todas = snapshot.data!;
          // Filtramos solo los padres (los que no tienen padre asignado)
          final padres = todas.where((c) => c['categoria_padre'] == null).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: padres.length,
            itemBuilder: (context, index) {
              final padre = padres[index];
              
              // Buscamos los hijos de este padre
              final hijos = todas.where((c) => c['categoria_padre'] == padre['id']).toList();

              // --- AQUÍ ESTÁ LA MAGIA DE LA SEGURIDAD ---
              // Si 'usuario' es null, asumimos que es del sistema (solo lectura)
              // Si 'usuario' tiene un ID, es tuya (editable)
              bool esPadreEditable = padre['usuario'] != null;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ExpansionTile(
                  // Icono: Folder verde si es tuyo, Candado gris si es sistema
                  leading: CircleAvatar(
                    backgroundColor: esPadreEditable ? Colors.green : Colors.grey[400],
                    child: Icon(
                      esPadreEditable ? Icons.folder : Icons.lock, 
                      color: Colors.white
                    ),
                  ),
                  title: Text(
                    padre['nombre'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: esPadreEditable ? Colors.black : Colors.grey[700]
                    ),
                  ),
                  subtitle: Text("${hijos.length} subcategorías"),
                  
                  // MENÚ DEL PADRE (Solo aparece si es editable)
                  trailing: esPadreEditable 
                    ? PopupMenuButton(
                        onSelected: (val) {
                          if (val == 'edit') _irAlFormulario(categoria: padre);
                          if (val == 'delete') _eliminarCategoria(padre['id']);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Text("Editar Padre")),
                          const PopupMenuItem(
                            value: 'delete', 
                            child: Text("Eliminar Padre", style: TextStyle(color: Colors.red))
                          ),
                        ],
                      )
                    : const Icon(Icons.lock_outline, color: Colors.grey, size: 16), // Candadito visual

                  children: [
                    // LISTA DE HIJOS
                    ...hijos.map((hijo) {
                      // Revisamos si el hijo es editable
                      bool esHijaEditable = hijo['usuario'] != null;

                      return ListTile(
                        contentPadding: const EdgeInsets.only(left: 30, right: 10),
                        leading: Icon(
                          Icons.subdirectory_arrow_right, 
                          color: esHijaEditable ? Colors.grey : Colors.grey[300]
                        ),
                        title: Text(
                          hijo['nombre'],
                          style: TextStyle(
                            color: esHijaEditable ? Colors.black : Colors.grey
                          ),
                        ),
                        // BOTONES DE ACCIÓN PARA EL HIJO
                        trailing: esHijaEditable 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  onPressed: () => _irAlFormulario(categoria: hijo),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _eliminarCategoria(hijo['id']),
                                ),
                              ],
                            )
                          : null, // Si no es editable, no mostramos nada a la derecha
                      );
                    }),

                    // BOTÓN SIEMPRE VISIBLE: Agregar nueva subcategoría (incluso en padres de sistema)
                    ListTile(
                      leading: const Icon(Icons.add, color: Colors.green),
                      title: Text(
                        "Nueva subcategoría en ${padre['nombre']}",
                        style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                      ),
                      onTap: () => _irAlFormulario(padreId: padre['id']),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

    );
  }
}