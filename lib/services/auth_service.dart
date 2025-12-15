import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class AuthService {
  // ⚠️ IMPORTANTE: Pon aquí tu URL de Google Cloud Run (sin la barra final /)
  final String baseUrl = ApiConfig.baseUrl; 
  
  // Instancia para guardar datos seguros
  final storage = const FlutterSecureStorage();

  // Función de Login
  Future<bool> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/token/');
    
    try {
      final response = await http.post(
        url,
        body: {
          'email': email,      // Tu backend espera 'email' (según configuramos)
          'password': password
        },
      );

      if (response.statusCode == 200) {
        // Si Django dice OK, decodificamos el JSON
        final data = jsonDecode(response.body);
        
        // Guardamos los tokens en el celular de forma encriptada
        await storage.write(key: 'access_token', value: data['access']);
        await storage.write(key: 'refresh_token', value: data['refresh']);
        
        return true; // Login exitoso
      } else {
        print("Error Login: ${response.body}");
        return false; // Credenciales malas
      }
    } catch (e) {
      print("Error de conexión: $e");
      return false;
    }
  }

  // Función para cerrar sesión (Borrar tokens)
  Future<void> logout() async {
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
  }
  
  // Verificar si hay token guardado
  Future<String?> getToken() async {
    return await storage.read(key: 'access_token');
  }
}