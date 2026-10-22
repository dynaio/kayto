import 'dart:typed_data';

class AppInfo {
  final String packageName;
  final String label;
  final Uint8List? icon;
  final bool isSystemApp;
  final bool isMonitored;

  const AppInfo({
    required this.packageName,
    required this.label,
    this.icon,
    this.isSystemApp = false,
    this.isMonitored = false,
  });

  AppInfo copyWith({
    String? packageName,
    String? label,
    Uint8List? icon,
    bool? isSystemApp,
    bool? isMonitored,
  }) {
    return AppInfo(
      packageName: packageName ?? this.packageName,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      isSystemApp: isSystemApp ?? this.isSystemApp,
      isMonitored: isMonitored ?? this.isMonitored,
    );
  }

  factory AppInfo.fromMap(Map<String, dynamic> map) => AppInfo(
        packageName: map['packageName'] as String,
        label: map['label'] as String,
        icon: map['icon'] as Uint8List?,
        isSystemApp: (map['isSystemApp'] as bool?) ?? false,
        isMonitored: (map['isMonitored'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'label': label,
        'icon': icon,
        'isSystemApp': isSystemApp,
        'isMonitored': isMonitored,
      };
}
