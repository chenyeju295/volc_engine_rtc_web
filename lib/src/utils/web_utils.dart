import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:js_interop';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Web utilities for handling JavaScript interop and resource loading
class WebUtils {
  static const String sdkAssetPath = 'sdk/volengine_Web_4.66.1.js';
  
  // SDK加载状态追踪
  static bool _isLoadingSDK = false;
  static Completer<void>? _sdkLoadCompleter;

  /// 等待SDK加载完成
  static Future<void> waitForSdkLoaded() async {
    // 如果SDK已经加载，直接返回
    if (js.context.hasProperty('VERTC')) {
      return;
    }
    
    // 如果正在加载，等待现有加载过程完成
    if (_isLoadingSDK && _sdkLoadCompleter != null) {
      return _sdkLoadCompleter!.future;
    }
    
    // 开始新的加载过程
    _isLoadingSDK = true;
    _sdkLoadCompleter = Completer<void>();
    
    try {
      // 尝试加载SDK
      await _loadVERTCScripts();
      _sdkLoadCompleter!.complete();
    } catch (e) {
      debugPrint('SDK加载失败: $e');
      _sdkLoadCompleter!.completeError(e);
    } finally {
      _isLoadingSDK = false;
    }
    
    return _sdkLoadCompleter!.future;
  }

  /// 加载VERTC脚本
  static Future<void> _loadVERTCScripts() async {
    debugPrint('开始加载RTC SDK...');
    
    // 方法1: 通过script标签加载
    try {
      final sdkUrl = await _getAssetUrl(sdkAssetPath);
      if (sdkUrl == null) {
        throw Exception('无法解析资源URL: $sdkAssetPath');
      }
      
      debugPrint('通过script标签加载SDK: $sdkUrl');
      await _loadScriptByTag(sdkUrl);
      
      // 验证加载结果
      await Future.delayed(const Duration(milliseconds: 300));
      if (js.context.hasProperty('VERTC')) {
        debugPrint('SDK加载成功 (方法1)');
        return;
      }
    } catch (e) {
      debugPrint('方法1加载失败: $e');
      // 继续尝试下一种方法
    }
    
    // 方法2: 预加载内容然后注入
    try {
      final sdkUrl = await _getAssetUrl(sdkAssetPath);
      if (sdkUrl != null) {
        debugPrint('预加载SDK内容后注入: $sdkUrl');
        final content = await _fetchScriptContent(sdkUrl);
        await _injectScriptContent(content);
        
        // 验证加载结果
        await Future.delayed(const Duration(milliseconds: 300));
        if (js.context.hasProperty('VERTC')) {
          debugPrint('SDK加载成功 (方法2)');
          return;
        }
      }
    } catch (e) {
      debugPrint('方法2加载失败: $e');
      // 继续尝试下一种方法
    }
    
    // 方法3: 直接从assets加载
    try {
      debugPrint('从assets直接加载SDK内容');
      await _loadScriptFromAssets(sdkAssetPath);
      
      // 验证加载结果
      await Future.delayed(const Duration(milliseconds: 300));
      if (js.context.hasProperty('VERTC')) {
        debugPrint('SDK加载成功 (方法3)');
        return;
      }
    } catch (e) {
      debugPrint('方法3加载失败: $e');
    }
    
    // 所有方法都失败
    throw Exception('所有SDK加载方法都失败');
  }
  
  /// 通过script标签加载脚本
  static Future<void> _loadScriptByTag(String url) {
    final completer = Completer<void>();
    
    final script = html.ScriptElement();
    script.type = 'application/javascript';
    script.src = url;
    
    script.onLoad.listen((_) {
      completer.complete();
    });
    
    script.onError.listen((event) {
      completer.completeError('脚本加载失败: $url');
    });
    
    html.document.head!.append(script);
    return completer.future;
  }

