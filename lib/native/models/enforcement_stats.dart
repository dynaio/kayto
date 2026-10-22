class EnforcementStats {
  final int blockedPackets;
  final int blockedBytes;
  final bool isVpnRunning;
  final String activeNetwork;

  const EnforcementStats({
    this.blockedPackets = 0,
    this.blockedBytes = 0,
    this.isVpnRunning = false,
    this.activeNetwork = 'NONE',
  });

  double get blockedMb => blockedBytes / (1024 * 1024);

  factory EnforcementStats.fromMap(Map<String, dynamic> map) {
    return EnforcementStats(
      blockedPackets: (map['blockedPackets'] as num?)?.toInt() ?? 0,
      blockedBytes: (map['blockedBytes'] as num?)?.toInt() ?? 0,
      isVpnRunning: (map['isVpnRunning'] as bool?) ?? false,
      activeNetwork: (map['activeNetwork'] as String?) ?? 'NONE',
    );
  }
}
