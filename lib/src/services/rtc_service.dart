import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import '../config/config.dart';
import 'service_interface.dart';

/// Callback for device state changes
typedef DeviceStateCallback = void Function(bool isAvailable);

/// RTC service for handling audio/video streams and room connections
class RtcService implements Service {
  /// Configuration for the RTC service
  final AigcRtcConfig config;

  /// JavaScript interop object for RTC functionality
  js.JsObject? _rtcClient;

  /// Stream controller for device state events
  final StreamController<bool> _deviceStateController =
      StreamController<bool>.broadcast();

  /// Stream of device state changes (true if devices are available)
  Stream<bool> get deviceStateStream => _deviceStateController.stream;

  /// Whether microphone is currently active
  bool _isMicrophoneActive = false;

  /// Whether camera is currently active
  bool _isCameraActive = false;

  /// RTC service for handling audio/video streams and room connections
  RtcService({required this.config});

  @override
  Future<void> initialize() async {
    _registerJsInterop();

    try {
      _rtcClient = js.JsObject(js.context['RtcClient'], [
        js.JsObject.jsify({
          'appId': config.appId,
          'roomId': config.roomId,
          'userId': config.userId,
          'token': config.token,
        })
      ]);

      // Set up device change listeners
      _setupDeviceListeners();

      // Connect to room
      await _connectToRoom();

      debugPrint('RTC service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize RTC service: $e');
      rethrow;
    }
  }

  /// Register JavaScript interop functions
  void _registerJsInterop() {
    js.context['onDeviceStatusChange'] = (bool isAvailable) {
      _deviceStateController.add(isAvailable);
    };
  }

  /// Set up device change listeners
  void _setupDeviceListeners() {
    // html.window.navigator.mediaDevices?.onDeviceChange.listen((_) {
    //   _checkDeviceAvailability();
    // });

    // Initial device check
    _checkDeviceAvailability();
  }

  /// Check if audio/video devices are available
  Future<void> _checkDeviceAvailability() async {
    try {
      final devices =
          await html.window.navigator.mediaDevices?.enumerateDevices();
      final hasAudioInput =
          devices?.any((device) => device.kind == 'audioinput') ?? false;
      final hasVideoInput =
          devices?.any((device) => device.kind == 'videoinput') ?? false;

      _deviceStateController.add(hasAudioInput && hasVideoInput);
    } catch (e) {
      debugPrint('Error checking device availability: $e');
      _deviceStateController.add(false);
    }
  }

  /// Connect to RTC room
  Future<void> _connectToRoom() async {
    try {
      final completer = Completer<void>();

      _rtcClient?.callMethod('connect', [
        js.JsObject.jsify({
          'success': () {
            completer.complete();
          },
          'failure': (error) {
            completer.completeError(error);
          }
        })
      ]);

      return completer.future;
    } catch (e) {
      debugPrint('Error connecting to RTC room: $e');
      rethrow;
    }
  }

  /// Request microphone access
  Future<bool> requestMicrophoneAccess() async {
    if (_isMicrophoneActive) return true;

    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true,
      });

      if (stream != null) {
        _isMicrophoneActive = true;
        _rtcClient?.callMethod('setLocalAudioStream', [stream]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting microphone access: $e');
      return false;
    }
  }

  /// Request camera access
  Future<bool> requestCameraAccess() async {
    if (_isCameraActive) return true;

    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': true,
      });

      if (stream != null) {
        _isCameraActive = true;
        _rtcClient?.callMethod('setLocalVideoStream', [stream]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting camera access: $e');
      return false;
    }
  }

  /// Stop local audio stream
  void stopLocalAudio() {
    if (!_isMicrophoneActive) return;

    _rtcClient?.callMethod('stopLocalAudio');
    _isMicrophoneActive = false;
  }

  /// Stop local video stream
  void stopLocalVideo() {
    if (!_isCameraActive) return;

    _rtcClient?.callMethod('stopLocalVideo');
    _isCameraActive = false;
  }

  @override
  Future<void> dispose() async {
    stopLocalAudio();
    stopLocalVideo();

    await _deviceStateController.close();

    // Disconnect from the room
    _rtcClient?.callMethod('disconnect');
    _rtcClient = null;

    debugPrint('RTC service disposed');
  }
}

/// Print debug information
void debugPrint(String message) {
  print('[RtcService] $message');
}
