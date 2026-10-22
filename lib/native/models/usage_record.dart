class UsageRecord {
  final String packageName;
  final int wifiBytes;
  final int sim1Bytes;
  final int sim2Bytes;
  final bool isAttributed;

  const UsageRecord({
    required this.packageName,
    this.wifiBytes = 0,
    this.sim1Bytes = 0,
    this.sim2Bytes = 0,
    this.isAttributed = false,
  });

  int get totalBytes => wifiBytes + sim1Bytes + sim2Bytes;

  double get wifiMb => wifiBytes / (1024 * 1024);
  double get sim1Mb => sim1Bytes / (1024 * 1024);
  double get sim2Mb => sim2Bytes / (1024 * 1024);
  double get totalMb => totalBytes / (1024 * 1024);

  factory UsageRecord.fromMap(Map<String, dynamic> map) {
    return UsageRecord(
      packageName: map['packageName'] as String,
      wifiBytes: (map['wifiBytes'] as num?)?.toInt() ?? 0,
      sim1Bytes: (map['sim1Bytes'] as num?)?.toInt() ?? 0,
      sim2Bytes: (map['sim2Bytes'] as num?)?.toInt() ?? 0,
      isAttributed: (map['isAttributed'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'wifiBytes': wifiBytes,
        'sim1Bytes': sim1Bytes,
        'sim2Bytes': sim2Bytes,
        'isAttributed': isAttributed,
      };
}
