import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

/// Web utilities for handling JavaScript interop and resource loading
class WebUtils {
  /// Whether scripts are being loaded
  static bool _areScriptsLoading = false;

  /// Script loading completion
  static Completer<bool>? _loadingCompleter;

  /// SDKs to load
  static final List<String> _sdks = [
    'https://lf-unpkg.volccdn.com/obj/vcloudfe/sdk/@volcengine/rtc/4.66.1/1741254642340/volengine_Web_4.66.1.js',
  ];
 

  /// Wait for SDK to load
  static Future<void> waitForSdkLoaded() async {
    final completer = Completer<void>();

    try {
      // Check if RTC objects already exist
      if (!js.context.hasProperty('VERTC')) {
        debugPrint('VERTC SDK not loaded, loading scripts...');

        // Add event listener for script load
        await _loadVERTCScripts(completer);
      } else {
        debugPrint('VERTC SDK already loaded');
        completer.complete();
      }
    } catch (e) {
      debugPrint('Error while loading SDK: $e');
      completer.completeError(e);
    }

    return completer.future;
  }

  /// Load VERTC scripts
  static Future<void> _loadVERTCScripts(Completer<void> completer) async {
    try {
      // First load the SDK
      for (final sdk in _sdks) {
        await _loadScript(sdk);
      }

      // Wait a moment to ensure SDK is initialized
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify SDK objects exist
      if (!js.context.hasProperty('VERTC') ) {
        throw Exception(
            'Volcano Engine RTC SDK not loaded properly - VERTC object not found');
      }
      debugPrint('Volcano Engine RTC SDK loaded successfully');
 
      // Wait a moment for the interop scripts to initialize
      await Future.delayed(const Duration(milliseconds: 200));

      completer.complete();
    } catch (e) {
      debugPrint('Failed to load VERTC scripts: $e');
      completer.completeError(e);
    }
  }

  /// Safely call a JavaScript method, handling null objects and exceptions
  static dynamic safeJsCall(dynamic jsObject, String method,
      [List<dynamic>? args]) {
    if (jsObject == null) {
      debugPrint('Cannot call $method: JavaScript object is null');
      return null;
    }

    try {
      // 检查是否存在该方法（仅对js.JsObject类型有效）
      if (jsObject is js.JsObject && !jsObject.hasProperty(method)) {
        debugPrint('Warning: JavaScript object does not have method: $method');
        return null;
      }

      // 调用方法
      if (args != null) {
        // 确保所有函数参数都用allowInterop包装
        final wrappedArgs = args.map((arg) {
          if (arg is Function) {
            return js_util.allowInterop(arg);
          }
          return arg;
        }).toList();
        
        return jsObject is js.JsObject 
            ? jsObject.callMethod(method, wrappedArgs)
            : js_util.callMethod(jsObject, method, wrappedArgs);
      } else {
        return jsObject is js.JsObject 
            ? jsObject.callMethod(method)
            : js_util.callMethod(jsObject, method, []);
      }
    } catch (e) {
      debugPrint('Error calling $method: $e');
      // 如果发生错误，尝试记录更多诊断信息
      if (jsObject is js.JsObject) {
        try {
          final properties =
              js.context['Object'].callMethod('keys', [jsObject]);
          debugPrint('Available properties/methods: $properties');
        } catch (e2) {
          debugPrint('Could not enumerate properties: $e2');
        }
      }
      return null;
    }
  }

  /// Call a JavaScript method that returns a Promise
  static dynamic callMethod(dynamic jsObject, String method,
      [List<dynamic>? args]) {
    if (jsObject == null) {
      throw Exception('JavaScript object is null, cannot call $method');
    }

    try {
      // 检查是否存在该方法（仅对js.JsObject类型有效）
      if (jsObject is js.JsObject && !jsObject.hasProperty(method)) {
        throw Exception('JavaScript object does not have method: $method');
      }

      if (args != null) {
        return js_util.callMethod(jsObject, method, args);
      } else {
        return js_util.callMethod(jsObject, method, []);
      }
    } catch (e) {
      debugPrint('Error calling $method: $e');
      // 如果发生错误，尝试记录更多诊断信息
      if (jsObject is js.JsObject) {
        try {
          final properties =
              js.context['Object'].callMethod('keys', [jsObject]);
          debugPrint('Available properties/methods: $properties');
        } catch (e2) {
          debugPrint('Could not enumerate properties: $e2');
        }
      }
      throw Exception('Failed to call $method: $e');
    }
  }