  /// Fetch script content via XMLHttpRequest to handle MIME type issues
  static Future<String> _fetchScriptContent(String url) async {
    final completer = Completer<String>();

    try {
      debugPrint('Fetching script content from: $url');

      // Create an XMLHttpRequest
      final request = html.HttpRequest();
      request.open('GET', url);

      // Set responseType to text
      request.responseType = 'text';

      // Set up event listeners
      request.onLoad.listen((_) {
        if (request.status == 200) {
          final content = request.responseText;
          if (content != null && content.isNotEmpty) {
            debugPrint(
                'Successfully fetched script content (${content.length} bytes)');
            completer.complete(content);
          } else {
            completer.completeError('Empty content received');
          }
        } else {
          completer.completeError(
              'Failed to fetch script: ${request.status} ${request.statusText}');
        }
      });

      request.onError.listen((_) {
        completer.completeError('Error fetching script: ${request.statusText}');
      });

      // Send the request
      request.send();
    } catch (e) {
      debugPrint('Error in fetch script content: $e');
      completer.completeError('Error fetching script: $e');
    }

    return completer.future;
  }

  /// Get the correct URL for an asset in web
  static Future<String?> _getAssetUrl(String assetPath) async {
    try {
      // In web, assets are served from a different location based on build mode

      // Try both formats commonly used in Flutter web
      final String packagePath = 'packages/rtc_aigc_plugin/$assetPath';

      // In debug mode
      if (kDebugMode) {
        return 'assets/$packagePath';
      } else {
        // In release mode - try to find the asset in manifest
        try {
          final String manifestContent =
              await rootBundle.loadString('AssetManifest.json');
          final Map<String, dynamic> manifest = json.decode(manifestContent);

          // Try finding the asset with different path patterns
          for (final key in manifest.keys) {
            if (key.endsWith(assetPath) || key.endsWith(packagePath)) {
              debugPrint('Found asset in manifest: $key');
              return key;
            }
          }
        } catch (e) {
          debugPrint('Error loading asset manifest: $e');
        }

        // Fallback - use standard paths
        return 'assets/$packagePath';
      }
    } catch (e) {
      debugPrint('Error resolving asset URL: $e');
      // Try a direct path as last resort
      return assetPath;
    }
  }

  /// Load a script from Flutter assets
  static Future<void> _loadScriptFromAssets(String assetPath) async {
    debugPrint('Loading script content from assets: $assetPath');

    try {
      // Try different asset paths
      final List<String> potentialPaths = [
        assetPath,
        'packages/rtc_aigc_plugin/$assetPath',
        'assets/packages/rtc_aigc_plugin/$assetPath',
        'assets/$assetPath',
      ];

      // Try each path in sequence until one works
      Exception? lastError;
      for (final path in potentialPaths) {
        try {
          debugPrint('Trying to load from: $path');
          final String jsContent = await rootBundle.loadString(path);
          if (jsContent.isNotEmpty) {
            debugPrint(
                'Successfully loaded script content from: $path (${jsContent.length} bytes)');
            await _injectScriptContent(jsContent);
            return;
          }
        } catch (e) {
          lastError = Exception('Failed to load from $path: $e');
          debugPrint('Error loading from $path: $e');
          // Continue to next path
        }
      }

      // If we get here, all paths failed
      throw lastError ?? Exception('Failed to load asset from any path');
    } catch (e) {
      debugPrint('Error loading script from assets: $e');
      throw Exception('Failed to load script from assets: $e');
    }
  }

  /// Inject JS content into a script tag
  static Future<void> _injectScriptContent(String jsContent) async {
    final completer = Completer<void>();

    // Create script element
    final scriptElement = html.ScriptElement();
    scriptElement.type = 'application/javascript';
    scriptElement.text = jsContent;

    // Add event listeners
    scriptElement.onLoad.listen((_) {
      debugPrint('Script content executed successfully');
      completer.complete();
    });

    scriptElement.onError.listen((event) {
      debugPrint('Failed to execute script content');
      completer.completeError('Failed to execute script content');
    });

    // Append to document
    html.document.head!.append(scriptElement);

    return completer.future;
  }

