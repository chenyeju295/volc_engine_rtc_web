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
}
