class SimInfo {
  final int slotIndex;
  final int subscriptionId;
  final String displayName;
  final String carrierName;
  final bool isDefaultData;

  const SimInfo({
    required this.slotIndex,
    required this.subscriptionId,
    required this.displayName,
    required this.carrierName,
    required this.isDefaultData,
  });

  factory SimInfo.fromMap(Map<String, dynamic> map) {
    return SimInfo(
      slotIndex: (map['slotIndex'] as num?)?.toInt() ?? 0,
      subscriptionId: (map['subscriptionId'] as num?)?.toInt() ?? 0,
      displayName: (map['displayName'] as String?) ?? 'SIM',
      carrierName: (map['carrierName'] as String?) ?? 'Carrier',
      isDefaultData: (map['isDefaultData'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'slotIndex': slotIndex,
        'subscriptionId': subscriptionId,
        'displayName': displayName,
        'carrierName': carrierName,
        'isDefaultData': isDefaultData,
      };
}
