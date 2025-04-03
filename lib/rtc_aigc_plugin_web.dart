import 'dart:async';
import 'dart:html' as html;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter/material.dart';

import 'rtc_aigc_plugin.dart';

/// The web implementation of the RtcAigcPlugin.
class RtcAigcPluginWeb {
  /// Registers the web implementation of the RtcAigcPlugin with the Flutter engine.
  static void registerWith(Registrar registrar) {
    // Inject the Volcano Engine RTC SDK from CDN
    _injectVolcanoEngineSDK();
    
    // Inject our custom JavaScript code
    _injectCustomJavaScript();
  }
  
  /// Inject the Volcano Engine RTC SDK from CDN
  static void _injectVolcanoEngineSDK() {
    final sdkScript = html.ScriptElement()
      ..type = 'text/javascript'
      ..src = 'https://lf-unpkg.volccdn.com/obj/vcloudfe/sdk/@volcengine/rtc/4.66.1/1741254642340/volengine_Web_4.66.1.js';
    
    html.document.head?.append(sdkScript);
    
    // Log SDK loading
    sdkScript.onLoad.listen((_) {
      debugPrint('Volcano Engine RTC SDK loaded successfully');
    });
    
    sdkScript.onError.listen((_) {
      debugPrint('Failed to load Volcano Engine RTC SDK');
    });
  }
  
  /// Inject the custom JavaScript code for the plugin
  static void _injectCustomJavaScript() {
    final script = html.ScriptElement()
      ..type = 'text/javascript'
      ..src = 'assets/packages/rtc_aigc_plugin/web/rtc_interop.js';
    
    html.document.head?.append(script);
    
    // Log custom JS loading
    script.onLoad.listen((_) {
      debugPrint('AIGC plugin JavaScript interop loaded successfully');
    });
    
    script.onError.listen((_) {
      debugPrint('Failed to load AIGC plugin JavaScript interop');
    });
  }
  
  /// Debug print helper
  static void debugPrint(String message) {
    print('[RtcAigcPluginWeb] $message');
  }
} 