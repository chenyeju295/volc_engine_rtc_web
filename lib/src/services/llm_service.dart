import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import '../config/config.dart';
import 'service_interface.dart';

/// Callback for AI response text updates
typedef AiResponseCallback = void Function(String text);

/// LLM (Large Language Model) service
class LlmService implements Service {
  /// Configuration for the LLM service
  final AigcRtcConfig config;

  /// HTTP client for API requests
  html.HttpRequest? _httpClient;

  /// Stream controller for AI response text
  final StreamController<String> _responseStreamController =
      StreamController<String>.broadcast();

  /// Stream of AI response text
  Stream<String> get responseStream => _responseStreamController.stream;

  /// Whether a request is currently in progress
  bool _isRequestInProgress = false;

  /// LLM (Large Language Model) service
  LlmService({required this.config});

  @override
  Future<void> initialize() async {
    try {
      debugPrint('LLM service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize LLM service: $e');
      rethrow;
    }
  }

  /// Send a text message to the LLM and get a response
  Future<void> sendMessage(String message) async {
    if (_isRequestInProgress) {
      debugPrint('Request already in progress, ignoring new message');
      return;
    }

    _isRequestInProgress = true;

    try {
      final endpoint = '${config.serverUrl}/api/conversation';

      final requestData = {
        'message': message,
        'modelId': config.arkModelId,
      };

      // Create a new request
      final request = await html.HttpRequest.request(
        endpoint,
        method: 'POST',
        requestHeaders: {
          'Content-Type': 'application/json',
        },
        sendData: jsonEncode(requestData),
      );

      if (request.status == 200) {
        final responseData = jsonDecode(request.responseText.toString());
        final aiResponse = responseData['response'] as String;

        // Add response to stream
        _responseStreamController.add(aiResponse);

        debugPrint('Received AI response: $aiResponse');
      } else {
        throw Exception('Failed to get AI response: ${request.statusText}');
      }
    } catch (e) {
      debugPrint('Error sending message to LLM: $e');
      rethrow;
    } finally {
      _isRequestInProgress = false;
    }
  }

  /// Check if a request is currently in progress
  bool get isRequestInProgress => _isRequestInProgress;

  @override
  Future<void> dispose() async {
    await _responseStreamController.close();

    _httpClient?.abort();
    _httpClient = null;

    debugPrint('LLM service disposed');
  }
}

/// Print debug information
void debugPrint(String message) {
  print('[LlmService] $message');
}
