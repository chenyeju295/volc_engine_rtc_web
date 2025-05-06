import 'dart:async';
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web.dart';

/// Manages the RTC and AIGC engine initialization and core functionality
class RtcEngineManager {
  final AigcConfig config;
  dynamic engine;
  dynamic aigcClient;
  bool isInitialized = false;
  bool isInRoom = false;

  RtcEngineManager({required this.config});

  /// Returns the RTC client instance
  dynamic getRtcClient() {
    return engine;
  }

  Future<bool> initialize() async {
    try {
      await _initializeRtcEngine();
      isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('【RTC引擎】初始化失败: $e');
      return false;
    }
  }

  Future<void> _initializeRtcEngine() async {
    // Check if SDK is already loaded first
    if (!WebUtils.isSdkLoaded()) {
      // Wait for SDK to load
      await WebUtils.waitForSdkLoaded();
    }

    // Verify SDK availability
    if (!WebUtils.isSdkLoaded()) {
      debugPrint('【RTC引擎】VERTC SDK加载失败');
      throw Exception('VERTC SDK not loaded properly');
    }

    try {
      // 使用VERTC.createEngine创建引擎实例
      debugPrint('【RTC引擎】创建RTC引擎，AppID: ${config.appId}');

      final vertcObject = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (vertcObject == null) {
        throw Exception('无法访问VERTC对象，请确保SDK已正确加载');
      }

      engine = js_util.callMethod(vertcObject, 'createEngine', [config.appId]);
      if (engine == null) {
        throw Exception('创建RTC引擎失败');
      }

      // 尝试添加AI降噪扩展（可选，如果失败不会影响主要功能）
      try {
        final rtcAiAnsExtensionClass =
            js_util.getProperty(js_util.globalThis, 'RTCAIAnsExtension');
        if (rtcAiAnsExtensionClass != null) {
          final aiAnsExtension =
              js_util.callConstructor(rtcAiAnsExtensionClass, []);
          await js_util.promiseToFuture(js_util
              .callMethod(engine, 'registerExtension', [aiAnsExtension]));
          js_util.callMethod(aiAnsExtension, 'enable', []);
          debugPrint('【RTC引擎】AI降噪扩展已启用');
        } else {
          debugPrint('【RTC引擎】未找到AI降噪扩展，跳过');
        }
      } catch (e) {
        debugPrint('【RTC引擎】AI降噪扩展加载失败，但不影响主要功能: $e');
      }
    } catch (e) {
      debugPrint('【RTC引擎】创建RTC引擎失败: $e');
      throw Exception('创建RTC引擎失败: $e');
    }
  }

  Future<bool> joinRoom(
      {required String roomId,
      required String userId,
      required String token}) async {
    if (engine == null) {
      debugPrint('【加入房间】RTC引擎未初始化，无法加入房间');
      return false;
    }

    try {
      // 启用音频属性报告
      js_util.callMethod(engine, 'enableAudioPropertiesReport', [
        js_util.jsify({'interval': 1000})
      ]);
      debugPrint('【RTC引擎】已启用音频属性报告，间隔: 1000ms');

      // 设置用户信息
      final extraInfo = WebUtils.stringify(js_util.jsify({
        'user_name': userId,
        'user_id': userId,
        'call_scene': 'RTC-AIGC',
      }));

      // 设置房间选项
      final roomOptions = WebUtils.stringify(js_util.jsify({
        'isAutoPublish': true,
        'isAutoSubscribeAudio': true,
        'roomProfileType': 5, // RoomProfileType.chat
      }));

      // 准备用户对象
      final userObject =
          js_util.jsify({'userId': userId, 'extraInfo': extraInfo});

      debugPrint(
          '【加入房间】准备加入房间:  房间ID: $roomId,  附加信息: $extraInfo, 房间选项: $roomOptions');
      // 调用joinRoom方法
      await js_util.promiseToFuture(js_util.callMethod(
          engine, 'joinRoom', [token, roomId, userObject, roomOptions]));

      isInRoom = true;

      return true;
    } catch (e) {
      debugPrint('【加入房间】加入房间失败: $e');
      isInRoom = false;
      return false;
    }
  }

  /// 离开RTC房间
  Future<bool> leaveRoom() async {
    if (engine == null) {
      debugPrint('【离开房间】RTC引擎未初始化，无法离开房间');
      return false;
    }

    if (!isInRoom) {
      debugPrint('【离开房间】当前未在房间中');
      return true;
    }

    try {
      debugPrint('【离开房间】开始离开RTC房间');
      js_util.callMethod(engine, 'leaveRoom', []);
      debugPrint('【离开房间】已调用leaveRoom方法');

      isInRoom = false;
      debugPrint('【离开房间】成功离开房间');
      return true;
    } catch (e) {
      debugPrint('【离开房间】离开房间失败: $e');
      return false;
    }
  }

  /// 销毁RTC引擎
  Future<void> dispose() async {
    try {
      if (isInRoom) {
        await leaveRoom();
      }

      // 销毁引擎实例
      if (engine != null) {
        debugPrint('【销毁引擎】正在销毁RTC引擎');

        final vertcObject = js_util.getProperty(js_util.globalThis, 'VERTC');
        if (vertcObject != null) {
          js_util.callMethod(vertcObject, 'destroyEngine', [engine]);
          debugPrint('【销毁引擎】RTC引擎已销毁');
        } else {
          debugPrint('【销毁引擎】警告: 无法访问VERTC对象，引擎可能未完全销毁');
        }

        engine = null;
      }

      // 销毁AIGC客户端
      if (aigcClient != null) {
        (aigcClient as AigcClient).dispose();
        aigcClient = null;
        debugPrint('【销毁引擎】AIGC客户端已销毁');
      }

      isInitialized = false;
      debugPrint('【销毁引擎】引擎管理器资源释放完成');
    } catch (e) {
      debugPrint('【销毁引擎】销毁引擎时出错: $e');
    }
  }
}
