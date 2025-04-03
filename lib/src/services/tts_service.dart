import 'dart:async';
import 'dart:js' as js;

import '../config/config.dart';
import 'service_interface.dart';

/// Callback for speech state changes
typedef SpeechStateCallback = void Function(bool isActive);

/// TTS (Text-to-Speech) service
class TtsService implements Service {
  /// Configuration for the TTS service
  final AigcRtcConfig config;
  
  /// JavaScript interop object for TTS functionality
  js.JsObject? _ttsClient;
  
  /// Stream controller for speech state events
  final StreamController<bool> _speechStateController = StreamController<bool>.broadcast();
  
  /// Stream of speech state changes (true if speech is active)
  Stream<bool> get speechStateStream => _speechStateController.stream;
  
  /// Whether speech is currently active
  bool _isSpeaking = false;

  /// TTS (Text-to-Speech) service
  TtsService({required this.config});

  @override
  Future<void> initialize() async {
    _registerJsInterop();
    
    try {
      _ttsClient = js.JsObject(js.context['TtsClient'], [
        js.JsObject.jsify({
          'appId': config.ttsAppId,
          'serverUrl': config.serverUrl,
        })
      ]);
      
      debugPrint('TTS service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize TTS service: $e');
      rethrow;
    }
  }
  
  /// Register JavaScript interop functions
  void _registerJsInterop() {
    js.context['onSpeechStateChange'] = (bool isActive) {
      _speechStateController.add(isActive);
      _isSpeaking = isActive;
      
      debugPrint('Speech state changed: ${isActive ? 'active' : 'inactive'}');
    };
  }
  
  /// Speak the given text
  Future<bool> speak(String text) async {
    if (_ttsClient == null) return false;
    
    try {
      final completer = Completer<bool>();
      
      _ttsClient?.callMethod('speak', [
        text,
        js.JsObject.jsify({
          'success': () {
            _isSpeaking = true;
            _speechStateController.add(true);
            completer.complete(true);
          },
          'failure': (error) {
            completer.complete(false);
            debugPrint('Error starting speech: $error');
          }
        })
      ]);
      
      return await completer.future;
    } catch (e) {
      debugPrint('Error speaking text: $e');
      return false;
    }
  }
  
  /// Stop the current speech
  Future<void> stopSpeaking() async {
    if (!_isSpeaking) return;
    
    try {
      _ttsClient?.callMethod('stop');
      _isSpeaking = false;
      _speechStateController.add(false);
      
      debugPrint('Speech stopped');
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
  }
  
  /// Check if speech is currently active
  bool get isSpeaking => _isSpeaking;

  @override
  Future<void> dispose() async {
    await stopSpeaking();
    
    await _speechStateController.close();
    
    _ttsClient?.callMethod('dispose');
    _ttsClient = null;
    
    debugPrint('TTS service disposed');
  }
}

/// Print debug information
void debugPrint(String message) {
  print('[TtsService] $message');
} 