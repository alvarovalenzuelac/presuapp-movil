import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Cuando trabajes en local, usa tu IP (ej: http://192.168.x.x:8000)
  // Cuando subas a prod, usa la de Cloud Run.
  static String get baseUrl => dotenv.env['API_URL'] ?? '';
  
  // Helper para armar URIs completos
  static Uri uri(String path) => Uri.parse('$baseUrl$path');
}