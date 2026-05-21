import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';

class ApiService extends ChangeNotifier {
  String baseUrl = 'https://shrayyyy-vetderm-ai.hf.space';
  bool isLoading = false;
  String? error;
  AnalysisResult? result;

  Future<void> analyzeCase({
    File? image,
    String description = '',
    String breed = '',
    String age = '',
  }) async {
    isLoading = true;
    error = null;
    result = null;
    notifyListeners();

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));

      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      request.fields['description'] = description;
      request.fields['breed'] = breed;
      request.fields['age'] = age;

      final response = await request.send().timeout(const Duration(seconds: 120));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        result = AnalysisResult.fromJson(jsonDecode(responseBody));
      } else {
        error = 'Server error: ${response.statusCode}';
      }
    } on SocketException {
      error = 'No internet connection';
    } on HttpException {
      error = 'Connection error';
    } on FormatException {
      error = 'Invalid response from server';
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    result = null;
    error = null;
    isLoading = false;
    notifyListeners();
  }
}
