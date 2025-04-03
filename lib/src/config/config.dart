import 'dart:async';

/// Configuration for the AIGC-RTC plugin
class AigcRtcConfig {
  /// RTC Application ID
  final String appId;
  
  /// Room ID for RTC session
  final String roomId;
  
  /// User ID for RTC session
  final String userId;
  
  /// RTC authentication token
  final String token;
  
  /// Business ID (optional)
  final String? businessId;
  
  /// ASR (Automatic Speech Recognition) Application ID
  final String asrAppId;
  
  /// TTS (Text-to-Speech) Application ID
  final String ttsAppId;
  
  /// Server URL for AIGC proxy requests
  final String serverUrl;
  
  /// Model ID for the Ark online inference service
  final String arkModelId;

  /// Configuration for the AIGC-RTC plugin
  const AigcRtcConfig({
    required this.appId,
    required this.roomId,
    required this.userId,
    required this.token,
    this.businessId,
    required this.asrAppId,
    required this.ttsAppId,
    required this.serverUrl,
    required this.arkModelId,
  });

  /// Create a copy of this configuration with the given fields replaced with new values
  AigcRtcConfig copyWith({
    String? appId,
    String? roomId,
    String? userId,
    String? token,
    String? businessId,
    String? asrAppId,
    String? ttsAppId,
    String? serverUrl,
    String? arkModelId,
  }) {
    return AigcRtcConfig(
      appId: appId ?? this.appId,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      businessId: businessId ?? this.businessId,
      asrAppId: asrAppId ?? this.asrAppId,
      ttsAppId: ttsAppId ?? this.ttsAppId,
      serverUrl: serverUrl ?? this.serverUrl,
      arkModelId: arkModelId ?? this.arkModelId,
    );
  }
}

/// Server authentication configuration
class ServerAuthConfig {
  /// Access key for server authentication
  final String accessKey;
  
  /// Secret key for server authentication
  final String secretKey;
  
  /// Session token (required for sub-accounts)
  final String? sessionToken;

  /// Server authentication configuration
  const ServerAuthConfig({
    required this.accessKey,
    required this.secretKey,
    this.sessionToken,
  });
} 