  /// Convert a JavaScript Promise to a Dart Future
  static Future<T> promiseToFuture<T>(dynamic jsPromise) {
    if (jsPromise == null) {
      throw Exception('Promise is null');
    }

    try {
      return js_util.promiseToFuture<T>(jsPromise);
    } catch (e) {
      debugPrint('Error converting Promise to Future: $e');
      throw e;
    }
  }

  /// Check if a JavaScript object exists
  static bool jsObjectExists(String objectName) {
    try {
      return js.context.hasProperty(objectName);
    } catch (e) {
      debugPrint('Error checking if object exists: $e');
      return false;
    }
  }

  /// Check if scripts are already loaded
  static bool _areScriptsAlreadyLoaded() {
    // Check if RTC object already exists (must check both old and new SDK object names)
    if (js.context.hasProperty('VERTC') ) {
      debugPrint('Volcano Engine RTC SDK already loaded');
      return true;
    }

    // Check if script tags already exist
    final scripts = html.document.querySelectorAll('script');
    bool sdksLoaded = true; 

    // Check if SDKs are loaded
    for (final sdk in _sdks) {
      bool found = false;
      for (final script in scripts) {
        final src = script.getAttribute('src') ?? '';
        if (src.contains(_getScriptBaseName(sdk))) {
          found = true;
          break;
        }
      }
      if (!found) {
        sdksLoaded = false;
        break;
      }
    }
 
    return sdksLoaded  ;
  }

  /// Check if SDK is loaded
  static bool isSdkLoaded() {
    if (js.context.hasProperty('VERTC')) {
      return true;
    }
    return false;
  }

  /// Check if VERTC objects are loaded
  static bool isVertcLoaded() {
    return js.context.hasProperty('VERTC');
  }

  /// Get the base name of a script path
  static String _getScriptBaseName(String path) {
    final parts = path.split('/');
    return parts.last;
  }

  /// Load a script and return a future that completes when the script is loaded
  static Future<void> _loadScript(String url) async {
    // Check if already loaded
    final scripts = html.document.querySelectorAll('script');
    for (final script in scripts) {
      final src = script.getAttribute('src') ?? '';
      if (src.contains(_getScriptBaseName(url))) {
        debugPrint('Script already loaded: $url');
        return;
      }
    }

    debugPrint('Loading script: $url');
    final completer = Completer<void>();

    final scriptElement = html.ScriptElement();
    scriptElement.type = 'text/javascript';
    scriptElement.src = url;

    scriptElement.onLoad.listen((_) {
      debugPrint('Script loaded: $url');
      completer.complete();
    });

    scriptElement.onError.listen((event) {
      debugPrint('Failed to load script: $url');
      completer.completeError('Failed to load script: $url');
    });

    html.document.head!.append(scriptElement);
    return completer.future;
  }

  /// Debug print wrapper for logging
  static void debugPrint(String message) {
    if (kDebugMode) {
      print('[WebUtils] $message');
    }
  }

