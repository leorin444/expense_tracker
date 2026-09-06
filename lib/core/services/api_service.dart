import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Base custom exception for API calls
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException(super.message) : super(statusCode: 0);
}

class AuthException extends ApiException {
  AuthException(super.message, {super.statusCode = 401});
}

class ServerException extends ApiException {
  ServerException(super.message, {super.statusCode = 500, super.details});
}

class ClientException extends ApiException {
  ClientException(super.message, {super.statusCode = 400, super.details});
}

class ApiService {
  static const Duration timeoutDuration = Duration(seconds: 15);

  /// Swagger UI: https://api.raminshrestha.com.np/swagger/index.html
  static const String _apiBaseUrl = 'https://api.raminshrestha.com.np/api';

  /// Points to your domain endpoint (https://api.raminshrestha.com.np/api)
  static String get baseUrl => _apiBaseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    String? token;
    try {
      token = await user?.getIdToken();
    } catch (e) {
      debugPrint('Failed to get Firebase token: $e');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Check server connectivity and reachability
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _getHeaders(),
          )
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Cannot connect to server. Please check your internet or server status.');
    } on TimeoutException {
      throw NetworkException('Request timed out. Server took too long to respond.');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP connection failed: ${e.message}');
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _getHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Cannot connect to server. Please check your internet or server status.');
    } on TimeoutException {
      throw NetworkException('Request timed out. Server took too long to respond.');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP connection failed: ${e.message}');
    }
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _getHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Cannot connect to server. Please check your internet or server status.');
    } on TimeoutException {
      throw NetworkException('Request timed out. Server took too long to respond.');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP connection failed: ${e.message}');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _getHeaders(),
          )
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Cannot connect to server. Please check your internet or server status.');
    } on TimeoutException {
      throw NetworkException('Request timed out. Server took too long to respond.');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP connection failed: ${e.message}');
    }
  }

  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    // Parse server error message if available
    String errorMessage = 'Request failed with status $statusCode';
    dynamic errorBody;
    try {
      if (response.body.isNotEmpty) {
        errorBody = jsonDecode(response.body);
        if (errorBody is Map) {
          if (errorBody.containsKey('message') && errorBody['message'] != null) {
            errorMessage = errorBody['message'].toString();
          } else if (errorBody.containsKey('error') && errorBody['error'] != null) {
            errorMessage = errorBody['error'].toString();
          } else if (errorBody.containsKey('errors') && errorBody['errors'] is Map) {
            final errorsMap = errorBody['errors'] as Map;
            final errorList = <String>[];
            errorsMap.forEach((key, val) {
              if (val is List) {
                errorList.addAll(val.map((e) => e.toString()));
              } else if (val != null) {
                errorList.add(val.toString());
              }
            });
            if (errorList.isNotEmpty) {
              errorMessage = errorList.join(', ');
            } else if (errorBody.containsKey('title') && errorBody['title'] != null) {
              errorMessage = errorBody['title'].toString();
            }
          } else if (errorBody.containsKey('title') && errorBody['title'] != null) {
            errorMessage = errorBody['title'].toString();
          } else {
            errorMessage = response.body;
          }
        } else {
          errorMessage = response.body;
        }
      }
    } catch (_) {
      errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
    }

    if (statusCode == 401 || statusCode == 403) {
      throw AuthException(errorMessage, statusCode: statusCode);
    } else if (statusCode >= 400 && statusCode < 500) {
      throw ClientException(errorMessage, statusCode: statusCode, details: errorBody);
    } else if (statusCode >= 500) {
      throw ServerException(errorMessage, statusCode: statusCode, details: errorBody);
    } else {
      throw ApiException(errorMessage, statusCode: statusCode, details: errorBody);
    }
  }
}

