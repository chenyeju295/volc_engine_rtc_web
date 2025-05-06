import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:volc_engine_rtc_web/src/services/rtc_engine_manager.dart';
import 'package:volc_engine_rtc_web/src/utils/web_utils.dart';

import '../../volc_engine_rtc_web.dart';

/// 音频操作结果类，统一返回格式
class AudioResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? trackSettings;
  
  AudioResult({
    required this.success, 
    this.errorCode, 
    this.errorMessage, 
    this.trackSettings
  });
  
  /// 转换为Map，便于序列化和传递
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'error': errorMessage,
      if (trackSettings != null) 'trackSettings': trackSettings,
    };
  }
  
  /// 从布尔值创建成功结果
  factory AudioResult.fromBool(bool result) {
    return AudioResult(success: result);
  }
  
  /// 创建失败结果
  factory AudioResult.failure(String errorMessage, [String? errorCode]) {
    return AudioResult(
      success: false,
      errorMessage: errorMessage,
      errorCode: errorCode ?? 'UNKNOWN_ERROR'
    );
  }
  
  /// 创建成功结果
  factory AudioResult.success([Map<String, dynamic>? trackSettings]) {
    return AudioResult(
      success: true,
      trackSettings: trackSettings
    );
  }
}

/// 音频错误码常量
class AudioErrorCode {
  static const String UNKNOWN_ERROR = 'UNKNOWN_ERROR';
  static const String REPEAT_CAPTURE = 'REPEAT_CAPTURE';
  static const String GET_AUDIO_TRACK_FAILED = 'GET_AUDIO_TRACK_FAILED';
  static const String STREAM_TYPE_NOT_MATCH = 'STREAM_TYPE_NOT_MATCH';
  static const String ENGINE_NOT_INITIALIZED = 'ENGINE_NOT_INITIALIZED';
  static const String NOT_IN_ROOM = 'NOT_IN_ROOM';
}

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
  
  /// 状态流控制器
  final StreamController<bool> _audioStatusController = 
      StreamController<bool>.broadcast();
  
  /// 设备变更流控制器
  final StreamController<List<Map<String, dynamic>>> _deviceChangeController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// 构造函数
  RtcDeviceManager({
    required this.engineManager,
  }) {
    // 不再自动调用_setupDeviceListener
  }
  
  /// 设置设备变更监听 - 移除定时刷新逻辑
  void _setupDeviceListener() {
    // 移除定时器逻辑，改为手动调用
    // 可以在这里添加原生设备变更事件监听（如果平台支持）
  }
  
  /// 刷新设备列表 - 需要用户手动调用
  /// 
  /// 手动获取当前可用的音频设备列表，并在设备发生变化时发送通知
  /// @return 可用的音频输入设备列表
  Future<List<Map<String, dynamic>>> refreshDevices() async {
    try {
      final oldDevices = List<Map<String, dynamic>>.from(_audioInputDevices);
      await getAudioInputDevices();
      
      // 同时获取输出设备
      await getAudioOutputDevices();
      
      // 检查设备列表是否有变化
      if (_audioInputDevices.length != oldDevices.length) {
        _deviceChangeController.add(_audioInputDevices);
      } else {
        // 检查设备ID是否有变化
        bool changed = false;
        for (int i = 0; i < _audioInputDevices.length; i++) {
          if (i >= oldDevices.length || 
              _audioInputDevices[i]['deviceId'] != oldDevices[i]['deviceId']) {
            changed = true;
            break;
          }
        }
        
        if (changed) {
          _deviceChangeController.add(_audioInputDevices);
        }
      }
      
      return _audioInputDevices;
    } catch (e) {
      debugPrint('刷新设备列表失败: $e');
      return [];
    }
  }
  
  void setEngine(dynamic rtcClient) {
    if (engine == null) {
      engineManager.engine = (rtcClient);
    }
  }

  /// 获取音频输入设备列表
  Future<List<Map<String, dynamic>>> getAudioInputDevices() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return [];
      }

      final devices = await WebUtils.getAudioInputDevices();
      if (devices.isNotEmpty) {
        _audioInputDevices = [];
        for (var device in devices) {
          try {
            final deviceObj = js_util.dartify(device);
            if (deviceObj is Map) {
              _audioInputDevices.add(Map<String, dynamic>.from(deviceObj));
            }
          } catch (e) {
            debugPrint('设备数据转换失败: $e');
          }
        }
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

      final devices = await WebUtils.getAudioOutputDevices();
      if (devices.isNotEmpty) {
        _audioOutputDevices = [];
        for (var device in devices) {
          try {
            final deviceObj = js_util.dartify(device);
            if (deviceObj is Map) {
              _audioOutputDevices.add(Map<String, dynamic>.from(deviceObj));
            }
          } catch (e) {
            debugPrint('设备数据转换失败: $e');
          }
        }
      }

      return _audioOutputDevices;
    } catch (e) {
      debugPrint('RtcDeviceManager: 获取音频输出设备列表失败: $e');
      return [];
    }
  }

  /// 开始音频采集
  /// 
  /// 开启内部音频采集。默认为关闭状态。
  /// 内部采集是指：使用 RTC SDK 内置采集机制进行音频采集。
  /// 可见用户进房后调用该方法，房间中的其他用户会收到 onUserStartAudioCapture 的回调。
  /// 
  /// @param deviceId 设备 ID，传入采集音频的设备 ID，以免出现无声等异常。可通过 getAudioInputDevices 获取设备列表。
  /// @return 统一的AudioResult对象，包含操作结果和错误信息
  Future<AudioResult> startAudioCapture({String? deviceId}) async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return AudioResult.failure('引擎未设置', AudioErrorCode.ENGINE_NOT_INITIALIZED);
      }

      if (_isCapturingAudio) {
        debugPrint('RtcDeviceManager: 已在采集音频');
        return AudioResult.failure('重复采集', AudioErrorCode.REPEAT_CAPTURE);
      }
      
      // 如果指定了设备ID，先设置设备
      if (deviceId != null && deviceId.isNotEmpty) {
        try {
          await js_util.promiseToFuture(
            js_util.callMethod(engine, 'setAudioCaptureDevice', [deviceId])
          );
          _selectedAudioInputDeviceId = deviceId;
          debugPrint('已设置音频采集设备: $deviceId');
        } catch (e) {
          debugPrint('设置音频采集设备失败: $e');
          // 继续尝试开启采集，使用默认设备
        }
      }

      try {
        // 调用原生startAudioCapture方法
        final resultPromise = js_util.callMethod(engine, 'startAudioCapture', []);
        final trackSettings = await js_util.promiseToFuture(resultPromise);
        
        // 转换音频轨道设置为Dart Map
        Map<String, dynamic>? settings;
        if (trackSettings != null) {
          try {
            final settingsObj = js_util.dartify(trackSettings);
            if (settingsObj is Map) {
              settings = Map<String, dynamic>.from(settingsObj);
            }
          } catch (e) {
            debugPrint('音频轨道设置转换失败: $e');
          }
        }
        
        _isCapturingAudio = true;
        _audioStatusController.add(true);
        
        debugPrint('音频采集启动成功${settings != null ? ": $settings" : ""}');
        return AudioResult.success(settings);
      } catch (e) {
        // 解析常见错误
        String errorMsg = e.toString();
        String errorCode = AudioErrorCode.UNKNOWN_ERROR;
        
        if (errorMsg.contains('REPEAT_CAPTURE')) {
          errorCode = AudioErrorCode.REPEAT_CAPTURE;
          errorMsg = '重复采集';
        } else if (errorMsg.contains('GET_AUDIO_TRACK_FAILED') || 
                   errorMsg.contains('Cannot read property') || 
                   errorMsg.contains('获取音频Track失败')) {
          errorCode = AudioErrorCode.GET_AUDIO_TRACK_FAILED;
          errorMsg = '采集音频失败，请确认是否有可用的采集设备，或是否被其他应用占用';
        } else if (errorMsg.contains('STREAM_TYPE_NOT_MATCH')) {
          errorCode = AudioErrorCode.STREAM_TYPE_NOT_MATCH;
          errorMsg = '流类型不匹配。调用setAudioSourceType设置了自定义媒体源后，又调用内部采集相关的接口';
        }
        
        debugPrint('音频采集启动失败: [$errorCode] $errorMsg');
        return AudioResult.failure(errorMsg, errorCode);
      }
    } catch (e) {
      debugPrint('开启音频采集过程发生未知错误: $e');
      return AudioResult.failure(e.toString());
    }
  }

  /// 停止音频采集
  /// 
  /// 立即关闭内部音频采集。
  /// 发布流后调用该方法，房间内的其他用户会收到 onUserStopAudioCapture 的回调。
  /// 
  /// 注意：
  /// - 调用 startAudioCapture 可以开启内部音频采集。
  /// - 如果不调用本方法停止内部音频采集，则只有当销毁引擎实例时，内部音频采集才会停止。
  /// 
  /// @return 统一的AudioResult对象，包含操作结果和错误信息
  Future<AudioResult> stopAudioCapture() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return AudioResult.failure('引擎未设置', AudioErrorCode.ENGINE_NOT_INITIALIZED);
      }

      if (!_isCapturingAudio) {
        debugPrint('RtcDeviceManager: 未在采集音频');
        return AudioResult.success();
      }

      try {
        // 调用原生stopAudioCapture方法
        final resultPromise = js_util.callMethod(engine, 'stopAudioCapture', []);
        await js_util.promiseToFuture(resultPromise);
        
        _isCapturingAudio = false;
        _audioStatusController.add(false);
        
        debugPrint('音频采集停止成功');
        return AudioResult.success();
      } catch (e) {
        // 解析常见错误
        String errorMsg = e.toString();
        String errorCode = AudioErrorCode.UNKNOWN_ERROR;
        
        if (errorMsg.contains('STREAM_TYPE_NOT_MATCH')) {
          errorCode = AudioErrorCode.STREAM_TYPE_NOT_MATCH;
          errorMsg = '流类型不匹配。调用setAudioSourceType设置了自定义媒体源后，又调用内部采集相关的接口';
        }
        
        debugPrint('音频采集停止失败: [$errorCode] $errorMsg');
        return AudioResult.failure(errorMsg, errorCode);
      }
    } catch (e) {
      debugPrint('停止音频采集过程发生未知错误: $e');
      return AudioResult.failure(e.toString());
    }
  }

  /// 切换音频设备
  /// @param deviceId 音频设备ID
  /// @return 成功返回true，失败返回false
  Future<AudioResult> switchAudioDevice(String deviceId) async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return AudioResult.failure('引擎未设置', AudioErrorCode.ENGINE_NOT_INITIALIZED);
      }

      debugPrint('切换音频设备: $deviceId');
      
      try {
        // 设置音频采集设备
        await js_util.promiseToFuture(
          js_util.callMethod(engine, 'setAudioCaptureDevice', [deviceId])
        );
        
        _selectedAudioInputDeviceId = deviceId;
        debugPrint('音频设备切换成功');
        return AudioResult.success();
      } catch (e) {
        debugPrint('切换音频设备失败: $e');
        return AudioResult.failure('切换音频设备失败: $e');
      }
    } catch (e) {
      debugPrint('切换音频设备过程发生未知错误: $e');
      return AudioResult.failure(e.toString());
    }
  }

  /// 设置音频采集音量
  /// @param volume 音量大小，范围[0-100]
  /// @return 成功返回true，失败返回false
  Future<AudioResult> setAudioCaptureVolume(int volume) async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return AudioResult.failure('引擎未设置', AudioErrorCode.ENGINE_NOT_INITIALIZED);
      }

      // 确保音量在正确范围内
      final int safeVolume = volume.clamp(0, 100);
      debugPrint('设置音频采集音量: $safeVolume');
      
      try {
        // 设置主流和屏幕共享流的音量
        // StreamIndex.STREAM_INDEX_MAIN = 0
        js_util.callMethod(engine, 'setCaptureVolume', [0, safeVolume]);
        
        // StreamIndex.STREAM_INDEX_SCREEN = 1 (可选)
        js_util.callMethod(engine, 'setCaptureVolume', [1, safeVolume]);
        
        debugPrint('音频采集音量设置成功');
        return AudioResult.success();
      } catch (e) {
        debugPrint('设置音频采集音量失败: $e');
        return AudioResult.failure('设置音频采集音量失败: $e');
      }
    } catch (e) {
      debugPrint('设置音频采集音量过程发生未知错误: $e');
      return AudioResult.failure(e.toString());
    }
  }

  /// 获取当前音频输入设备ID
  Future<String?> getCurrentAudioInputDeviceId() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return null;
      }

      // 优先返回已记录的设备ID
      if (_selectedAudioInputDeviceId != null) {
        return _selectedAudioInputDeviceId;
      }

      try {
        final deviceId = await WebUtils.callMethodAsync(
          engine,
          'getCurrentAudioInputDeviceId',
          [],
        );
        
        if (deviceId != null) {
          _selectedAudioInputDeviceId = deviceId.toString();
        }
        
        return _selectedAudioInputDeviceId;
      } catch (e) {
        debugPrint('RtcDeviceManager: 获取当前音频输入设备ID失败: $e');
        return null;
      }
    } catch (e) {
      debugPrint('RtcDeviceManager: 获取当前音频输入设备ID过程发生未知错误: $e');
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

      // 优先返回已记录的设备ID
      if (_selectedAudioOutputDeviceId != null) {
        return _selectedAudioOutputDeviceId;
      }

      try {
        final deviceId = await WebUtils.callMethodAsync(
          engine,
          'getCurrentAudioOutputDeviceId',
          [],
        );
        
        if (deviceId != null) {
          _selectedAudioOutputDeviceId = deviceId.toString();
        }
        
        return _selectedAudioOutputDeviceId;
      } catch (e) {
        debugPrint('RtcDeviceManager: 获取当前音频输出设备ID失败: $e');
        return null;
      }
    } catch (e) {
      debugPrint('RtcDeviceManager: 获取当前音频输出设备ID过程发生未知错误: $e');
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

      // 调用WebUtils中的getUserMedia方法
      final result = await WebUtils.enableDevices(video: true, audio: false);
      
      return result['video'] == true;
    } catch (e) {
      debugPrint('RtcDeviceManager: 请求摄像头权限失败: $e');
      return false;
    }
  }

  /// 请求麦克风访问权限
  Future<bool> requestMicrophoneAccess() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return false;
      }

      // 调用WebUtils中的getUserMedia方法
      final result = await WebUtils.enableDevices(video: false, audio: true);
      _hasAudioInputPermission = result['audio'] == true;
      
      return _hasAudioInputPermission;
    } catch (e) {
      debugPrint('RtcDeviceManager: 请求麦克风权限失败: $e');
      return false;
    }
  }

  /// 获取设备权限
  /// 
  /// 向用户请求音频和/或视频设备的访问权限
  /// @param options 请求选项，包含audio和video布尔值
  /// @return 权限获取结果
  Future<Map<String, dynamic>> enableDevices({
    bool video = false,
    bool audio = true, 
  }) async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return {
          'success': false,
          'audio': false,
          'video': false,
          'error': '引擎未设置'
        };
      }

      // 调用WebUtils中的enableDevices方法
      final result = await WebUtils.enableDevices(
        video: video,
        audio: audio,
      );
      
      // 更新音频权限状态
      if (audio) {
        _hasAudioInputPermission = result['audio'] == true;
      }
      
      // 权限获取后刷新设备列表
      if ((audio && result['audio'] == true) || (video && result['video'] == true)) {
        await refreshDevices();
      }
      
      // 添加success字段使返回格式与其他方法一致
      result['success'] = (audio && !result['audio'] == true) || 
                          (video && !result['video'] == true) 
                          ? false : true;
      
      return result;
    } catch (e) {
      debugPrint('RtcDeviceManager: 获取设备权限失败: $e');
      return {
        'success': false,
        'audio': false,
        'video': false,
        'error': e.toString()
      };
    }
  }

  /// 枚举所有媒体设备
  /// 
  /// 获取系统中所有可用的媒体输入和输出设备列表
  /// 注意：浏览器只有在已经获得设备权限时，才能准确获取设备信息
  /// 推荐在调用enableDevices获取权限后使用本方法
  /// 
  /// @return 所有媒体设备的列表
  Future<List<Map<String, dynamic>>> enumerateDevices() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return [];
      }

      // 调用WebUtils中的enumerateDevices方法
      final devices = await WebUtils.enumerateDevices();
      final List<Map<String, dynamic>> result = [];
      
      // 将设备信息转换为Dart格式
      if (devices.isNotEmpty) {
        for (var device in devices) {
          try {
            final deviceObj = js_util.dartify(device);
            if (deviceObj is Map) {
              result.add(Map<String, dynamic>.from(deviceObj));
            }
          } catch (e) {
            debugPrint('设备数据转换失败: $e');
          }
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('RtcDeviceManager: 枚举设备失败: $e');
      return [];
    }
  }

  /// 恢复音频播放
  /// 用于处理自动播放策略限制
  Future<bool> resumeAudioPlayback() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return false;
      }

      debugPrint('尝试恢复音频播放...');

      try {
        // 创建空白音频元素，播放静音音频来绕过浏览器自动播放限制
        final document = js_util.getProperty(js_util.globalThis, 'document');
        final audioElement = js_util.callMethod(document, 'createElement', ['audio']);

        // 设置音频属性
        js_util.setProperty(audioElement, 'volume', 0.1);

        // 创建一个短暂的静音音轨
        final AudioContext = js_util.getProperty(js_util.globalThis, 'AudioContext') ??
            js_util.getProperty(js_util.globalThis, 'webkitAudioContext');

        if (AudioContext != null) {
          final audioContext = js_util.callConstructor(AudioContext, []);
          final oscillator = js_util.callMethod(audioContext, 'createOscillator', []);

          js_util.callMethod(oscillator, 'connect',
              [js_util.getProperty(audioContext, 'destination')]);
          js_util.callMethod(oscillator, 'start', [0]);
          js_util.callMethod(oscillator, 'stop', [0.1]);
        }

        // 尝试播放一个静音音频
        js_util.setProperty(audioElement, 'src',
            'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=');
        await js_util.promiseToFuture(js_util.callMethod(audioElement, 'play', []));
        
        _isPlayingAudio = true;
        debugPrint('音频播放已恢复');
        return true;
      } catch (e) {
        debugPrint('恢复音频播放失败: $e');
        return false;
      }
    } catch (e) {
      debugPrint('恢复音频播放过程发生未知错误: $e');
      return false;
    }
  }

  /// 启动音频播放设备测试
  /// 
  /// 测试启动后，循环播放指定的音频文件，同时会触发音量回调
  /// 
  /// @param filePath 指定播放设备检测的音频文件网络地址。包括格式 wav 和 mp3
  /// @param indicationInterval 音量回调的时间间隔，单位为毫秒，推荐设置200毫秒以上
  /// @return 测试结果 AudioResult
  Future<AudioResult> startAudioPlaybackDeviceTest(String filePath, int indicationInterval) async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return AudioResult.failure('引擎未设置', AudioErrorCode.ENGINE_NOT_INITIALIZED);
      }
      
      debugPrint('开始音频播放设备测试: $filePath, 间隔: $indicationInterval ms');
      
      try {
        // 调用SDK方法
        await WebUtils.callJsAsync(
          engine, 
          'startAudioPlaybackDeviceTest', 
          [filePath, indicationInterval]
        );
        
        debugPrint('音频播放设备测试启动成功');
        return AudioResult.success();
      } catch (e) {
        debugPrint('启动音频播放设备测试失败: $e');
        return AudioResult.failure('启动音频播放设备测试失败: $e');
      }
    } catch (e) {
      debugPrint('启动音频播放设备测试过程发生未知错误: $e');
      return AudioResult.failure(e.toString());
    }
  }
  
  /// 停止音频播放设备测试
  /// 
  /// @return 测试结果 AudioResult
  Future<AudioResult> stopAudioPlaybackDeviceTest() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return AudioResult.failure('引擎未设置', AudioErrorCode.ENGINE_NOT_INITIALIZED);
      }
      
      debugPrint('停止音频播放设备测试');
      
      try {
        // 调用SDK方法
        WebUtils.callJs(engine, 'stopAudioPlaybackDeviceTest', []);
        
        debugPrint('音频播放设备测试停止成功');
        return AudioResult.success();
      } catch (e) {
        debugPrint('停止音频播放设备测试失败: $e');
        return AudioResult.failure('停止音频播放设备测试失败: $e');
      }
    } catch (e) {
      debugPrint('停止音频播放设备测试过程发生未知错误: $e');
      return AudioResult.failure(e.toString());
    }
  }
  
  /// 开始音频采集设备和播放设备测试
  /// 
  /// 测试开始后，音频设备开始采集本地声音，30秒后自动停止采集并播放
  /// 
  /// @param indicationInterval 音量回调的时间间隔，单位为毫秒，推荐设置200毫秒以上
  /// @param onAutoplayFailed 由于浏览器自动播放策略影响，导致录制音频播放失败时回调
  /// @return 测试结果 AudioResult
  Future<AudioResult> startAudioDeviceRecordTest(
      int indicationInterval,
      {Function? onAutoplayFailed}) async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return AudioResult.failure('引擎未设置', AudioErrorCode.ENGINE_NOT_INITIALIZED);
      }
      
      debugPrint('开始音频设备录制测试，间隔: $indicationInterval ms');
      
      try {
        // 处理回调函数
        dynamic wrappedCallback;
        if (onAutoplayFailed != null) {
          wrappedCallback = js_util.allowInterop((resume) {
            // 包装resume函数为Future
            final Future<dynamic> Function() wrappedResume = () async {
              try {
                final jsResult = resume();
                return js_util.promiseToFuture(jsResult);
              } catch (e) {
                debugPrint('恢复播放失败: $e');
                return null;
              }
            };
            
            // 调用回调
            onAutoplayFailed(wrappedResume);
          });
        }
        
        // 调用SDK方法
        List<dynamic> args = [indicationInterval];
        if (wrappedCallback != null) {
          args.add(wrappedCallback);
        }
        
        await WebUtils.callJsAsync(engine, 'startAudioDeviceRecordTest', args);
        
        debugPrint('音频设备录制测试启动成功');
        return AudioResult.success();
      } catch (e) {
        String errorMsg = e.toString();
        String errorCode = AudioErrorCode.UNKNOWN_ERROR;
        
        if (errorMsg.contains('NOT_SUPPORTED')) {
          errorCode = 'NOT_SUPPORTED';
          errorMsg = '浏览器不支持设置音频播放设备或测试音频采集/播放设备';
        } else if (errorMsg.contains('REPEAT_DEVICE_TEST')) {
          errorCode = 'REPEAT_DEVICE_TEST';
          errorMsg = '重复开启检测';
        } else if (errorMsg.contains('AUDIO_DEVICE_RECORD_FAILED')) {
          errorCode = 'AUDIO_DEVICE_RECORD_FAILED';
          errorMsg = '开启音频设备测试失败，请重试';
        }
        
        debugPrint('开始音频设备录制测试失败: [$errorCode] $errorMsg');
        return AudioResult.failure(errorMsg, errorCode);
      }
    } catch (e) {
      debugPrint('开始音频设备录制测试过程发生未知错误: $e');
      return AudioResult.failure(e.toString());
    }
  }
  
  /// 停止采集本地音频，并开始播放采集到的声音
  /// 
  /// 在startAudioDeviceRecordTest调用后30秒内调用，可以提前结束录制并开始播放
  /// 
  /// @return 测试结果 AudioResult
  Future<AudioResult> stopAudioDeviceRecordAndPlayTest() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return AudioResult.failure('引擎未设置', AudioErrorCode.ENGINE_NOT_INITIALIZED);
      }
      
      debugPrint('停止录制并开始播放测试音频');
      
      try {
        // 调用SDK方法
        WebUtils.callJs(engine, 'stopAudioDeviceRecordAndPlayTest', []);
        
        debugPrint('停止录制并开始播放测试音频成功');
        return AudioResult.success();
      } catch (e) {
        debugPrint('停止录制并播放测试失败: $e');
        return AudioResult.failure('停止录制并播放测试失败: $e');
      }
    } catch (e) {
      debugPrint('停止录制并播放测试过程发生未知错误: $e');
      return AudioResult.failure(e.toString());
    }
  }
  
  /// 停止音频设备播放测试
  /// 
  /// @return 测试结果 AudioResult
  Future<AudioResult> stopAudioDevicePlayTest() async {
    try {
      if (engine == null) {
        debugPrint('RtcDeviceManager: 引擎未设置');
        return AudioResult.failure('引擎未设置', AudioErrorCode.ENGINE_NOT_INITIALIZED);
      }
      
      debugPrint('停止音频设备播放测试');
      
      try {
        // 调用SDK方法
        WebUtils.callJs(engine, 'stopAudioDevicePlayTest', []);
        
        debugPrint('音频设备播放测试停止成功');
        return AudioResult.success();
      } catch (e) {
        debugPrint('停止音频设备播放测试失败: $e');
        return AudioResult.failure('停止音频设备播放测试失败: $e');
      }
    } catch (e) {
      debugPrint('停止音频设备播放测试过程发生未知错误: $e');
      return AudioResult.failure(e.toString());
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
  
  /// 音频状态流
  Stream<bool> get audioStatusStream => _audioStatusController.stream;
  
  /// 设备变更流
  Stream<List<Map<String, dynamic>>> get deviceChangeStream => _deviceChangeController.stream;
  
  /// 设置音频采集状态标志
  /// @param isCapturing 是否正在采集音频
  void setCapturingAudioStatus(bool isCapturing) {
    _isCapturingAudio = isCapturing;
    _audioStatusController.add(isCapturing);
    debugPrint('RtcDeviceManager: 音频采集状态已更新为 ${isCapturing ? "采集中" : "未采集"}');
  }
  
  /// 释放资源
  void dispose() {
    _audioStatusController.close();
    _deviceChangeController.close();
    debugPrint('RtcDeviceManager: 资源已释放');
  }
}
