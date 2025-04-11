import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_engine_manager.dart';
import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';

import '../../rtc_aigc_plugin.dart';

/// 管理RTC设备相关操作的类
class RtcDeviceManager {
  /// 引擎管理器引用
  RtcEngineManager engineManager;
  dynamic get engine => engineManager.engine;

  /// 音频设备状态
  bool _hasAudioInputPermission = false;
  bool _isCapturingAudio = false;
  bool _isPlayingAudio = false;

  /// 设备列表
  List<Map<String, dynamic>> _audioInputDevices = [];
  List<Map<String, dynamic>> _audioOutputDevices = [];

  /// 选中的设备ID
  String? _selectedAudioInputDeviceId;
  String? _selectedAudioOutputDeviceId;

  /// 构造函数
  RtcDeviceManager({
    required this.engineManager,
  });
  void setEngine(dynamic rtcClient) {
    if (engine == null) {
      engineManager.engine = (rtcClient);
    }
  }

  /// 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return false;
      }

      final result = await WebUtils.callMethodAsync(
        engine,
        'requestMicrophonePermission',
        [],
      );

      _hasAudioInputPermission = result == true;
      return _hasAudioInputPermission;
    } catch (e) {
      debugPrint('RtcDeviceManager: 请求麦克风权限失败: $e');
      return false;
    }
  }

  /// 获取音频输入设备列表
  Future<List<Map<String, dynamic>>> getAudioInputDevices() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return [];
      }

      final devices = await WebUtils.callMethodAsync(
        engine,
        'getAudioInputDevices',
        [],
      );

      if (devices != null) {
        _audioInputDevices = List<Map<String, dynamic>>.from(devices);
      }

      return _audioInputDevices;
    } catch (e) {
      debugPrint('RtcDeviceManager: 获取音频输入设备列表失败: $e');
      return [];
    }
  }

  /// 获取音频输出设备列表
  Future<List<Map<String, dynamic>>> getAudioOutputDevices() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return [];
      }

      final devices = await WebUtils.callMethodAsync(
        engine,
        'getAudioOutputDevices',
        [],
      );

      if (devices != null) {
        _audioOutputDevices = List<Map<String, dynamic>>.from(devices);
      }

      return _audioOutputDevices;
    } catch (e) {
      debugPrint('RtcDeviceManager: 获取音频输出设备列表失败: $e');
      return [];
    }
  }

  /// 设置音频采集设备
  Future<bool> setAudioCaptureDevice(String deviceId) async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return false;
      }

      final success = await WebUtils.callMethodAsync(
        engine,
        'setAudioCaptureDevice',
        [deviceId],
      );

      if (success == true) {
        _selectedAudioInputDeviceId = deviceId;
      }

      return success == true;
    } catch (e) {
      debugPrint('RtcDeviceManager: 设置音频采集设备失败: $e');
      return false;
    }
  }

  /// 设置音频播放设备
  Future<bool> setAudioPlaybackDevice(String deviceId) async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return false;
      }

      final success = await WebUtils.callMethodAsync(
        engine,
        'setAudioPlaybackDevice',
        [deviceId],
      );

      if (success == true) {
        _selectedAudioOutputDeviceId = deviceId;
      }

      return success == true;
    } catch (e) {
      debugPrint('RtcDeviceManager: 设置音频播放设备失败: $e');
      return false;
    }
  }

  /// 开始音频采集
  Future<bool> startAudioCapture({String? deviceId}) async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return false;
      }

      if (_isCapturingAudio) {
        debugPrint('RtcDeviceManager: 已在采集音频');
        return true;
      }

      // 如果指定了设备ID，先设置设备
      if (deviceId != null) {
        final setDeviceSuccess = await setAudioCaptureDevice(deviceId);
        if (!setDeviceSuccess) {
          debugPrint('RtcDeviceManager: 设置音频采集设备失败');
          return false;
        }
      }

      final success = await WebUtils.callMethodAsync(
        engine,
        'startAudioCapture',
        [],
      );

      _isCapturingAudio = success == true;
      return _isCapturingAudio;
    } catch (e) {
      debugPrint('RtcDeviceManager: 开始音频采集失败: $e');
      return false;
    }
  }

  /// 停止音频采集
  Future<bool> stopAudioCapture() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return false;
      }

      if (!_isCapturingAudio) {
        debugPrint('RtcDeviceManager: 未在采集音频');
        return true;
      }

      final success = await WebUtils.callMethodAsync(
        engine,
        'stopAudioCapture',
        [],
      );

      _isCapturingAudio = !(success == true);
      return success == true;
    } catch (e) {
      debugPrint('RtcDeviceManager: 停止音频采集失败: $e');
      return false;
    }
  }

  /// 获取当前音频输入设备ID
  Future<String?> getCurrentAudioInputDeviceId() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return null;
      }

      final deviceId = await WebUtils.callMethodAsync(
        engine,
        'getCurrentAudioInputDeviceId',
        [],
      );

      return deviceId?.toString();
    } catch (e) {
      debugPrint('RtcDeviceManager: 获取当前音频输入设备ID失败: $e');
      return null;
    }
  }

  /// 获取当前音频输出设备ID
  Future<String?> getCurrentAudioOutputDeviceId() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return null;
      }

      final deviceId = await WebUtils.callMethodAsync(
        engine,
        'getCurrentAudioOutputDeviceId',
        [],
      );

      return deviceId?.toString();
    } catch (e) {
      debugPrint('RtcDeviceManager: 获取当前音频输出设备ID失败: $e');
      return null;
    }
  }

  /// 请求摄像头访问权限
  Future<bool> requestCameraAccess() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return false;
      }

      final result = await WebUtils.callMethodAsync(
        engine,
        'requestCameraAccess',
        [],
      );

      return result == true;
    } catch (e) {
      debugPrint('RtcDeviceManager: 请求摄像头访问权限失败: $e');
      return false;
    }
  }

  // Getters
  bool get hasAudioInputPermission => _hasAudioInputPermission;
  bool get isCapturingAudio => _isCapturingAudio;
  bool get isPlayingAudio => _isPlayingAudio;
  List<Map<String, dynamic>> get audioInputDevices => _audioInputDevices;
  List<Map<String, dynamic>> get audioOutputDevices => _audioOutputDevices;
  String? get selectedAudioInputDeviceId => _selectedAudioInputDeviceId;
  String? get selectedAudioOutputDeviceId => _selectedAudioOutputDeviceId;
}
