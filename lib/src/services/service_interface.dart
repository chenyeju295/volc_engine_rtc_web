/// Base interface for all services in the AIGC-RTC plugin
abstract class Service {
  /// Initialize the service
  Future<void> initialize();
  
  /// Dispose and clean up resources used by the service
  Future<void> dispose();
} 