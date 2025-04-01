import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelVolcEngineRtcWeb platform = MethodChannelVolcEngineRtcWeb();
  const MethodChannel channel = MethodChannel('volc_engine_rtc_web');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