  /// 通用的JavaScript方法调用函数
  /// 处理函数参数包装，并支持直接调用或通过字符串路径调用
  static dynamic callJs(dynamic target, String method, [List<dynamic>? args]) {
    try {
      if (target == null) {
        throw Exception('JavaScript对象为空，无法调用方法：$method');
      }
      
      // 支持通过字符串路径访问目标对象
      if (target is String) {
        final parts = target.split('.');
        dynamic obj = js.context;
        
        for (int i = 0; i < parts.length; i++) {
          if (obj.hasProperty(parts[i])) {
            obj = obj[parts[i]];
          } else {
            throw Exception('找不到对象路径: ${parts.sublist(0, i + 1).join('.')}');
          }
        }
        
        if (method.isEmpty) {
          return obj; // 如果只需要获取对象属性
        }
        target = obj;
      }
      
      // 包装函数参数
      List<dynamic> wrappedArgs = [];
      if (args != null) {
        wrappedArgs = args.map((arg) {
          if (arg is Function) {
            return js_util.allowInterop(arg);
          }
          return arg;
        }).toList();
      }
      
      // 调用方法
      return js_util.callMethod(target, method, wrappedArgs);
    } catch (e) {
      debugPrint('调用方法失败: $method - $e');
      throw Exception('调用JavaScript方法失败：$method - $e');
    }
  }
  
  /// 异步调用JavaScript方法
  /// 自动处理Promise结果转换
  static Future<dynamic> callJsAsync(dynamic target, String method, [List<dynamic>? args]) async {
    try {
      dynamic result = callJs(target, method, args);
      
      // 如果结果是Promise，转换为Future
      if (result != null && js_util.hasProperty(result, 'then')) {
        return await js_util.promiseToFuture(result);
      }
      
      return result;
    } catch (e) {
      debugPrint('异步调用方法失败: $method - $e');
      throw Exception('异步调用JavaScript方法失败：$method - $e');
    }
  }
  
  /// 获取JavaScript对象属性
  static dynamic getProperty(dynamic target, String propertyPath) {
    try {
      if (target is String) {
        // 拼接完整路径
        propertyPath = '$target.$propertyPath';
        target = js.context;
      }
      
      final parts = propertyPath.split('.');
      dynamic obj = target;
      
      for (int i = 0; i < parts.length; i++) {
        if (obj == null) return null;
        
        if (obj is js.JsObject && obj.hasProperty(parts[i])) {
          obj = obj[parts[i]];
        } else if (js_util.hasProperty(obj, parts[i])) {
          obj = js_util.getProperty(obj, parts[i]);
        } else {
          return null;
        }
      }
      
      return obj;
    } catch (e) {
      debugPrint('获取属性失败: $propertyPath - $e');
      return null;
    }
  }

  /// Check if SDK is loaded and initialized
  static bool isSdkLoaded() {
    try {
      // Check if SDK global object exists
      if (js.context.hasProperty('VERTC')) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking if SDK is loaded: $e');
      return false;
    }
  }

