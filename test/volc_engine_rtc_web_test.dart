import 'package:flutter_test/flutter_test.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web_platform_interface.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:web/helpers.dart';

class MockVolcEngineRtcWebPlatform
    with MockPlatformInterfaceMixin
    implements VolcEngineRtcWebPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> initialize(String appId) {
    // TODO: implement initialize
    throw UnimplementedError();
  }

  @override
  Future<bool> joinRoom(String roomId, String userId, String token) {
    // TODO: implement joinRoom
    throw UnimplementedError();
  }

  @override
  Future<bool> leaveRoom() {
    // TODO: implement leaveRoom
    throw UnimplementedError();
  }

  @override
  Future<bool> publishStream(bool hasAudio, bool hasVideo) {
    // TODO: implement publishStream
    throw UnimplementedError();
  }

  @override
  Future<bool> release() {
    // TODO: implement release
    throw UnimplementedError();
  }

  @override
  Future<bool> unpublishStream() {
    // TODO: implement unpublishStream
    throw UnimplementedError();
  }

  @override
  Future<List<MediaDeviceInfo>> getAudioDevices() {
    // TODO: implement getAudioDevices
    throw UnimplementedError();
  }

  @override
  Future<bool> muteLocalAudio(bool mute) {
    // TODO: implement muteLocalAudio
    throw UnimplementedError();
  }

  @override
  // TODO: implement onError
  Stream<RtcErrorInfo> get onError => throw UnimplementedError();

  @override
  // TODO: implement onJoinRoomSuccess
  Stream<String> get onJoinRoomSuccess => throw UnimplementedError();

  @override
  // TODO: implement onLeaveRoom
  Stream<void> get onLeaveRoom => throw UnimplementedError();

  @override
  // TODO: implement onUserJoined
  Stream<UserInfo> get onUserJoined => throw UnimplementedError();

  @override
  // TODO: implement onUserLeave
  Stream<UserInfo> get onUserLeave => throw UnimplementedError();

  @override
  Future<bool> setAudioOutput(String deviceId) {
    // TODO: implement setAudioOutput
    throw UnimplementedError();
  }
}

void main() {
  final VolcEngineRtcWebPlatform initialPlatform =
      VolcEngineRtcWebPlatform.instance;

  test('$MethodChannelVolcEngineRtcWeb is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVolcEngineRtcWeb>());
  });

  test('getPlatformVersion', () async {
    VolcEngineRtcWeb volcEngineRtcWebPlugin = VolcEngineRtcWeb();
    MockVolcEngineRtcWebPlatform fakePlatform = MockVolcEngineRtcWebPlatform();
    VolcEngineRtcWebPlatform.instance = fakePlatform;

    expect(await volcEngineRtcWebPlugin.getPlatformVersion(), '42');
  });
}
