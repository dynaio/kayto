class AppConstants {
  static const String appName = 'Kayto';
  static const String nativeChannel = 'com.kayto/native';
  static const String eventChannel = 'com.kayto/events';

  /// Limit presets in MB. `null` means infinite.
  static const List<int?> limitPresets = [null, 100, 200, 500];

  /// Notification thresholds as percentages.
  static const List<int> thresholds = [50, 70, 90, 100];
}
