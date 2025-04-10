import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../utils/web_utils.dart';
import '../models/models.dart';
import 'rtc_service.dart';
import 'rtc_engine_manager.dart';
import 'rtc_device_manager.dart';
import 'rtc_event_manager.dart';
import 'service_interface.dart';

/// Callback for handling state changes
typedef StateChangeCallback = void Function(String state, String? message);

/// Callback for handling messages
typedef MessageCallback = void Function(RtcAigcMessage message);

/// Callback for handling audio status changes
typedef AudioStatusCallback = void Function(bool isPlaying);

/// Callback for handling audio devices changes
typedef AudioDevicesCallback = void Function(List<dynamic> devices);

/// Callback for handling AI subtitles
typedef SubtitleCallback = void Function(Map<String, dynamic> subtitle);

/// Service manager for AIGC RTC services
class ServiceManager implements Service {
  /// Services configuration
  final RtcConfig config;

  /// RTC Engine Manager
  late final RtcEngineManager _engineManager;

  /// RTC Device Manager
  late final RtcDeviceManager _deviceManager;

  /// RTC Event Manager
  late final RtcEventManager _eventManager;

  /// RTC Service
  late final RtcService _rtcService;

  /// Public getter for rtcService
  RtcService get rtcService => _rtcService;

  /// Is initialized
  bool _isInitialized = false;

  /// Is disposed
  bool _isDisposed = false;

  /// Is conversation active
  bool _isConversationActive = false;

  /// List of subscriptions to clean up
  final List<StreamSubscription> _subscriptions = [];

  /// Stream controller for subtitle state changes
  final StreamController<Map<String, dynamic>> _subtitleStateController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream controller for audio properties changes
  final StreamController<Map<String, dynamic>> _audioPropertiesController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream controller for network quality changes
  final StreamController<Map<String, dynamic>> _networkQualityController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream controller for message history changes
  final StreamController<List<RtcAigcMessage>> _messageHistoryController =
      StreamController<List<RtcAigcMessage>>.broadcast();

  /// Subtitle state change stream
  Stream<Map<String, dynamic>> get onSubtitleStateChanged =>
      _subtitleStateController.stream;

  /// Audio properties change stream
  Stream<Map<String, dynamic>> get onAudioPropertiesChanged =>
      _audioPropertiesController.stream;

  /// Network quality change stream
  Stream<Map<String, dynamic>> get onNetworkQualityChanged =>
      _networkQualityController.stream;

  /// Message history change stream
  Stream<List<RtcAigcMessage>> get onMessageHistoryChanged =>
      _messageHistoryController.stream;

  /// Current message history
  List<RtcAigcMessage> get messageHistory => _rtcService.getMessageHistory();

  /// Callback for state changes
  StateChangeCallback? _onStateChange;

  /// Callback for messages
  MessageCallback? _onMessage;

  /// Callback for audio status changes
  AudioStatusCallback? _onAudioStatus;

  /// Callback for audio devices changes
  AudioDevicesCallback? _onAudioDevicesChange;

  /// Callback for AI subtitles
  SubtitleCallback? _onSubtitle;

  /// Device state subscription
  StreamSubscription<bool>? _deviceStateSubscription;

  /// Message subscription
  StreamSubscription<String>? _messageSubscription;

  /// Connection state subscription
  StreamSubscription<String>? _connectionStateSubscription;

  /// Create a new service manager
  ServiceManager({required this.config}) {
    _engineManager = RtcEngineManager(config: config);
    _deviceManager =
        RtcDeviceManager(config: config, engineManager: _engineManager);
    _eventManager = RtcEventManager(config: config);
    _rtcService = RtcService(
      config: config,
      engineManager: _engineManager,
      deviceManager: _deviceManager,
      eventManager: _eventManager,
    );
  }

  /// Set callback for state changes
  void setOnStateChange(StateChangeCallback callback) {
    _onStateChange = callback;
  }

  /// Set callback for text messages
  void setOnMessage(MessageCallback callback) {
    _onMessage = callback;

    // 设置消息回调
    _rtcService.setMessageCallback(callback);
  }

