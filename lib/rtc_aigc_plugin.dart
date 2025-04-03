import 'dart:async';

import 'src/config/config.dart';
import 'src/services/service_manager.dart';

/// RTC AIGC Plugin for Flutter Web
class RtcAigcPlugin {
  /// The singleton instance of the plugin
  static RtcAigcPlugin? _instance;
  
  /// The service manager instance
  late final ServiceManager _serviceManager;
  
  /// The configuration for the plugin
  final AigcRtcConfig config;
  
  /// Private constructor
  RtcAigcPlugin._({
    required this.config,
    required Function(String text)? onUserSpeechRecognized,
    required Function(String text)? onAiResponseReceived,
    required Function(bool isActive)? onSpeechStateChanged,
  }) {
    _serviceManager = ServiceManager(
      config: config,
      onUserSpeechRecognized: onUserSpeechRecognized,
      onAiResponseReceived: onAiResponseReceived,
      onSpeechStateChanged: onSpeechStateChanged,
    );
  }
  
  /// Initialize the plugin with configuration and callbacks
  static Future<void> initialize({
    required String appId,
    required String roomId,
    required String userId,
    required String token,
    String? businessId,
    required String asrAppId,
    required String ttsAppId,
    required String serverUrl,
    required String arkModelId,
    Function(String text)? onUserSpeechRecognized,
    Function(String text)? onAiResponseReceived,
    Function(bool isActive)? onSpeechStateChanged,
  }) async {
    final config = AigcRtcConfig(
      appId: appId,
      roomId: roomId,
      userId: userId,
      token: token,
      businessId: businessId,
      asrAppId: asrAppId,
      ttsAppId: ttsAppId,
      serverUrl: serverUrl,
      arkModelId: arkModelId,
    );
    
    _instance = RtcAigcPlugin._(
      config: config,
      onUserSpeechRecognized: onUserSpeechRecognized,
      onAiResponseReceived: onAiResponseReceived,
      onSpeechStateChanged: onSpeechStateChanged,
    );
    
    await _instance!._serviceManager.initialize();
  }
  
  /// Start a conversation session
  static Future<bool> startConversation() async {
    _checkInstance();
    return await _instance!._serviceManager.startConversation();
  }
  
  /// Stop the current conversation session
  static Future<void> stopConversation() async {
    _checkInstance();
    await _instance!._serviceManager.stopConversation();
  }
  
  /// Send a text message manually (without speech)
  static Future<void> sendTextMessage(String message) async {
    _checkInstance();
    await _instance!._serviceManager.sendTextMessage(message);
  }
  
  /// Dispose the plugin and release resources
  static Future<void> dispose() async {
    if (_instance != null) {
      await _instance!._serviceManager.dispose();
      _instance = null;
    }
  }
  
  /// Check if the plugin instance is initialized
  static void _checkInstance() {
    if (_instance == null) {
      throw StateError('RtcAigcPlugin has not been initialized. Call initialize() first.');
    }
  }
} 