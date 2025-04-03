import 'dart:async';

import '../config/config.dart';
import 'asr_service.dart';
import 'llm_service.dart';
import 'rtc_service.dart';
import 'service_interface.dart';
import 'tts_service.dart';

/// Manager for all services in the AIGC-RTC plugin
class ServiceManager implements Service {
  /// Configuration for all services
  final AigcRtcConfig config;
  
  /// RTC service instance
  late final RtcService rtcService;
  
  /// ASR service instance
  late final AsrService asrService;
  
  /// LLM service instance
  late final LlmService llmService;
  
  /// TTS service instance
  late final TtsService ttsService;
  
  /// Whether services are initialized
  bool _isInitialized = false;
  
  /// Subscription for ASR text stream
  StreamSubscription<String>? _asrTextSubscription;
  
  /// Subscription for LLM response stream
  StreamSubscription<String>? _llmResponseSubscription;
  
  /// Callback for user speech recognition
  final Function(String text)? onUserSpeechRecognized;
  
  /// Callback for AI response text
  final Function(String text)? onAiResponseReceived;
  
  /// Callback for speech state changes
  final Function(bool isActive)? onSpeechStateChanged;

  /// Manager for all services in the AIGC-RTC plugin
  ServiceManager({
    required this.config,
    this.onUserSpeechRecognized,
    this.onAiResponseReceived,
    this.onSpeechStateChanged,
  }) {
    rtcService = RtcService(config: config);
    asrService = AsrService(config: config);
    llmService = LlmService(config: config);
    ttsService = TtsService(config: config);
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize all services
      await rtcService.initialize();
      await asrService.initialize();
      await llmService.initialize();
      await ttsService.initialize();
      
      // Set up event listeners
      _setupEventListeners();
      
      _isInitialized = true;
      
      debugPrint('All services initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize services: $e');
      
      // Clean up any successfully initialized services
      await dispose();
      
      rethrow;
    }
  }
  
  /// Set up event listeners between services
  void _setupEventListeners() {
    // Listen for ASR text events
    _asrTextSubscription = asrService.textStream.listen((text) {
      // Forward to user callback
      onUserSpeechRecognized?.call(text);
      
      // If this is a final result, send to LLM
      if (text.isNotEmpty) {
        llmService.sendMessage(text);
      }
    });
    
    // Listen for LLM response events
    _llmResponseSubscription = llmService.responseStream.listen((text) {
      // Forward to user callback
      onAiResponseReceived?.call(text);
      
      // Speak the response using TTS
      ttsService.speak(text);
    });
    
    // Forward TTS speech state to user callback
    ttsService.speechStateStream.listen((isActive) {
      onSpeechStateChanged?.call(isActive);
    });
  }
  
  /// Start a conversation session
  Future<bool> startConversation() async {
    if (!_isInitialized) {
      debugPrint('Services not initialized, cannot start conversation');
      return false;
    }
    
    try {
      // Request microphone access
      final hasMicrophone = await rtcService.requestMicrophoneAccess();
      if (!hasMicrophone) {
        debugPrint('Microphone access denied, cannot start conversation');
        return false;
      }
      
      // Start speech recognition
      final started = await asrService.startRecognition();
      
      return started;
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      return false;
    }
  }
  
  /// Stop the current conversation session
  Future<void> stopConversation() async {
    try {
      // Stop speech recognition
      await asrService.stopRecognition();
      
      // Stop TTS if speaking
      await ttsService.stopSpeaking();
      
      // Stop local audio
      rtcService.stopLocalAudio();
      
      debugPrint('Conversation stopped');
    } catch (e) {
      debugPrint('Error stopping conversation: $e');
    }
  }
  
  /// Send a text message manually (without speech)
  Future<void> sendTextMessage(String message) async {
    if (!_isInitialized) {
      debugPrint('Services not initialized, cannot send message');
      return;
    }
    
    try {
      await llmService.sendMessage(message);
    } catch (e) {
      debugPrint('Error sending text message: $e');
    }
  }

  @override
  Future<void> dispose() async {
    // Cancel subscriptions
    await _asrTextSubscription?.cancel();
    await _llmResponseSubscription?.cancel();
    
    // Dispose all services
    await rtcService.dispose();
    await asrService.dispose();
    await llmService.dispose();
    await ttsService.dispose();
    
    _isInitialized = false;
    
    debugPrint('All services disposed');
  }
}

/// Print debug information
void debugPrint(String message) {
  print('[ServiceManager] $message');
} 