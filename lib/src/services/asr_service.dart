import 'dart:async';
import 'dart:js' as js;

import '../config/config.dart';
import 'service_interface.dart';

/// Callback for speech recognition text updates
typedef SpeechRecognizedCallback = void Function(String text);

/// ASR (Automatic Speech Recognition) service
class AsrService implements Service {
  /// Configuration for the ASR service
  final AigcRtcConfig config;
  
  /// JavaScript interop object for ASR functionality
  js.JsObject? _asrClient;
  
  /// Stream controller for recognized speech text
  final StreamController<String> _textStreamController = StreamController<String>.broadcast();
  
  /// Stream of recognized speech text
  Stream<String> get textStream => _textStreamController.stream;
  
  /// Whether recognition is currently active
  bool _isRecognizing = false;

  /// ASR (Automatic Speech Recognition) service
  AsrService({required this.config});

  @override
  Future<void> initialize() async {
    _registerJsInterop();
    
    try {
      _asrClient = js.JsObject(js.context['AsrClient'], [
        js.JsObject.jsify({
          'appId': config.asrAppId,
          'serverUrl': config.serverUrl,
        })
      ]);
      
      debugPrint('ASR service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize ASR service: $e');
      rethrow;
    }
  }
  
  /// Register JavaScript interop functions
  void _registerJsInterop() {
    js.context['onSpeechRecognized'] = (String text, bool isFinal) {
      _textStreamController.add(text);
      
      if (isFinal) {
        debugPrint('Final speech recognized: $text');
      }
    };
  }
  
  /// Start speech recognition
  Future<bool> startRecognition() async {
    if (_isRecognizing) return true;
    if (_asrClient == null) return false;
    
    try {
      final completer = Completer<bool>();
      
      _asrClient?.callMethod('startRecognition', [
        js.JsObject.jsify({
          'success': () {
            _isRecognizing = true;
            completer.complete(true);
          },
          'failure': (error) {
            completer.complete(false);
            debugPrint('Error starting speech recognition: $error');
          }
        })
      ]);
      
      return await completer.future;
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      return false;
    }
  }
  
  /// Stop speech recognition
  Future<void> stopRecognition() async {
    if (!_isRecognizing) return;
    
    try {
      _asrClient?.callMethod('stopRecognition');
      _isRecognizing = false;
      debugPrint('Speech recognition stopped');
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
    }
  }
  
  /// Check if recognition is currently active
  bool get isRecognizing => _isRecognizing;

  @override
  Future<void> dispose() async {
    await stopRecognition();
    
    await _textStreamController.close();
    
    _asrClient?.callMethod('dispose');
    _asrClient = null;
    
    debugPrint('ASR service disposed');
  }
}

/// Print debug information
void debugPrint(String message) {
  print('[AsrService] $message');
} 