  /// 异步调用JavaScript方法并等待Promise结果
  static Future<dynamic> callJsMethodAsync(dynamic jsObject, String method,
      [List<dynamic>? args]) async {
    if (jsObject == null) {
      throw Exception('JavaScript object is null, cannot call $method');
    }

    try {
      dynamic result;
      if (args != null) {
        // 确保所有函数参数都用allowInterop包装
        final wrappedArgs = args.map((arg) {
          if (arg is Function) {
            return js_util.allowInterop(arg);
          }
          return arg;
        }).toList();
        
        result = js_util.callMethod(jsObject, method, wrappedArgs);
      } else {
        result = js_util.callMethod(jsObject, method, []);
      }

      // 如果结果是Promise，等待它完成
      if (js_util.hasProperty(result, 'then')) {
        return await js_util.promiseToFuture(result);
      }

      return result;
    } catch (e) {
      debugPrint('Error calling $method async: $e');
      throw Exception('Failed to call $method async: $e');
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

  /// Call a JavaScript method directly
  static dynamic callJsMethod(dynamic jsObject, String method,
      [List<dynamic>? args]) {
    if (jsObject == null) {
      throw Exception('JavaScript object is null, cannot call $method');
    }

    try {
      if (args != null) {
        // 确保所有函数参数都用allowInterop包装
        final wrappedArgs = args.map((arg) {
          if (arg is Function) {
            return js_util.allowInterop(arg);
          }
          return arg;
        }).toList();
        
        return js_util.callMethod(jsObject, method, wrappedArgs);
      } else {
        return js_util.callMethod(jsObject, method, []);
      }
    } catch (e) {
      debugPrint('Error calling method $method: $e');
      throw Exception('Failed to call method $method: $e');
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

  /// Call a JavaScript method that returns a Promise, and convert the promise to a Dart Future
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
        result = js_util.callMethod(methodFunc, 'apply', [jsObject, js_util.jsify(wrappedArgs)]);
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

  /// Convert a binary message to a string
  static String binaryToString(dynamic binaryData) {
    try {
      // First check if it's already a string
      if (binaryData is String) {
        return binaryData;
      }

      // Check if it's a Uint8Array
      if (js_util.hasProperty(binaryData, 'byteLength')) {
        // Convert to a JavaScript string using TextDecoder
        final textDecoder = js_util.callConstructor(
            js_util.getProperty(js_util.globalThis, 'TextDecoder'), ['utf-8']);

        return js_util.callMethod(textDecoder, 'decode', [binaryData]);
      }

      // Try direct toString conversion as fallback
      return binaryData.toString();
    } catch (e) {
      debugPrint('Error converting binary to string: $e');
      return '';
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

  /// Get audio input devices - Direct implementation based on RtcClient.ts
  static Future<List<dynamic>> getAudioInputDevices() async {
    try {
      debugPrint('Getting audio input devices');
      // Make sure SDK is loaded
      if (!isSdkLoaded()) {
        await waitForSdkLoaded();
      }

      // Get VERTC object directly from global scope
      final vertcObj = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (vertcObj == null) {
        throw Exception('VERTC object not found in global scope');
      }

      // Call enumerateAudioCaptureDevices directly (similar to the TS implementation)
      debugPrint('Calling VERTC.enumerateAudioCaptureDevices()');
      final devicesPromise = js_util.callMethod(vertcObj, 'enumerateAudioCaptureDevices', []);
      
      // Convert to Future and return
      final devices = await js_util.promiseToFuture(devicesPromise);
      debugPrint('Got ${js_util.getProperty(devices, 'length')} audio input devices');
      return devices;
    } catch (e) {
      debugPrint('Error getting audio input devices: $e');
      return [];
    }
  }
  
  /// Get audio output devices - Direct implementation based on RtcClient.ts
  static Future<List<dynamic>> getAudioOutputDevices() async {
    try {
      debugPrint('Getting audio output devices');
      // Make sure SDK is loaded
      if (!isSdkLoaded()) {
        await waitForSdkLoaded();
      }

      // Get VERTC object directly from global scope
      final vertcObj = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (vertcObj == null) {
        throw Exception('VERTC object not found in global scope');
      }

      // Call enumerateAudioPlaybackDevices directly (similar to the TS implementation)
      debugPrint('Calling VERTC.enumerateAudioPlaybackDevices()');
      final devicesPromise = js_util.callMethod(vertcObj, 'enumerateAudioPlaybackDevices', []);
      
      // Convert to Future and return
      final devices = await js_util.promiseToFuture(devicesPromise);
      debugPrint('Got ${js_util.getProperty(devices, 'length')} audio output devices');
      return devices;
    } catch (e) {
      debugPrint('Error getting audio output devices: $e');
      return [];
    }
  }
}
