/// Media type constants for RTC
class MediaType {
  /// Audio media type
  static const int AUDIO = 1;
  
  /// Video media type
  static const int VIDEO = 2;
  
  /// Both audio and video media type
  static const int AUDIO_AND_VIDEO = 3;
}

/// Stream index constants for RTC
class StreamIndex {
  /// Main stream index
  static const String STREAM_INDEX_MAIN = 'main';
}

/// Room profile type constants for RTC
class RoomProfileType {
  /// Communication room profile type
  static const String COMMUNICATION = 'communication';
  
  /// Chat room profile type
  static const String CHAT = 'chat';
  
  /// Live room profile type
  static const String LIVE = 'live';
  
  /// Game room profile type
  static const String GAME = 'game';
}

/// Voice chat commands
class VoiceChatCommands {
  /// Stop command
  static const String STOP = 'stop';
  
  /// Resume command
  static const String RESUME = 'resume';
  
  /// Pause command
  static const String PAUSE = 'pause';
  
  /// Interrupt command
  static const String INTERRUPT = 'interrupt';
}

/// Video render mode constants
class VideoRenderMode {
  /// Hidden render mode
  static const String RENDER_MODE_HIDDEN = 'hidden';
  
  /// Fit render mode
  static const String RENDER_MODE_FIT = 'fit';
}

/// Audio profile type constants
class AudioProfileType {
  /// Default audio profile
  static const String DEFAULT = 'default';
  
  /// High quality audio profile
  static const String HIGH_QUALITY = 'high_quality';
  
  /// High quality stereo audio profile
  static const String HIGH_QUALITY_STEREO = 'high_quality_stereo';
  
  /// Medium quality audio profile
  static const String MEDIUM_QUALITY = 'medium_quality';
  
  /// Medium quality stereo audio profile
  static const String MEDIUM_QUALITY_STEREO = 'medium_quality_stereo';
  
  /// Speech quality audio profile
  static const String SPEECH = 'speech';
}

/// Mirror type constants
class MirrorType {
  /// No mirror
  static const String MIRROR_TYPE_NONE = 'none';
  
  /// Mirror (render only)
  static const String MIRROR_TYPE_RENDER = 'render';
  
  /// Mirror (render and encoding)
  static const String MIRROR_TYPE_RENDER_AND_ENCODE = 'render_and_encode';
}

/// Stream remove reason constants
class StreamRemoveReason {
  /// End reason
  static const String END = 'end';
  
  /// Error reason
  static const String ERROR = 'error';
}

/// Network quality constants
class NetworkQuality {
  /// Unknown quality
  static const String NETWORK_QUALITY_UNKNOWN = 'unknown';
  
  /// Excellent quality
  static const String NETWORK_QUALITY_EXCELLENT = 'excellent';
  
  /// Good quality
  static const String NETWORK_QUALITY_GOOD = 'good';
  
  /// Poor quality
  static const String NETWORK_QUALITY_POOR = 'poor';
  
  /// Bad quality
  static const String NETWORK_QUALITY_BAD = 'bad';
  
  /// Very bad quality
  static const String NETWORK_QUALITY_VERY_BAD = 'very_bad';
  
  /// Down quality (not available/can't use)
  static const String NETWORK_QUALITY_DOWN = 'down';
}