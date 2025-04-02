
import 'volc_engine_rtc_web_platform_interface.dart';

class VolcEngineRtcWeb {
  Future<String?> getPlatformVersion() {
    return VolcEngineRtcWebPlatform.instance.getPlatformVersion();
  }
}
