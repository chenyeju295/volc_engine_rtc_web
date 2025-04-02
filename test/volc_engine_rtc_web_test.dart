import 'package:flutter_test/flutter_test.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web_platform_interface.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVolcEngineRtcWebPlatform
    with MockPlatformInterfaceMixin
    implements VolcEngineRtcWebPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VolcEngineRtcWebPlatform initialPlatform = VolcEngineRtcWebPlatform.instance;

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