  /// Set callback for audio status changes
  void setOnAudioStatusChange(AudioStatusCallback callback) {
    _onAudioStatus = callback;

    // 如果已经初始化完成，则设置对应的音频状态监听
    if (_isInitialized && !_isDisposed) {
      _setupAudioStatusListener();
    }
  }

  /// Set callback for audio devices changes
  void setOnAudioDevicesChange(AudioDevicesCallback callback) {
    _onAudioDevicesChange = callback;

    // 如果已经初始化完成，则设置对应的设备变更监听
    if (_isInitialized && !_isDisposed) {
      _setupAudioDeviceListener();
    }
  }

  /// Set callback for AI subtitles
  void setOnSubtitle(SubtitleCallback callback) {
    _onSubtitle = callback;

    // 如果已经初始化完成，则设置对应的字幕监听
    if (_isInitialized && !_isDisposed) {
      _setupSubtitleListener();
    }
  }

  /// Safely execute callback, catching possible exceptions
  void _safeCallback(Function() callback) {
    if (_isDisposed) return;

    try {
      callback();
    } catch (e) {
      debugPrint('Error in callback: $e');
    }
  }

  /// Initialize all services
  @override
  Future<bool> initialize() async {
    if (_isInitialized || _isDisposed) return true;

    try {
      // Notify state change
      if (_onStateChange != null) {
        _safeCallback(
            () => _onStateChange!('initializing', 'Initializing services...'));
      }

      // First make sure the SDK is loaded
      await WebUtils.waitForSdkLoaded();

      // 1. Initialize RTC engine first
      final engineInitResult = await _engineManager.initialize();
      if (!engineInitResult) {
        throw Exception('Failed to initialize RTC engine');
      }

      // 2. Get engine instance and set event manager BEFORE any further operations
      debugPrint('【服务管理器】正在设置事件处理器...');
      _engineManager.registerEventHandler(_eventManager);

      // 3. Initialize RTC service with event manager already connected to engine
      final serviceInitResult = await _rtcService.initialize();
      if (!serviceInitResult) {
        throw Exception('Failed to initialize RTC service');
      }

      // Subscribe to device state change events
      _deviceStateSubscription =
          _rtcService.deviceStateStream.listen((isAvailable) {
        if (_onStateChange != null) {
          _safeCallback(() => _onStateChange!(
              isAvailable ? 'ready' : 'error',
              isAvailable
                  ? 'Devices are ready'
                  : 'Audio/video devices not available'));
        }
      }, onError: (error) {
        debugPrint('Device state error: $error');
        if (_onStateChange != null) {
          _safeCallback(
              () => _onStateChange!('error', 'Device state error: $error'));
        }
      });

      // Setup audio device listener if callback is set
      if (_onAudioDevicesChange != null) {
        _setupAudioDeviceListener();
      }

      // Setup audio status listener if callback is set
      if (_onAudioStatus != null) {
        _setupAudioStatusListener();
      }

      // Setup subtitle listener if callback is set
      if (_onSubtitle != null) {
        _setupSubtitleListener();
      }

      // Setup subtitle state listener
      _setupSubtitleStateListener();

      // Setup audio properties listener
      _setupAudioPropertiesListener();

      // Setup network quality listener
      _setupNetworkQualityListener();

      // Setup message history listener
      _setupMessageHistoryListener();

      _isInitialized = true;

      // Notify state change
      if (_onStateChange != null) {
        _safeCallback(() => _onStateChange!('ready', 'Services initialized'));
      }

      return true;
    } catch (e) {
      debugPrint('Error initializing services: $e');
      if (_onStateChange != null) {
        _safeCallback(
            () => _onStateChange!('error', 'Error initializing services: $e'));
      }
      return false;
    }
  }

  /// Set up audio device change listener
  void _setupAudioDeviceListener() {
    try {
      // Subscribe to audio devices change stream
      final audioDevicesSubscription =
          _rtcService.audioDevicesStream.listen((devices) {
        if (_onAudioDevicesChange != null) {
          _safeCallback(() => _onAudioDevicesChange!(devices));
        }
      }, onError: (error) {
        debugPrint('Audio devices stream error: $error');
      });

      // Add the subscription to be disposed later
      _subscriptions.add(audioDevicesSubscription);
    } catch (e) {
      debugPrint('Error setting up audio device listener: $e');
    }
  }

