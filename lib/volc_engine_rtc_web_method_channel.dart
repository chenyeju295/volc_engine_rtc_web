import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'volc_engine_rtc_web_platform_interface.dart';

/// An implementation of [VolcEngineRtcWebPlatform] that uses method channels.
class MethodChannelVolcEngineRtcWeb extends VolcEngineRtcWebPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('volc_engine_rtc_web');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
  
  @override
  Future<bool> initializeEngine(String appId) async {
    final result = await methodChannel.invokeMethod<bool>('initializeEngine', {
      'appId': appId,
    });
    return result ?? false;
  }
  
  @override
  Future<bool> joinRoom(String roomId, String userId, String token) async {
    final result = await methodChannel.invokeMethod<bool>('joinRoom', {
      'roomId': roomId,
      'userId': userId,
      'token': token,
    });
    return result ?? false;
  }
  
  @override
  Future<bool> leaveRoom() async {
    final result = await methodChannel.invokeMethod<bool>('leaveRoom');
    return result ?? false;
  }
  
  @override
  Future<bool> startAudioCapture() async {
    final result = await methodChannel.invokeMethod<bool>('startAudioCapture');
    return result ?? false;
  }
  
  @override
  Future<bool> stopAudioCapture() async {
    final result = await methodChannel.invokeMethod<bool>('stopAudioCapture');
    return result ?? false;
  }
  
  @override
  Future<bool> publishStream(int mediaType) async {
    final result = await methodChannel.invokeMethod<bool>('publishStream', {
      'mediaType': mediaType,
    });
    return result ?? false;
  }
  
  @override
  Future<bool> unpublishStream(int mediaType) async {
    final result = await methodChannel.invokeMethod<bool>('unpublishStream', {
      'mediaType': mediaType,
    });
    return result ?? false;
  }
  
  @override
  Future<Map<String, dynamic>> startVoiceChat(Map<String, dynamic> options) async {
    final result = await methodChannel.invokeMethod<String>('startVoiceChat', {
      'options': options,
    });
    return {'sessionId': result ?? ''};
  }
  
  @override
  Future<Map<String, dynamic>> updateVoiceChat(String sessionId, Map<String, dynamic> options) async {
    final result = await methodChannel.invokeMethod<String>('updateVoiceChat', {
      'sessionId': sessionId,
      'options': options,
    });
    return {'result': result ?? ''};
  }
  
  @override
  Future<Map<String, dynamic>> stopVoiceChat(String sessionId) async {
    throw UnimplementedError('Not supported on this platform');
  }
  
  @override
  void setEventHandler(dynamic handler) {
    // Method channel implementation is not required for events
    // since they are handled directly by the web implementation
  }
}
