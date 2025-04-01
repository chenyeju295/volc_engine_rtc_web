import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web.dart';

/// Registers the web implementation of the plugin
void registerPlugins(Registrar registrar) {
  VolcEngineRtcWeb.registerWith(registrar);
  registrar.registerMessageHandler();
} 