  /// Set up AI subtitle listener
  void _setupSubtitleListener() {
    try {
      // Subscribe to RTC subtitle stream
      final subtitleSubscription =
          _rtcService.subtitleStream.listen((subtitle) {
        if (_onSubtitle != null) {
          _safeCallback(() => _onSubtitle!({"subtitle": subtitle}));
        }
      }, onError: (error) {
        debugPrint('Subtitle stream error: $error');
      });

      // Add the subscription to be disposed later
      _subscriptions.add(subtitleSubscription);
      debugPrint('Subtitle listener set up successfully');
    } catch (e) {
      debugPrint('Error setting up subtitle listener: $e');
    }
  }

  /// Set up audio status listener
  void _setupAudioStatusListener() {
    try {
      // Subscribe to RTC audio status stream
      final audioStatusSubscription =
          _rtcService.audioStatusStream.listen((isPlaying) {
        if (_onAudioStatus != null) {
          _safeCallback(() => _onAudioStatus!(isPlaying));
        }
      }, onError: (error) {
        debugPrint('Audio status stream error: $error');
      });

      // Add the subscription to be disposed later
      _subscriptions.add(audioStatusSubscription);
      debugPrint('Audio status listener set up successfully');
    } catch (e) {
      debugPrint('Error setting up audio status listener: $e');
    }
  }

  /// Set up message history listener
  void _setupMessageHistoryListener() {
    try {
      final subscription = _rtcService.messageHistoryStream.listen(
        (List<RtcAigcMessage> messages) {
          _messageHistoryController.add(messages);
        },
        onError: (error) {
          debugPrint('Message history stream error: $error');
        },
      );
      _subscriptions.add(subscription);
    } catch (e) {
      debugPrint('Failed to setup message history listener: $e');
    }
  }

  /// Set up subtitle state listener
  void _setupSubtitleStateListener() {
    try {
      final subscription = _eventManager.subtitleStateStream.listen(
        (Map<String, dynamic> stateData) {
          _subtitleStateController.add(stateData);
        },
        onError: (error) {
          debugPrint('Subtitle state stream error: $error');
        },
      );
      _subscriptions.add(subscription);
    } catch (e) {
      debugPrint('Failed to setup subtitle state listener: $e');
    }
  }

  /// Set up audio properties listener
  void _setupAudioPropertiesListener() {
    try {
      final subscription = _eventManager.audioPropertiesStream.listen(
        (Map<String, dynamic> data) {
          _audioPropertiesController.add(data);
        },
        onError: (error) {
          debugPrint('Audio properties stream error: $error');
        },
      );
      _subscriptions.add(subscription);
    } catch (e) {
      debugPrint('Failed to setup audio properties listener: $e');
    }
  }

  /// Set up network quality listener
  void _setupNetworkQualityListener() {
    try {
      final subscription = _eventManager.networkQualityStream.listen(
        (Map<String, dynamic> data) {
          _networkQualityController.add(data);
        },
        onError: (error) {
          debugPrint('Network quality stream error: $error');
        },
      );
      _subscriptions.add(subscription);
    } catch (e) {
      debugPrint('Failed to setup network quality listener: $e');
    }
  }

  /// Join a room with the given parameters
  Future<bool> joinRoom({
    required String roomId,
    required String userId,
    required String token,
  }) async {
    if (!_isInitialized || _isDisposed) {
      debugPrint('Cannot join room: Service not initialized or disposed');
      return false;
    }

    try {
      // Notify state change
      if (_onStateChange != null) {
        _safeCallback(
            () => _onStateChange!('joining', 'Joining room $roomId...'));
      }

      // Join the room using RTC service
      final joinResult = await _rtcService.joinRoom(
        roomId: roomId,
        userId: userId,
        token: token,
      );

      if (!joinResult) {
        if (_onStateChange != null) {
          _safeCallback(() => _onStateChange!('error', 'Failed to join room'));
        }
        return false;
      }

      // Notify state change
      if (_onStateChange != null) {
        _safeCallback(() =>
            _onStateChange!('joined', 'Joined room $roomId successfully'));
      }

      return true;
    } catch (e) {
      debugPrint('Error joining room: $e');
      if (_onStateChange != null) {
        _safeCallback(() => _onStateChange!('error', 'Error joining room: $e'));
      }
      return false;
    }
  }

