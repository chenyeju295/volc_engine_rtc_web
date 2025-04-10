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

  /// Wait for SDK to load
  static Future<void> waitForSdkLoaded() async {
    final completer = Completer<void>();

    try {
      // Check if RTC objects already exist
      if (!js.context.hasProperty('VERTC')) {
        // Add event listener for script load
        await _loadVERTCScripts(completer);
      } else {
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
      // Try loading the SDK from assets first
      try {
        debugPrint('Loading SDK from Flutter assets: $sdkAssetPath');

        // Get the correct asset URL for web
        final sdkUrl = await _getAssetUrl(sdkAssetPath);
        debugPrint('Resolved SDK URL: $sdkUrl');

        if (sdkUrl == null) {
          throw Exception('Could not resolve asset URL for $sdkAssetPath');
        }

        // Try to pre-fetch the script content to avoid MIME type issues
        try {
          debugPrint('Pre-fetching script content to avoid MIME type issues');
          final scriptContent = await _fetchScriptContent(sdkUrl);
          await _injectScriptContent(scriptContent);

          // Verify if RTC objects were loaded - allow a moment for scripts to initialize
          await Future.delayed(const Duration(milliseconds: 500));

          if (!js.context.hasProperty('VERTC')) {
            throw Exception('SDK not loaded properly after pre-fetch attempt');
          }

          debugPrint('SDK loaded successfully via pre-fetch method');
          completer.complete();
          return;
        } catch (preFetchError) {
          debugPrint(
              'Pre-fetch method failed, trying direct script tag: $preFetchError');

          // Fallback to traditional script tag loading
          final scriptElement = html.ScriptElement();
          scriptElement.type = 'application/javascript';
          scriptElement.src = sdkUrl;

          // Create a completion mechanism
          final scriptCompleter = Completer<void>();

          scriptElement.onLoad.listen((_) {
            debugPrint('Script loaded successfully: $sdkUrl');
            scriptCompleter.complete();
          });

          scriptElement.onError.listen((event) {
            debugPrint('Error loading script: $sdkUrl');
            scriptCompleter.completeError('Failed to load script: $sdkUrl');
          });

          // Add to document
          html.document.head!.append(scriptElement);

          // Wait for script to load
          await scriptCompleter.future;

          // Verify if RTC objects were loaded - allow a moment for scripts to initialize
          await Future.delayed(const Duration(milliseconds: 500));

          // Final verification
          if (!js.context.hasProperty('VERTC')) {
            throw Exception(
                'Volcano Engine RTC SDK not loaded properly - VERTC object not found');
          }

          debugPrint('Volcano Engine RTC SDK loaded successfully');
          completer.complete();
        }
      } catch (e) {
        debugPrint('Error with asset loading approach: $e');

        // Fallback to loading the script inline from assets
        try {
          debugPrint(
              'Trying fallback: load script content directly from assets');
          await _loadScriptFromAssets(sdkAssetPath);

          // Verify if RTC objects were loaded
          if (!js.context.hasProperty('VERTC')) {
            throw Exception('SDK not loaded properly after fallback attempt');
          }

          debugPrint('Volcano Engine RTC SDK loaded successfully via fallback');
          completer.complete();
        } catch (fallbackError) {
          debugPrint('Error with all local loading approaches: $fallbackError');
          completer.completeError(
              'Failed to load SDK from local assets: $fallbackError');
        }
      }
    } catch (e) {
      debugPrint('Failed to load VERTC scripts: $e');
      completer.completeError(e);
    }
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
      final devicesPromise =
          js_util.callMethod(vertcObj, 'enumerateAudioCaptureDevices', []);

      // Convert to Future and return
      final devices = await js_util.promiseToFuture(devicesPromise);
      debugPrint(
          'Got ${js_util.getProperty(devices, 'length')} audio input devices');
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
      final devicesPromise =
          js_util.callMethod(vertcObj, 'enumerateAudioPlaybackDevices', []);

      // Convert to Future and return
      final devices = await js_util.promiseToFuture(devicesPromise);
      debugPrint(
          'Got ${js_util.getProperty(devices, 'length')} audio output devices');
      return devices;
    } catch (e) {
      debugPrint('Error getting audio output devices: $e');
      return [];
    }
  }
}
