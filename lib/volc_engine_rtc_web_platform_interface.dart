import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'volc_engine_rtc_web_method_channel.dart';

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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
