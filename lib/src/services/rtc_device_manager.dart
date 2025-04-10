import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';

/// 管理RTC设备相关操作的类
class RtcDeviceManager {
  dynamic engineManager;
  dynamic get engine => engineManager?.engine;

  // 音频设备状态
  bool _hasAudioInputPermission = false;
  bool _isCapturingAudio = false;
  bool _isPlayingAudio = false;

  // 设备列表
  List<Map<String, dynamic>> _audioInputDevices = [];
  List<Map<String, dynamic>> _audioOutputDevices = [];

  // 选中的设备ID
  String? _selectedAudioInputDeviceId;
  String? _selectedAudioOutputDeviceId;

  // Getters
  bool get hasAudioInputPermission => _hasAudioInputPermission;
  bool get isCapturingAudio => _isCapturingAudio;
  bool get isPlayingAudio => _isPlayingAudio;
  List<Map<String, dynamic>> get audioInputDevices => _audioInputDevices;
  List<Map<String, dynamic>> get audioOutputDevices => _audioOutputDevices;
  String? get selectedAudioInputDeviceId => _selectedAudioInputDeviceId;
  String? get selectedAudioOutputDeviceId => _selectedAudioOutputDeviceId;

  RtcDeviceManager({required this.engineManager, dynamic config});

  /// 请求麦克风权限
  Future<bool> requestMicrophoneAccess() async {
    try {
      if (engine == null) {
        return false;
      }

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        await WebUtils.waitForSdkLoaded();
      }

      try {
        // 参考web demo，直接使用js_util调用全局VERTC对象上的方法

        // 获取VERTC全局对象
        final vertcObject = js_util.getProperty(js_util.globalThis, 'VERTC');
        if (vertcObject == null) {
          throw Exception('无法访问VERTC全局对象，SDK可能未正确加载');
        }

        // 调用enableDevices方法
        final result = await js_util
            .promiseToFuture(js_util.callMethod(vertcObject, 'enableDevices', [
          js_util.jsify({'audio': true, 'video': false})
        ]));

        // 解析结果
        if (result != null) {
          final audioPermission = js_util.getProperty(result, 'audio');
          _hasAudioInputPermission = audioPermission == true;

          if (_hasAudioInputPermission) {
            // 更新设备列表
            await getAudioInputDevices();
            await getAudioOutputDevices();
            return true;
          } else {
            return false;
          }
        } else {
          _hasAudioInputPermission = false;
          return false;
        }
      } catch (e) {
        // 回退到使用原生浏览器API

        try {
          // 获取navigator对象
          final navigator =
              js_util.getProperty(js_util.globalThis, 'navigator');
          if (navigator == null) {
            throw Exception('无法访问navigator对象');
          }

          // 获取mediaDevices对象
          final mediaDevices = js_util.getProperty(navigator, 'mediaDevices');
          if (mediaDevices == null) {
            throw Exception('无法访问mediaDevices对象，浏览器可能不支持');
          }

          // 调用getUserMedia方法
          final stream = await js_util.promiseToFuture(
              js_util.callMethod(mediaDevices, 'getUserMedia', [
            js_util.jsify({'audio': true, 'video': false})
          ]));

          if (stream != null) {
            _hasAudioInputPermission = true;

            // 释放获取到的媒体流
            try {
              final trackArray = js_util.callMethod(stream, 'getTracks', []);
              final length = js_util.getProperty(trackArray, 'length');

              for (var i = 0; i < length; i++) {
                final track = js_util.getProperty(trackArray, i);
                js_util.callMethod(track, 'stop', []);
              }
            } catch (e2) {}

            // 更新设备列表
            await getAudioInputDevices();
            await getAudioOutputDevices();
            return true;
          } else {
            _hasAudioInputPermission = false;
            return false;
          }
        } catch (e2) {
          _hasAudioInputPermission = false;
          return false;
        }
      }
    } catch (e) {
      _hasAudioInputPermission = false;
      return false;
    }
  }

  /// 获取音频输入设备列表
  Future<List<Map<String, dynamic>>> getAudioInputDevices() async {
    try {
      if (engine == null) {
        return [];
      }

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        await WebUtils.waitForSdkLoaded();
      }

      // 直接使用WebUtils中的新方法获取设备列表
      final devicesList = await WebUtils.getAudioInputDevices();

      // 解析设备信息
      final List<Map<String, dynamic>> devices = [];

      if (devicesList != null) {
        final length = js_util.getProperty(devicesList, 'length');

        for (var i = 0; i < length; i++) {
          final device = js_util.getProperty(devicesList, i);
          final deviceId =
              js_util.getProperty(device, 'deviceId')?.toString() ?? '';

          // 获取设备名称，优先使用label，然后是deviceName
          String deviceName = '';
          final label = js_util.getProperty(device, 'label');
          final name = js_util.getProperty(device, 'deviceName');

          if (label != null && label.toString().isNotEmpty) {
            deviceName = label.toString();
          } else if (name != null && name.toString().isNotEmpty) {
            deviceName = name.toString();
          } else {
            deviceName = '麦克风 $i';
          }

          devices.add({
            'deviceId': deviceId,
            'label': deviceName,
            'kind': 'audioinput'
          });
        }
      }

      _audioInputDevices = devices;

      // 如果有设备但未选择，则选择第一个
      if (_audioInputDevices.isNotEmpty &&
          (_selectedAudioInputDeviceId == null ||
              _selectedAudioInputDeviceId!.isEmpty)) {
        _selectedAudioInputDeviceId = _audioInputDevices[0]['deviceId'];
      }

      return _audioInputDevices;
    } catch (e) {
      return [];
    }
  }

  /// 获取音频输出设备列表
  Future<List<Map<String, dynamic>>> getAudioOutputDevices() async {
    try {
      if (engine == null) {
        return [];
      }

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        await WebUtils.waitForSdkLoaded();
      }

      // 直接使用WebUtils中的新方法获取设备列表
      final devicesList = await WebUtils.getAudioOutputDevices();

      // 解析设备信息
      final List<Map<String, dynamic>> devices = [];

      if (devicesList != null) {
        final length = js_util.getProperty(devicesList, 'length');

        for (var i = 0; i < length; i++) {
          final device = js_util.getProperty(devicesList, i);
          final deviceId =
              js_util.getProperty(device, 'deviceId')?.toString() ?? '';

          // 获取设备名称，优先使用label，然后是deviceName
          String deviceName = '';
          final label = js_util.getProperty(device, 'label');
          final name = js_util.getProperty(device, 'deviceName');

          if (label != null && label.toString().isNotEmpty) {
            deviceName = label.toString();
          } else if (name != null && name.toString().isNotEmpty) {
            deviceName = name.toString();
          } else {
            deviceName = '扬声器 $i';
          }

          devices.add({
            'deviceId': deviceId,
            'label': deviceName,
            'kind': 'audiooutput'
          });
        }
      }

      _audioOutputDevices = devices;

      // 如果有设备但未选择，则选择第一个
      if (_audioOutputDevices.isNotEmpty &&
          (_selectedAudioOutputDeviceId == null ||
              _selectedAudioOutputDeviceId!.isEmpty)) {
        _selectedAudioOutputDeviceId = _audioOutputDevices[0]['deviceId'];
      }

      return _audioOutputDevices;
    } catch (e) {
      return [];
    }
  }

  /// 设置音频输入设备
  Future<bool> setAudioInputDevice(String deviceId) async {
    try {
      if (engine == null) {
        return false;
      }

      // 获取VERTC对象
      final vertcObject = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (vertcObject == null) {
        throw Exception('无法访问VERTC对象');
      }

      // 调用VERTC.setAudioCaptureDevice
      await js_util.promiseToFuture(
          js_util.callMethod(vertcObject, 'setAudioCaptureDevice', [deviceId]));

      _selectedAudioInputDeviceId = deviceId;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 设置音频输出设备
  Future<bool> setAudioOutputDevice(String deviceId) async {
    try {
      if (engine == null) {
        return false;
      }

      // 获取VERTC对象
      final vertcObject = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (vertcObject == null) {
        throw Exception('无法访问VERTC对象');
      }

      // 调用VERTC.setAudioPlaybackDevice
      await js_util.promiseToFuture(js_util
          .callMethod(vertcObject, 'setAudioPlaybackDevice', [deviceId]));

      _selectedAudioOutputDeviceId = deviceId;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 开始音频采集
  Future<bool> startAudioCapture({String? deviceId}) async {
    try {
      if (engine == null) {
        return false;
      }

      if (_isCapturingAudio) {
        return true;
      }

      // 检查麦克风权限
      if (!_hasAudioInputPermission) {
        final hasPermission = await requestMicrophoneAccess();
        if (!hasPermission) {
          return false;
        }
      }

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        await WebUtils.waitForSdkLoaded();
      }

      try {
        // 获取引擎实例
        final engineObj = engine;
        if (engineObj == null) {
          throw Exception('引擎对象为空，无法开始音频采集');
        }

        // 如果指定了设备ID，先设置捕获设备
        if (deviceId != null && deviceId.isNotEmpty) {
          try {
            await js_util.promiseToFuture(js_util
                .callMethod(engineObj, 'setAudioCaptureDevice', [deviceId]));
            _selectedAudioInputDeviceId = deviceId;
          } catch (e) {}
        }

        // 调用startAudioCapture方法 - 参考web demo直接使用engine对象
        final effectiveDeviceId = deviceId ?? _selectedAudioInputDeviceId;

        await js_util.promiseToFuture(js_util.callMethod(
            engineObj,
            'startAudioCapture',
            effectiveDeviceId != null ? [effectiveDeviceId] : []));

        _isCapturingAudio = true;
        return true;
      } catch (e) {
        _isCapturingAudio = false;

        // 尝试使用VERTC全局对象作为备选方案
        try {
          final vertcObject = js_util.getProperty(js_util.globalThis, 'VERTC');
          if (vertcObject == null) {
            throw Exception('无法访问VERTC全局对象，SDK可能未正确加载');
          }

          await js_util.promiseToFuture(
              js_util.callMethod(vertcObject, 'startAudioCapture', []));

          _isCapturingAudio = true;
          return true;
        } catch (e2) {
          return false;
        }
      }
    } catch (e) {
      _isCapturingAudio = false;
      return false;
    }
  }

  /// 停止音频采集
  Future<bool> stopAudioCapture() async {
    try {
      if (engine == null) {
        return false;
      }

      if (!_isCapturingAudio) {
        return true;
      }

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        return false;
      }

      try {
        // 获取引擎实例
        final engineObj = engine;
        if (engineObj == null) {
          throw Exception('引擎对象为空，无法停止音频采集');
        }

        // 调用stopAudioCapture方法 - 参考web demo直接使用engine对象
        await js_util.promiseToFuture(
            js_util.callMethod(engineObj, 'stopAudioCapture', []));

        _isCapturingAudio = false;
        return true;
      } catch (e) {
        // 尝试使用VERTC全局对象作为备选方案
        try {
          final vertcObject = js_util.getProperty(js_util.globalThis, 'VERTC');
          if (vertcObject == null) {
            throw Exception('无法访问VERTC全局对象，SDK可能未正确加载');
          }

          await js_util.promiseToFuture(
              js_util.callMethod(vertcObject, 'stopAudioCapture', []));

          _isCapturingAudio = false;
          return true;
        } catch (e2) {
          return false;
        }
      }
    } catch (e) {
      return false;
    }
  }

  /// 恢复音频播放（解决浏览器自动播放限制问题）
  Future<bool> resumeAudioPlayback() async {
    try {
      if (engine == null) {
        return false;
      }

      // 使用WebUtils创建和播放临时音频来解除浏览器自动播放限制
      try {
        // 创建AudioContext
        final hasAudioContext =
            await WebUtils.checkObjectExists('AudioContext') ||
                await WebUtils.checkObjectExists('webkitAudioContext');

        if (!hasAudioContext) {
          return false;
        }

        // 获取正确的AudioContext构造函数
        final contextName = await WebUtils.checkObjectExists('AudioContext')
            ? 'AudioContext'
            : 'webkitAudioContext';

        // 创建一个短暂的静音音轨
        final audioContextObj =
            await WebUtils.callGlobalMethodAsync('new ' + contextName, []);

        if (audioContextObj != null) {
          // 创建振荡器
          final oscillator = await WebUtils.callMethodAsync(
              audioContextObj, 'createOscillator', []);

          // 连接到输出
          final destination =
              js_util.getProperty(audioContextObj, 'destination');
          await WebUtils.callMethodAsync(oscillator, 'connect', [destination]);

          // 播放很短的音频
          await WebUtils.callMethodAsync(oscillator, 'start', [0]);
          await WebUtils.callMethodAsync(oscillator, 'stop', [0.1]);

          _isPlayingAudio = true;
          return true;
        } else {
          return false;
        }
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// 设置音频采集音量
  Future<bool> setAudioCaptureVolume(int volume) async {
    try {
      if (engine == null) {
        return false;
      }

      // 验证音量值
      final int safeVolume = volume.clamp(0, 100);

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        await WebUtils.waitForSdkLoaded();
      }

      // 获取VERTC对象
      final vertcObject = WebUtils.getJsProperty('VERTC');
      if (vertcObject == null) {
        throw Exception('无法访问VERTC对象，SDK可能未正确加载');
      }

      // 调用VERTC.setCaptureVolume
      await WebUtils.callMethodAsync(
          vertcObject, 'setCaptureVolume', [safeVolume]);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 设置音频播放音量
  Future<bool> setAudioPlaybackVolume(int volume) async {
    try {
      if (engine == null) {
        return false;
      }

      // 验证音量值
      final int safeVolume = volume.clamp(0, 100);

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        await WebUtils.waitForSdkLoaded();
      }

      // 获取VERTC对象
      final vertcObject = WebUtils.getJsProperty('VERTC');
      if (vertcObject == null) {
        throw Exception('无法访问VERTC对象，SDK可能未正确加载');
      }

      // 调用VERTC.setPlaybackVolume
      await WebUtils.callMethodAsync(
          vertcObject, 'setPlaybackVolume', [safeVolume]);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    try {
      if (_isCapturingAudio) {
        stopAudioCapture();
      }

      _audioInputDevices = [];
      _audioOutputDevices = [];
      _selectedAudioInputDeviceId = null;
      _selectedAudioOutputDeviceId = null;
      _hasAudioInputPermission = false;
      _isCapturingAudio = false;
      _isPlayingAudio = false;
    } catch (e) {}
  }

  /// 设置音频采集设备
  Future<bool> setAudioCaptureDevice(String deviceId) async {
    try {
      if (engine == null) {
        return false;
      }

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        await WebUtils.waitForSdkLoaded();
      }

      // 获取VERTC对象
      final vertcObject = WebUtils.getJsProperty('VERTC');
      if (vertcObject == null) {
        throw Exception('无法访问VERTC对象，SDK可能未正确加载');
      }

      // 调用VERTC.setAudioCaptureDevice
      await WebUtils.callMethodAsync(
          vertcObject, 'setAudioCaptureDevice', [deviceId]);

      _selectedAudioInputDeviceId = deviceId;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 设置音频播放设备
  Future<bool> setAudioPlaybackDevice(String deviceId) async {
    try {
      if (engine == null) {
        return false;
      }

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        await WebUtils.waitForSdkLoaded();
      }

      // 获取VERTC对象
      final vertcObject = WebUtils.getJsProperty('VERTC');
      if (vertcObject == null) {
        throw Exception('无法访问VERTC对象，SDK可能未正确加载');
      }

      // 调用VERTC.setAudioPlaybackDevice
      await WebUtils.callMethodAsync(
          vertcObject, 'setAudioPlaybackDevice', [deviceId]);

      _selectedAudioOutputDeviceId = deviceId;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取当前音频输入设备ID
  Future<String?> getCurrentAudioInputDeviceId() async {
    try {
      if (engine == null) {
        return null;
      }

      return _selectedAudioInputDeviceId;
    } catch (e) {
      return null;
    }
  }

  /// 获取当前音频输出设备ID
  Future<String?> getCurrentAudioOutputDeviceId() async {
    try {
      if (engine == null) {
        return null;
      }

      return _selectedAudioOutputDeviceId;
    } catch (e) {
      return null;
    }
  }

  /// 请求摄像头访问权限
  Future<bool> requestCameraAccess() async {
    try {
      if (engine == null) {
        return false;
      }

      // 确保SDK已加载
      if (!WebUtils.isSdkLoaded()) {
        await WebUtils.waitForSdkLoaded();
      }

      try {
        // 参考web demo，直接使用js_util调用全局VERTC对象上的方法

        // 获取VERTC全局对象
        final vertcObject = js_util.getProperty(js_util.globalThis, 'VERTC');
        if (vertcObject == null) {
          throw Exception('无法访问VERTC全局对象，SDK可能未正确加载');
        }

        // 调用enableDevices方法
        final result = await js_util
            .promiseToFuture(js_util.callMethod(vertcObject, 'enableDevices', [
          js_util.jsify({'audio': false, 'video': true})
        ]));

        // 解析结果
        if (result != null) {
          final videoPermission = js_util.getProperty(result, 'video');
          final hasVideoPermission = videoPermission == true;

          if (hasVideoPermission) {
            return true;
          } else {
            return false;
          }
        } else {
          return false;
        }
      } catch (e) {
        // 回退到使用原生浏览器API

        try {
          // 获取navigator对象
          final navigator =
              js_util.getProperty(js_util.globalThis, 'navigator');
          if (navigator == null) {
            throw Exception('无法访问navigator对象');
          }

          // 获取mediaDevices对象
          final mediaDevices = js_util.getProperty(navigator, 'mediaDevices');
          if (mediaDevices == null) {
            throw Exception('无法访问mediaDevices对象，浏览器可能不支持');
          }

          // 调用getUserMedia方法
          final stream = await js_util.promiseToFuture(
              js_util.callMethod(mediaDevices, 'getUserMedia', [
            js_util.jsify({'audio': false, 'video': true})
          ]));

          if (stream != null) {
            // 释放获取到的媒体流
            try {
              final trackArray = js_util.callMethod(stream, 'getTracks', []);
              final length = js_util.getProperty(trackArray, 'length');

              for (var i = 0; i < length; i++) {
                final track = js_util.getProperty(trackArray, i);
                js_util.callMethod(track, 'stop', []);
              }
            } catch (e2) {}

            return true;
          } else {
            return false;
          }
        } catch (e2) {
          return false;
        }
      }
    } catch (e) {
      return false;
    }
  }
}
