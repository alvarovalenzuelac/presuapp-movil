import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart'; // Librería de gráficos
import '../services/api_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final storage = const FlutterSecureStorage();
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _fetchDashboardData();
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final token = await storage.read(key: 'access_token');
    final url = ApiConfig.uri('/api/v1/dashboard-data/'); // Endpoint nuevo
    
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error cargando dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("Sin datos"));
          }

          final data = snapshot.data!;
          final totales = data['totales'];
          final List<dynamic> torta = data['grafico_torta'];
          final List<dynamic> linea = data['grafico_linea'];

          return RefreshIndicator(
            onRefresh: () async => setState(() => _dashboardFuture = _fetchDashboardData()),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Resumen del Mes", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // 1. TARJETAS DE TOTALES
                  Row(
                    children: [
                      // CAMBIO: Mostramos Presupuesto Global (Azul) en vez de Ingresos
                      _buildCard(
                        "Presupuesto Global", 
                        totales['presupuesto_global'] ?? 0, 
                        Colors.blueAccent
                      ),
                      const SizedBox(width: 12),
                      _buildCard("Gastos", totales['gastos'], Colors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // CAMBIO: El saldo ahora refleja lo disponible del presupuesto
                  _buildCard(
                    "Disponible del Global", 
                    totales['saldo'], 
                    (totales['saldo'] ?? 0) < 0 ? Colors.black : Colors.green, // Negro si es negativo
                    fullWidth: true
                  ),
                  const SizedBox(height: 12),
                  _buildCard("Saldo Disponible", totales['saldo'], Colors.blue, fullWidth: true),
                  
                  const SizedBox(height: 24),

                  // 2. GRÁFICO DE TORTA (Gastos por Categoría)
                  const Text("Gastos por Categoría", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: torta.isEmpty 
                      ? const Center(child: Text("Sin gastos registrados"))
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: _crearSeccionesTorta(torta),
                          ),
                        ),
                  ),

                  const SizedBox(height: 24),

                  // 3. GRÁFICO DE LÍNEA (Evolución Diaria)
                  const Text("Evolución Diaria", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false), // Ocultamos ejes para diseño limpio
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _crearPuntosLinea(linea),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget auxiliar para Tarjetas
  Widget _buildCard(String title, dynamic amount, Color color, {bool fullWidth = false}) {
    return Expanded(
      flex: fullWidth ? 0 : 1,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              "\$${double.parse(amount.toString()).toStringAsFixed(0)}",
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _crearSeccionesTorta(List<dynamic> datos) {
    // Colores simples para las categorías
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    
    return List.generate(datos.length, (i) {
      final item = datos[i];
      final double valor = double.parse(item['value'].toString());
      
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: valor,
        title: '${item['name']}\n${valor.toStringAsFixed(0)}',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });
  }

  List<FlSpot> _crearPuntosLinea(List<dynamic> datos) {
    return List.generate(datos.length, (index) {
      return FlSpot(index.toDouble(), double.parse(datos[index].toString()));
    });
  }
}