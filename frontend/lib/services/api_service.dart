import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String baseUrl = 'https://your-railway-url';

  static Future<Map<String, dynamic>> deployBot(String repoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user!.getIdToken();
    final response = await http.post(
      Uri.parse('$baseUrl/bots/deploy'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'repo_url': repoUrl}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> uploadFiles(String botId, String botFilePath, String reqFilePath) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user!.getIdToken();
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/bots/upload/$botId'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('bot_file', botFilePath));
    request.files.add(await http.MultipartFile.fromPath('req_file', reqFilePath));
    final response = await request.send();
    return jsonDecode(await response.stream.bytesToString());
  }

  static Future<Map<String, dynamic>> stopBot(String botId) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user!.getIdToken();
    final response = await http.post(
      Uri.parse('$baseUrl/bots/$botId/stop'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> restartBot(String botId) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user!.getIdToken();
    final response = await http.post(
      Uri.parse('$baseUrl/bots/$botId/restart'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getStats(String botId) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user!.getIdToken();
    final response = await http.get(
      Uri.parse('$baseUrl/bots/$botId/stats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }
}