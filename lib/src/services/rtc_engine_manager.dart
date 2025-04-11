import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';

import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';
import 'package:rtc_aigc_plugin/src/client/aigc_client.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_event_manager.dart';

import '../config/aigc_config.dart';

/// Manages the RTC and AIGC engine initialization and core functionality
class RtcEngineManager {
  final AigcConfig config;
  dynamic engine;
  dynamic aigcClient;
  bool isInitialized = false;
  bool isInRoom = false;
  RtcEventManager? _eventHandler;

  RtcEngineManager({required this.config});

  /// Returns the RTC client instance
  dynamic getRtcClient() {
    return engine;
  }

  Future<bool> initialize() async {
    try {
      debugPrint('【RTC引擎】开始初始化RTC引擎...');

      // Initialize RTC engine
      await _initializeRtcEngine();
      isInitialized = true;

      debugPrint('【RTC引擎】初始化完成');
      return true;
    } catch (e) {
      debugPrint('【RTC引擎】初始化失败: $e');
      return false;
    }
  }

  Future<void> _initializeRtcEngine() async {
    // Wait for SDK to load
    debugPrint('【RTC引擎】正在加载RTC SDK...');
    await WebUtils.waitForSdkLoaded();

    // Verify SDK availability
    if (!WebUtils.isSdkLoaded()) {
      debugPrint('【RTC引擎】VERTC SDK加载失败');
      throw Exception('VERTC SDK not loaded properly');
    }
    debugPrint('【RTC引擎】VERTC SDK加载成功');

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

      debugPrint('【RTC引擎】RTC引擎创建成功');

      // 启用音频属性报告
      js_util.callMethod(engine, 'enableAudioPropertiesReport', [
        js_util.jsify({'interval': 1000})
      ]);
      debugPrint('【RTC引擎】已启用音频属性报告，间隔: 1000ms');

      // 尝试添加AI降噪扩展（可选，如果失败不会影响主要功能）
      try {
        debugPrint('【RTC引擎】尝试加载AI降噪扩展...');
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

      debugPrint('【RTC引擎】RTC引擎初始化成功');
    } catch (e) {
      debugPrint('【RTC引擎】创建RTC引擎失败: $e');
      throw Exception('创建RTC引擎失败: $e');
    }
  }

  /// 注册事件处理器
  void registerEventHandler(RtcEventManager eventHandler) {
    _eventHandler = eventHandler;

    // 设置引擎实例
    if (engine != null) {
      _eventHandler?.setEngine(engine);
      debugPrint('【引擎管理器】成功注册事件处理器，并设置引擎实例');
    } else {
      debugPrint('【引擎管理器】注册事件处理器失败：引擎实例为空');
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
      debugPrint('【加入房间】正在加入RTC房间: ${roomId}');
      debugPrint('【加入房间】token: ${'已设置 '}');

      // 设置用户信息
      final extraInfo = WebUtils.stringify(js_util.jsify({
        'user_name': userId,
        'user_id': userId,
        'call_scene': 'RTC-AIGC',
      }));

      debugPrint('【加入房间】用户ID: $userId, 附加信息: $extraInfo');

      // 设置房间选项
      final roomOptions = js_util.jsify({
        'isAutoPublish': true,
        'isAutoSubscribeAudio': true,
        'roomProfileType': 5, // RoomProfileType.chat
      });

      // 准备用户对象
      final userObject =
          js_util.jsify({'userId': userId, 'extraInfo': extraInfo});

      // 调用joinRoom方法
      await js_util.promiseToFuture(js_util.callMethod(
          engine, 'joinRoom', [token, roomId, userObject, roomOptions]));

      debugPrint('【加入房间】成功加入房间: ${roomId}');
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

  /// 验证权限并获取默认设备
  Future<Map<String, dynamic>> checkPermissionAndGetDevices() async {
    if (engine == null) {
      debugPrint('【设备检查】RTC引擎未初始化，无法检查设备');
      return {'video': false, 'audio': false};
    }

    try {
      final vertcObject = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (vertcObject == null) {
        throw Exception('无法访问VERTC对象');
      }

      // 请求权限
      final permissionResult =
          await js_util.promiseToFuture<Map<dynamic, dynamic>>(
              js_util.callMethod(vertcObject, 'enableDevices', [
        js_util.jsify({'video': false, 'audio': true})
      ]));

      final hasAudioPermission = permissionResult['audio'] == true;

      debugPrint('【设备检查】音频权限: $hasAudioPermission');

      if (hasAudioPermission) {
        // 获取音频输入设备
        final inputsResult = await js_util.promiseToFuture(js_util
            .callMethod(vertcObject, 'enumerateAudioCaptureDevices', []));

        // 获取音频输出设备
        final outputsResult = await js_util.promiseToFuture(js_util
            .callMethod(vertcObject, 'enumerateAudioPlaybackDevices', []));

        return {
          'audio': true,
          'audioInputs': inputsResult,
          'audioOutputs': outputsResult,
        };
      }

      return {'audio': hasAudioPermission};
    } catch (e) {
      debugPrint('【设备检查】检查权限时出错: $e');
      return {'audio': false, 'error': e.toString()};
    }
  }

  /// 恢复音频播放（解决浏览器自动播放限制问题）
  Future<bool> resumeAudioPlayback() async {
    if (engine == null) {
      debugPrint('【RTC引擎】RTC引擎未初始化，无法恢复音频播放');
      return false;
    }

    try {
      debugPrint('【RTC引擎】尝试恢复音频播放...');

      // 创建空白音频元素，播放静音音频来绕过浏览器自动播放限制
      final document = js_util.getProperty(js_util.globalThis, 'document');
      final audioElement =
          js_util.callMethod(document, 'createElement', ['audio']);

      // 设置音频属性
      js_util.setProperty(audioElement, 'volume', 0.1);

      // 创建一个短暂的静音音轨
      final AudioContext =
          js_util.getProperty(js_util.globalThis, 'AudioContext') ??
              js_util.getProperty(js_util.globalThis, 'webkitAudioContext');

      if (AudioContext != null) {
        final audioContext = js_util.callConstructor(AudioContext, []);
        final oscillator =
            js_util.callMethod(audioContext, 'createOscillator', []);

        js_util.callMethod(oscillator, 'connect',
            [js_util.getProperty(audioContext, 'destination')]);
        js_util.callMethod(oscillator, 'start', [0]);
        js_util.callMethod(oscillator, 'stop', [0.1]);
      }

      // 尝试播放一个静音音频
      js_util.setProperty(audioElement, 'src',
          'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=');
      js_util.callMethod(audioElement, 'play', []);

      debugPrint('【RTC引擎】音频播放已恢复');
      return true;
    } catch (e) {
      debugPrint('【RTC引擎】恢复音频播放失败: $e');
      return false;
    }
  }
}
