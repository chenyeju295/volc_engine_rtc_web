import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'volc_engine_rtc_web_method_channel.dart';
// Temporarily commented out until issue is resolved
// import 'src/rtc_event_handler.dart';

abstract class VolcEngineRtcWebPlatform extends PlatformInterface {
  /// Constructs a VolcEngineRtcWebPlatform.
  VolcEngineRtcWebPlatform() : super(token: _token);

  static final Object _token = Object();

  static VolcEngineRtcWebPlatform _instance = MethodChannelVolcEngineRtcWeb();

  /// The default instance of [VolcEngineRtcWebPlatform] to use.
  ///
  /// Defaults to [MethodChannelVolcEngineRtcWeb].
  static VolcEngineRtcWebPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VolcEngineRtcWebPlatform] when
  /// they register themselves.
  static set instance(VolcEngineRtcWebPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Gets the platform version
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Initializes the RTC engine with appId
  Future<bool> initializeEngine(String appId) {
    throw UnimplementedError('initializeEngine() has not been implemented.');
  }

  /// Joins a room with given parameters
  Future<bool> joinRoom(String roomId, String userId, String token) {
    throw UnimplementedError('joinRoom() has not been implemented.');
  }

  /// Leaves the current room
  Future<bool> leaveRoom() {
    throw UnimplementedError('leaveRoom() has not been implemented.');
  }

  /// Starts audio capture
  Future<bool> startAudioCapture() {
    throw UnimplementedError('startAudioCapture() has not been implemented.');
  }

  /// Stops audio capture
  Future<bool> stopAudioCapture() {
    throw UnimplementedError('stopAudioCapture() has not been implemented.');
  }

  /// Publishes local stream to the room
  Future<bool> publishStream(int mediaType) {
    throw UnimplementedError('publishStream() has not been implemented.');
  }

  /// Unpublishes local stream
  Future<bool> unpublishStream(int mediaType) {
    throw UnimplementedError('unpublishStream() has not been implemented.');
  }

  /// Starts AI voice chat
  Future<Map<String, dynamic>> startVoiceChat(Map<String, dynamic> options) {
    throw UnimplementedError('startVoiceChat() has not been implemented.');
  }

  /// Updates AI voice chat parameters
  Future<Map<String, dynamic>> updateVoiceChat(String sessionId, Map<String, dynamic> options) {
    throw UnimplementedError('updateVoiceChat() has not been implemented.');
  }

  /// Stops AI voice chat
  Future<Map<String, dynamic>> stopVoiceChat(String sessionId) {
    throw UnimplementedError('stopVoiceChat() has not been implemented.');
  }

  /// Set event handler
  void setEventHandler(dynamic handler) {
    throw UnimplementedError('setEventHandler() has not been implemented.');
  }
}