  /// Check if VERTC objects are loaded and accessible
  static bool isVertcLoaded() {
    try {
      if (js.context.hasProperty('VERTC')) {
        // Try accessing a property to verify it's properly initialized
        try {
          final version = js.context['VERTC']['version'];
          debugPrint('VERTC SDK loaded, version: $version');
          return true;
        } catch (propError) {
          debugPrint(
              'VERTC object exists but may not be fully initialized: $propError');
          return js.context
              .hasProperty('VERTC'); // Return true if the object exists at all
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking VERTC loaded status: $e');
      return false;
    }
  }

  /// Debug print wrapper for logging
  static void debugPrint(String message) {
    if (kDebugMode) {
      print('[WebUtils] $message');
    }
  }

  /// 异步调用全局JavaScript方法并等待Promise结果
  static Future<dynamic> callGlobalMethodAsync(String methodPath,
      [List<dynamic>? args]) async {
    try {
      // 解析方法路径，例如 'navigator.mediaDevices.getUserMedia'
      final parts = methodPath.split('.');

      // 获取根对象
      dynamic obj = js.context;
      for (int i = 0; i < parts.length - 1; i++) {
        if (obj.hasProperty(parts[i])) {
          obj = obj[parts[i]];
        } else {
          throw Exception(
              'Object path not found: ${parts.sublist(0, i + 1).join('.')}');
        }
      }

      // 获取最终方法名
      final methodName = parts.last;

      // 调用方法
      dynamic result;
      if (args != null) {
        // 确保所有函数参数都用allowInterop包装
        final wrappedArgs = args.map((arg) {
          if (arg is Function) {
            return js_util.allowInterop(arg);
          }
          return arg;
        }).toList();

        result = js_util.callMethod(obj, methodName, wrappedArgs);
      } else {
        result = js_util.callMethod(obj, methodName, []);
      }

      // 如果结果是Promise，等待它完成
      if (result != null && js_util.hasProperty(result, 'then')) {
        return await js_util.promiseToFuture(result);
      }

      return result;
    } catch (e) {
      debugPrint('Error calling global method $methodPath async: $e');
      throw Exception('Failed to call global method $methodPath async: $e');
    }
  }

  /// 调用全局JavaScript方法
  static dynamic callGlobalMethod(String methodPath, [List<dynamic>? args]) {
    try {
      // 解析方法路径，例如 'console.log'
      final parts = methodPath.split('.');

      // 获取根对象
      dynamic obj = js.context;
      for (int i = 0; i < parts.length - 1; i++) {
        if (obj.hasProperty(parts[i])) {
          obj = obj[parts[i]];
        } else {
          throw Exception(
              'Object path not found: ${parts.sublist(0, i + 1).join('.')}');
        }
      }

      // 获取最终方法名
      final methodName = parts.last;

      // 调用方法
      if (args != null) {
        // 确保所有函数参数都用allowInterop包装
        final wrappedArgs = args.map((arg) {
          if (arg is Function) {
            return js_util.allowInterop(arg);
          }
          return arg;
        }).toList();

        return js_util.callMethod(obj, methodName, wrappedArgs);
      } else {
        return js_util.callMethod(obj, methodName, []);
      }
    } catch (e) {
      debugPrint('Error calling global method $methodPath: $e');
      throw Exception('Failed to call global method $methodPath: $e');
    }
  }

  /// 获取JavaScript对象属性
  static dynamic getJsProperty(String propertyPath) {
    try {
      // 解析属性路径，例如 'VERTC.events.onUserJoined'
      final parts = propertyPath.split('.');

      // 获取根对象
      dynamic obj = js.context;
      for (int i = 0; i < parts.length; i++) {
        if (obj.hasProperty(parts[i])) {
          obj = obj[parts[i]];
        } else {
          throw Exception(
              'Property path not found: ${parts.sublist(0, i + 1).join('.')}');
        }
      }

      return obj;
    } catch (e) {
      debugPrint('Error getting JS property $propertyPath: $e');
      return null;
    }
  }

  /// 检查全局对象是否存在
  static Future<bool> checkObjectExists(String objectName) async {
    try {
      final result = await callGlobalMethodAsync(
          'eval', ['typeof ' + objectName + ' !== "undefined"']);
      return result == true;
    } catch (e) {
      debugPrint('Error checking if object exists: $e');
      return false;
    }
  }

  /// 使用eval创建对象实例的更可靠方法
  static Future<dynamic> createObjectWithEval(
      String className, Map<String, dynamic> params) async {
    try {
      if (!await checkObjectExists(className)) {
        throw Exception('Class $className does not exist in global scope');
      }

      final jsParams = js_util.jsify(params);
      final paramsString = stringify(jsParams);
      final evalString = 'new ' + className + '(' + paramsString + ')';

      debugPrint('Creating object with eval: $evalString');
      return await callGlobalMethodAsync('eval', [evalString]);
    } catch (e) {
      debugPrint('Error creating object with eval: $e');
      throw Exception('Failed to create $className: $e');
    }
  }

  /// 异步调用全局JavaScript变量
  static Future<dynamic> callGlobalMethodVarAsync(String varName) async {
    try {
      return await callGlobalMethodAsync('eval', [varName]);
    } catch (e) {
      debugPrint('Error getting global var $varName: $e');
      return null;
    }
  }

  static Future<dynamic> callMethodAsync(dynamic jsObject, String method,
      [List<dynamic>? args]) async {
    if (jsObject == null) {
      debugPrint('Cannot call async $method: JavaScript object is null');
      return null;
    }

    try {
      // Try to get a direct reference to the method
      final methodFunc = js_util.getProperty(jsObject, method);
      if (methodFunc == null) {
        debugPrint('Method $method not found on JavaScript object');
        return null;
      }

      dynamic result;
      if (args != null) {
        // Ensure all function arguments are wrapped with allowInterop if they are functions
        final wrappedArgs = args.map((arg) {
          if (arg is Function) {
            return js_util.allowInterop(arg);
          }
          return arg;
        }).toList();

        // Use callMethod with apply to ensure proper method binding
        result = js_util.callMethod(
            methodFunc, 'apply', [jsObject, js_util.jsify(wrappedArgs)]);
      } else {
        // Call method with empty args array
        result = js_util.callMethod(methodFunc, 'apply', [jsObject, []]);
      }

      if (result != null && js_util.hasProperty(result, 'then')) {
        // It's a Promise, convert to Future
        return await js_util.promiseToFuture(result);
      }

      // Not a Promise, return as is
      return result;
    } catch (e) {
      debugPrint('Error calling async $method: $e');

      // Fallback approach using direct method call
      try {
        debugPrint('Trying fallback approach for $method');

        // Check if any args are functions and wrap them with allowInterop
        List<dynamic>? wrappedArgs;
        if (args != null) {
          wrappedArgs = args.map((arg) {
            if (arg is Function) {
              return js_util.allowInterop(arg);
            }
            return arg;
          }).toList();
        }

        final result = wrappedArgs != null
            ? js_util.callMethod(jsObject, method, wrappedArgs)
            : js_util.callMethod(jsObject, method, []);

        if (result != null && js_util.hasProperty(result, 'then')) {
          // It's a Promise, convert to Future
          return await js_util.promiseToFuture(result);
        }

        // Not a Promise, return as is
        return result;
      } catch (fallbackError) {
        debugPrint('Fallback approach also failed: $fallbackError');
        return null;
      }
    }
  }

  /// 将二进制数据转换为Uint8List
  /// 简化版本，专注于常见场景并减少日志输出
  static Uint8List binaryToUint8List(dynamic binaryData) {
    try {
      // 已经是Uint8List，直接返回
      if (binaryData is Uint8List) {
        return binaryData;
      }
      
      // 处理List<int>
      if (binaryData is List<int>) {
        return Uint8List.fromList(binaryData);
      }

      // 处理ArrayBuffer或TypedArray
      if (binaryData != null && js_util.hasProperty(binaryData, 'byteLength')) {
        // 创建Uint8Array视图
        final uint8Array = js_util.hasProperty(binaryData, 'BYTES_PER_ELEMENT') 
            ? binaryData  // 已经是TypedArray
            : js_util.callConstructor(
                js_util.getProperty(js_util.globalThis, 'Uint8Array'), [binaryData]);
        
        // 获取数组长度
        final int length = js_util.getProperty(uint8Array, 'length');
        
        // 创建Uint8List并复制数据
        final Uint8List result = Uint8List(length);
        for (int i = 0; i < length; i++) {
          result[i] = js_util.getProperty(uint8Array, i);
        }
        
        return result;
      }

      // 处理失败，返回空数组
      return Uint8List(0);
    } catch (e) {
      debugPrint('二进制数据转换失败: $e');
      return Uint8List(0);
    }
  }

  /// 将二进制消息转换为字符串
  /// 简化版本，使用最常见的编码方式和最小日志输出
  static String binaryToString(dynamic binaryData) {
    try {
      // 已经是字符串直接返回
      if (binaryData is String) {
        return binaryData;
      }

      // 转换为Uint8List
      final Uint8List bytes = binaryToUint8List(binaryData);
      if (bytes.isEmpty) {
        return '';
      }
      
      // 检查常见的TLV格式标记
      if (bytes.length >= 8) {
        final String magic = String.fromCharCodes(bytes.sublist(0, 4));
        if (magic == 'conv' || magic == 'subv' || magic == 'func') {
          // 解析TLV格式消息
          final int contentLength = (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
          
          if (contentLength > 0 && bytes.length >= (8 + contentLength)) {
            try {
              // 提取内容部分并解码
              return utf8.decode(bytes.sublist(8, 8 + contentLength));
            } catch (_) {
              // 解码失败，继续使用常规方法
            }
          }
        }
      }
      
      // 尝试用UTF-8解码（最常见的情况）
      try {
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        // UTF-8解码失败时使用Latin1作为备选
        return latin1.decode(bytes);
      }
    } catch (e) {
      return ''; // 错误情况下返回空字符串
    }
  }

  /// Stringify a JavaScript object (similar to JSON.stringify)
  static String stringify(dynamic jsObject) {
    try {
      if (jsObject == null) {
        return '';
      }

      final JSON = js_util.getProperty(js_util.globalThis, 'JSON');
      if (JSON == null) {
        throw Exception('JSON object not found in global scope');
      }

      return js_util.callMethod(JSON, 'stringify', [jsObject]).toString();
    } catch (e) {
      debugPrint('Error stringifying object: $e');
      return jsObject.toString();
    }
  }

  // 设备缓存
  static List<dynamic>? _cachedAudioInputDevices;
  static List<dynamic>? _cachedAudioOutputDevices;
  static DateTime? _lastAudioInputDeviceRefresh;
  static DateTime? _lastAudioOutputDeviceRefresh;
  
  // 缓存有效期（毫秒）
  static const int _deviceCacheValidityMs = 2000; // 2秒

  /// 获取音频输入设备列表（带缓存）
  static Future<List<dynamic>> getAudioInputDevices() async {
    // 检查缓存是否有效
    final now = DateTime.now();
    if (_cachedAudioInputDevices != null && 
        _lastAudioInputDeviceRefresh != null && 
        now.difference(_lastAudioInputDeviceRefresh!).inMilliseconds < _deviceCacheValidityMs) {
      // 使用缓存，不打印日志，减少重复信息
      return _cachedAudioInputDevices!;
    }

    try {
      // 确保SDK已加载
      if (!isSdkLoaded()) {
        await waitForSdkLoaded();
      }

      // 从全局作用域获取VERTC对象
      final vertcObj = getProperty(js_util.globalThis, 'VERTC');
      if (vertcObj == null) {
        throw Exception('VERTC对象未在全局作用域中找到');
      }

      // 调用SDK方法获取设备列表
      final devices = await callJsAsync(vertcObj, 'enumerateAudioCaptureDevices');
      
      if (devices != null) {
        final length = getProperty(devices, 'length') ?? 0;
        
        // 只有首次或设备数量变化时才打印日志
        if (_cachedAudioInputDevices == null || 
            _cachedAudioInputDevices!.length != length) {
          debugPrint('获取到 $length 个音频输入设备');
        }
        
        // 更新缓存
        _cachedAudioInputDevices = devices;
        _lastAudioInputDeviceRefresh = now;
      }
      
      return devices ?? [];
    } catch (e) {
      debugPrint('获取音频输入设备列表失败: $e');
      return _cachedAudioInputDevices ?? [];
    }
  }

  /// 获取音频输出设备列表（带缓存）
  static Future<List<dynamic>> getAudioOutputDevices() async {
    // 检查缓存是否有效
    final now = DateTime.now();
    if (_cachedAudioOutputDevices != null && 
        _lastAudioOutputDeviceRefresh != null && 
        now.difference(_lastAudioOutputDeviceRefresh!).inMilliseconds < _deviceCacheValidityMs) {
      // 使用缓存，不打印日志
      return _cachedAudioOutputDevices!;
    }

    try {
      // 确保SDK已加载
      if (!isSdkLoaded()) {
        await waitForSdkLoaded();
      }

      // 从全局作用域获取VERTC对象
      final vertcObj = getProperty(js_util.globalThis, 'VERTC');
      if (vertcObj == null) {
        throw Exception('VERTC对象未在全局作用域中找到');
      }

      // 调用SDK方法获取设备列表
      final devices = await callJsAsync(vertcObj, 'enumerateAudioPlaybackDevices');
      
      if (devices != null) {
        final length = getProperty(devices, 'length') ?? 0;
        
        // 只有首次或设备数量变化时才打印日志
        if (_cachedAudioOutputDevices == null || 
            _cachedAudioOutputDevices!.length != length) {
          debugPrint('获取到 $length 个音频输出设备');
        }
        
        // 更新缓存
        _cachedAudioOutputDevices = devices;
        _lastAudioOutputDeviceRefresh = now;
      }
      
      return devices ?? [];
    } catch (e) {
      debugPrint('获取音频输出设备列表失败: $e');
      return _cachedAudioOutputDevices ?? [];
    }
  }
  
  /// 强制刷新设备列表缓存
  static Future<void> refreshDeviceCaches() async {
    _cachedAudioInputDevices = null;
    _cachedAudioOutputDevices = null;
    _lastAudioInputDeviceRefresh = null;
    _lastAudioOutputDeviceRefresh = null;
    
    // 重新获取并缓存设备列表
    await getAudioInputDevices();
    await getAudioOutputDevices();
    
    debugPrint('设备列表缓存已刷新');
  }
}
