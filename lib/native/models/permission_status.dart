class PermissionHealth {
  final bool usageAccess;
  final bool batteryOptimization;
  final bool notification;
  final bool vpnConsent;
  final bool phoneState;

  const PermissionHealth({
    this.usageAccess = false,
    this.batteryOptimization = false,
    this.notification = false,
    this.vpnConsent = false,
    this.phoneState = false,
  });

  bool get isFullyConfigured =>
      usageAccess && batteryOptimization && notification && vpnConsent;

  factory PermissionHealth.fromMap(Map<String, dynamic> map) {
    return PermissionHealth(
      usageAccess: (map['usageAccess'] as bool?) ?? false,
      batteryOptimization: (map['batteryOptimization'] as bool?) ?? false,
      notification: (map['notification'] as bool?) ?? false,
      vpnConsent: (map['vpnConsent'] as bool?) ?? false,
      phoneState: (map['phoneState'] as bool?) ?? false,
    );
  }
}
