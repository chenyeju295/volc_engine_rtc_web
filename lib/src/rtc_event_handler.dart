import 'dart:js';
import 'dart:js_util' as js_util;

/// Interface for RTC event handlers
class RtcEventHandler {
  /// Error event handler
  final Function(dynamic)? onError;
  
  /// User joined event handler
  final Function(Map<String, dynamic>)? onUserJoined;
  
  /// User left event handler
  final Function(Map<String, dynamic>)? onUserLeave;
  
  /// User publish stream event handler
  final Function(String, int)? onUserPublishStream;
  
  /// User unpublish stream event handler
  final Function(String, int, String)? onUserUnpublishStream;
  
  /// Remote stream stats event handler
  final Function(Map<String, dynamic>)? onRemoteStreamStats;
  
  /// Local stream stats event handler
  final Function(Map<String, dynamic>)? onLocalStreamStats;
  
  /// Local audio properties report event handler
  final Function(List<dynamic>)? onLocalAudioPropertiesReport;
  
  /// Remote audio properties report event handler
  final Function(List<dynamic>)? onRemoteAudioPropertiesReport;
  
  /// Audio device state changed event handler
  final Function(Map<String, dynamic>)? onAudioDeviceStateChanged;
  
  /// User message received event handler
  final Function(String, dynamic)? onUserMessageReceived;
  
  /// Auto play failed event handler
  final Function(Map<String, dynamic>)? onAutoPlayFailed;
  
  /// Player event handler
  final Function(Map<String, dynamic>)? onPlayerEvent;
  
  /// User start audio capture event handler
  final Function(String)? onUserStartAudioCapture;
  
  /// User stop audio capture event handler
  final Function(String)? onUserStopAudioCapture;
  
  /// Room binary message received event handler
  final Function(String, dynamic)? onRoomBinaryMessageReceived;
  
  /// Network quality event handler
  final Function(String, String)? onNetworkQuality;
  
  /// Constructor
  RtcEventHandler({
    this.onError,
    this.onUserJoined,
    this.onUserLeave,
    this.onUserPublishStream,
    this.onUserUnpublishStream,
    this.onRemoteStreamStats,
    this.onLocalStreamStats,
    this.onLocalAudioPropertiesReport,
    this.onRemoteAudioPropertiesReport,
    this.onAudioDeviceStateChanged,
    this.onUserMessageReceived,
    this.onAutoPlayFailed,
    this.onPlayerEvent,
    this.onUserStartAudioCapture,
    this.onUserStopAudioCapture,
    this.onRoomBinaryMessageReceived,
    this.onNetworkQuality,
  });
  
