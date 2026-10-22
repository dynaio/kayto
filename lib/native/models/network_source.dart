enum NetworkSource {
  wifi,
  sim1,
  sim2;

  String get displayName {
    switch (this) {
      case NetworkSource.wifi:
        return 'Wi-Fi';
      case NetworkSource.sim1:
        return 'SIM 1';
      case NetworkSource.sim2:
        return 'SIM 2';
    }
  }

  String get code {
    switch (this) {
      case NetworkSource.wifi:
        return 'WIFI';
      case NetworkSource.sim1:
        return 'SIM_1';
      case NetworkSource.sim2:
        return 'SIM_2';
    }
  }

  static NetworkSource fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'WIFI':
        return NetworkSource.wifi;
      case 'SIM_1':
      case 'SIM1':
        return NetworkSource.sim1;
      case 'SIM_2':
      case 'SIM2':
        return NetworkSource.sim2;
      default:
        return NetworkSource.wifi;
    }
  }
}