  /// Start a conversation
  Future<bool> startConversation() async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot start conversation: Service not initialized or disposed');
      return false;
    }

    try {
      if (_isConversationActive) {
        debugPrint('Conversation already active');
        return true;
      }

      // Notify state change
      if (_onStateChange != null) {
        _safeCallback(
            () => _onStateChange!('starting', 'Starting conversation...'));
      }

      // Start the conversation using RTC service
      final startResult = await _rtcService.startConversation();

      _isConversationActive = startResult;

      // Notify state change
      if (_onStateChange != null) {
        _safeCallback(() => _onStateChange!(
            startResult ? 'inConversation' : 'error',
            startResult
                ? 'Conversation started'
                : 'Failed to start conversation'));
      }

      return startResult;
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      if (_onStateChange != null) {
        _safeCallback(
            () => _onStateChange!('error', 'Error starting conversation: $e'));
      }
      return false;
    }
  }

  /// Stop the current conversation
  Future<bool> stopConversation() async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot stop conversation: Service not initialized or disposed');
      return false;
    }

    try {
      if (!_isConversationActive) {
        debugPrint('No active conversation to stop');
        return true;
      }

      // Notify state change
      if (_onStateChange != null) {
        _safeCallback(
            () => _onStateChange!('stopping', 'Stopping conversation...'));
      }

      // Stop the conversation using RTC service
      final stopResult = await _rtcService.stopConversation();

      _isConversationActive = !stopResult;

      // Notify state change
      if (_onStateChange != null) {
        _safeCallback(() => _onStateChange!(
            stopResult ? 'joined' : 'error',
            stopResult
                ? 'Conversation stopped'
                : 'Failed to stop conversation'));
      }

      return stopResult;
    } catch (e) {
      debugPrint('Error stopping conversation: $e');
      if (_onStateChange != null) {
        _safeCallback(
            () => _onStateChange!('error', 'Error stopping conversation: $e'));
      }
      return false;
    }
  }

  /// Request microphone access
  Future<bool> requestMicrophoneAccess() async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot request microphone access: Service not initialized or disposed');
      return false;
    }

    try {
      return await _deviceManager.requestMicrophoneAccess();
    } catch (e) {
      debugPrint('Error requesting microphone access: $e');
      return false;
    }
  }

  /// Leave the current room
  @override
  Future<bool> leaveRoom() async {
    if (!_isInitialized || _isDisposed) {
      debugPrint('Cannot leave room: Service not initialized or disposed');
      return false;
    }

    try {
      // Notify state change
      if (_onStateChange != null) {
        _safeCallback(() => _onStateChange!('leaving', 'Leaving room...'));
      }

      // Leave the room using RTC service
      final leaveResult = await _rtcService.leaveRoom();
      _isConversationActive = false;

      if (_onStateChange != null) {
        _safeCallback(() => _onStateChange!(leaveResult ? 'ready' : 'error',
            leaveResult ? 'Left room successfully' : 'Failed to leave room'));
      }

      return leaveResult;
    } catch (e) {
      debugPrint('Error leaving room: $e');
      if (_onStateChange != null) {
        _safeCallback(() => _onStateChange!('error', 'Error leaving room: $e'));
      }
      return false;
    }
  }

  /// Send a message to the AI
  @override
  Future<bool> sendMessage(String text) async {
    if (!_isInitialized || _isDisposed || !_isConversationActive) {
      debugPrint(
          'Cannot send message: Service not initialized, disposed, or conversation not active');
      return false;
    }

    try {
      return await _rtcService.sendMessage(text);
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Interrupt the current conversation
  @override
  Future<bool> interruptConversation() async {
    if (!_isInitialized || _isDisposed || !_isConversationActive) {
      debugPrint(
          'Cannot interrupt conversation: Service not initialized, disposed, or conversation not active');
      return false;
    }

    try {
      return await _rtcService.interruptConversation();
    } catch (e) {
      debugPrint('Error interrupting conversation: $e');
      return false;
    }
  }

  /// Resume audio playback (used when autoplay is blocked)
  @override
  Future<bool> resumeAudioPlayback() async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot resume audio playback: Service not initialized or disposed');
      return false;
    }

    try {
      return await _rtcService.resumeAudioPlayback();
    } catch (e) {
      debugPrint('Error resuming audio playback: $e');
      return false;
    }
  }

  /// Get list of available audio input devices
  @override
  Future<List<Map<String, String>>> getAudioInputDevices() async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot get audio input devices: Service not initialized or disposed');
      return [];
    }

    try {
      final devices = await _rtcService.getAudioInputDevices();
      return devices.map((device) {
        return {
          'deviceId': device['deviceId'] as String,
          'label': device['label'] as String,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting audio input devices: $e');
      return [];
    }
  }

  /// Get list of available audio output devices
  @override
  Future<List<Map<String, String>>> getAudioOutputDevices() async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot get audio output devices: Service not initialized or disposed');
      return [];
    }

    try {
      final devices = await _rtcService.getAudioOutputDevices();
      return devices.map((device) {
        return {
          'deviceId': device['deviceId'] as String,
          'label': device['label'] as String,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting audio output devices: $e');
      return [];
    }
  }

  /// Set the audio capture device
  @override
  Future<bool> setAudioCaptureDevice(String deviceId) async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot set audio capture device: Service not initialized or disposed');
      return false;
    }

    try {
      return await _rtcService.setAudioCaptureDevice(deviceId);
    } catch (e) {
      debugPrint('Error setting audio capture device: $e');
      return false;
    }
  }

  /// Set the audio playback device
  @override
  Future<bool> setAudioPlaybackDevice(String deviceId) async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot set audio playback device: Service not initialized or disposed');
      return false;
    }

    try {
      return await _rtcService.setAudioPlaybackDevice(deviceId);
    } catch (e) {
      debugPrint('Error setting audio playback device: $e');
      return false;
    }
  }

  /// Start audio capture
  @override
  Future<bool> startAudioCapture(String? deviceId) async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot start audio capture: Service not initialized or disposed');
      return false;
    }

    try {
      return await _rtcService.startAudioCapture(deviceId);
    } catch (e) {
      debugPrint('Error starting audio capture: $e');
      return false;
    }
  }

  /// Stop audio capture
  @override
  Future<bool> stopAudioCapture() async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot stop audio capture: Service not initialized or disposed');
      return false;
    }

    try {
      return await _rtcService.stopAudioCapture();
    } catch (e) {
      debugPrint('Error stopping audio capture: $e');
      return false;
    }
  }

  /// Test a subtitle for debug purposes
  Future<bool> testAISubtitle(String text, {bool isFinal = false}) async {
    if (!_isInitialized || _isDisposed) {
      debugPrint('Cannot test subtitle: Service not initialized or disposed');
      return false;
    }

    try {
      return await _rtcService.testAISubtitle(text, isFinal: isFinal);
    } catch (e) {
      debugPrint('Error testing AI subtitle: $e');
      return false;
    }
  }

  /// Request camera access
  Future<bool> requestCameraAccess() async {
    if (!_isInitialized || _isDisposed) {
      debugPrint(
          'Cannot request camera access: Service not initialized or disposed');
      return false;
    }

    try {
      return await _rtcService.requestCameraAccess();
    } catch (e) {
      debugPrint('Error requesting camera access: $e');
      return false;
    }
  }

  /// Clean up resources
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    debugPrint('Disposing service manager...');

    try {
      // Clean up stream subscriptions
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();

      // Clean up device state subscription
      if (_deviceStateSubscription != null) {
        await _deviceStateSubscription!.cancel();
        _deviceStateSubscription = null;
      }

      // Close all stream controllers
      _subtitleStateController.close();
      _audioPropertiesController.close();
      _networkQualityController.close();
      _messageHistoryController.close();

      // Dispose RTC service
      await _rtcService.dispose();

      _isDisposed = true;
      _isInitialized = false;
      debugPrint('Service manager disposed successfully');
    } catch (e) {
      debugPrint('Error disposing service manager: $e');
    }
  }
}