  /// Register event handlers with the RTC engine
  void registerWith(JsObject engine, JsObject vertc) {
    if (onError != null) {
      engine.callMethod('on', [
        vertc['events']['onError'],
        js_util.allowInterop((e) => onError!(e))
      ]);
    }
    
    if (onUserJoined != null) {
      engine.callMethod('on', [
        vertc['events']['onUserJoined'],
        js_util.allowInterop((e) => onUserJoined!(Map<String, dynamic>.from(dartify(e) as Map)))
      ]);
    }
    
    if (onUserLeave != null) {
      engine.callMethod('on', [
        vertc['events']['onUserLeave'],
        js_util.allowInterop((e) => onUserLeave!(Map<String, dynamic>.from(dartify(e) as Map)))
      ]);
    }
    
    if (onUserPublishStream != null) {
      engine.callMethod('on', [
        vertc['events']['onUserPublishStream'],
        js_util.allowInterop((e) {
          final Map<String, dynamic> event = dartify(e) as Map<String, dynamic>;
          onUserPublishStream!(event['userId'] as String, event['mediaType'] as int);
        })
      ]);
    }
    
    if (onUserUnpublishStream != null) {
      engine.callMethod('on', [
        vertc['events']['onUserUnpublishStream'],
        js_util.allowInterop((e) {
          final Map<String, dynamic> event = dartify(e) as Map<String, dynamic>;
          onUserUnpublishStream!(
            event['userId'] as String,
            event['mediaType'] as int,
            event['reason'] as String
          );
        })
      ]);
    }
    
    if (onRemoteStreamStats != null) {
      engine.callMethod('on', [
        vertc['events']['onRemoteStreamStats'],
        js_util.allowInterop((e) => onRemoteStreamStats!(Map<String, dynamic>.from(dartify(e) as Map)))
      ]);
    }
    
    if (onLocalStreamStats != null) {
      engine.callMethod('on', [
        vertc['events']['onLocalStreamStats'],
        js_util.allowInterop((e) => onLocalStreamStats!(Map<String, dynamic>.from(dartify(e) as Map)))
      ]);
    }
    
    if (onLocalAudioPropertiesReport != null) {
      engine.callMethod('on', [
        vertc['events']['onLocalAudioPropertiesReport'],
        js_util.allowInterop((e) => onLocalAudioPropertiesReport!(List.from(dartify(e) as List)))
      ]);
    }
    
    if (onRemoteAudioPropertiesReport != null) {
      engine.callMethod('on', [
        vertc['events']['onRemoteAudioPropertiesReport'],
        js_util.allowInterop((e) => onRemoteAudioPropertiesReport!(List.from(dartify(e) as List)))
      ]);
    }
    
    if (onAudioDeviceStateChanged != null) {
      engine.callMethod('on', [
        vertc['events']['onAudioDeviceStateChanged'],
        js_util.allowInterop((e) => onAudioDeviceStateChanged!(Map<String, dynamic>.from(dartify(e) as Map)))
      ]);
    }
    
    if (onUserMessageReceived != null) {
      engine.callMethod('on', [
        vertc['events']['onUserMessageReceived'],
        js_util.allowInterop((e) {
          final Map<String, dynamic> event = dartify(e) as Map<String, dynamic>;
          onUserMessageReceived!(event['userId'] as String, event['message']);
        })
      ]);
    }
    
    if (onAutoPlayFailed != null) {
      engine.callMethod('on', [
        vertc['events']['onAutoplayFailed'],
        js_util.allowInterop((e) => onAutoPlayFailed!(Map<String, dynamic>.from(dartify(e) as Map)))
      ]);
    }
    
    if (onPlayerEvent != null) {
      engine.callMethod('on', [
        vertc['events']['onPlayerEvent'],
        js_util.allowInterop((e) => onPlayerEvent!(Map<String, dynamic>.from(dartify(e) as Map)))
      ]);
    }
    
    if (onUserStartAudioCapture != null) {
      engine.callMethod('on', [
        vertc['events']['onUserStartAudioCapture'],
        js_util.allowInterop((e) {
          final Map<String, dynamic> event = dartify(e) as Map<String, dynamic>;
          onUserStartAudioCapture!(event['userId'] as String);
        })
      ]);
    }
    
    if (onUserStopAudioCapture != null) {
      engine.callMethod('on', [
        vertc['events']['onUserStopAudioCapture'],
        js_util.allowInterop((e) {
          final Map<String, dynamic> event = dartify(e) as Map<String, dynamic>;
          onUserStopAudioCapture!(event['userId'] as String);
        })
      ]);
    }
    
    if (onRoomBinaryMessageReceived != null) {
      engine.callMethod('on', [
        vertc['events']['onRoomBinaryMessageReceived'],
        js_util.allowInterop((e) {
          final Map<String, dynamic> event = dartify(e) as Map<String, dynamic>;
          onRoomBinaryMessageReceived!(event['userId'] as String, event['message']);
        })
      ]);
    }
    
    if (onNetworkQuality != null) {
      engine.callMethod('on', [
        vertc['events']['onNetworkQuality'],
        js_util.allowInterop((uplinkQuality, downlinkQuality) => onNetworkQuality!(
          uplinkQuality as String,
          downlinkQuality as String
        ))
      ]);
    }
  }
}

/// Convert JavaScript objects to Dart objects
dynamic dartify(dynamic jsObject) {
  return context['JSON'].callMethod('parse', 
    [context['JSON'].callMethod('stringify', [jsObject])]);
} 