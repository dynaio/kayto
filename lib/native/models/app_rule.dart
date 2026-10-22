import 'network_source.dart';

class AppRule {
  final int? id;
  final String packageName;
  final NetworkSource source;
  final int? limitMb; // null means infinite
  final String scheduleMode; // 'DAILY' or 'CUSTOM_DAYS'
  final int customDaysBitmask; // 7-bit mask: bit 0 = Monday ... bit 6 = Sunday (127 = every day)
  final List<int> notifyAt; // [50, 70, 90, 100]
  final bool isEnforced;
  final bool isMonitored;

  const AppRule({
    this.id,
    required this.packageName,
    required this.source,
    this.limitMb,
    this.scheduleMode = 'DAILY',
    this.customDaysBitmask = 127,
    this.notifyAt = const [50, 70, 90, 100],
    this.isEnforced = true,
    this.isMonitored = true,
  });

  AppRule copyWith({
    int? id,
    String? packageName,
    NetworkSource? source,
    int? Function()? limitMb,
    String? scheduleMode,
    int? customDaysBitmask,
    List<int>? notifyAt,
    bool? isEnforced,
    bool? isMonitored,
  }) {
    return AppRule(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      source: source ?? this.source,
      limitMb: limitMb != null ? limitMb() : this.limitMb,
      scheduleMode: scheduleMode ?? this.scheduleMode,
      customDaysBitmask: customDaysBitmask ?? this.customDaysBitmask,
      notifyAt: notifyAt ?? this.notifyAt,
      isEnforced: isEnforced ?? this.isEnforced,
      isMonitored: isMonitored ?? this.isMonitored,
    );
  }

  bool isDayActive(int dayIndex) {
    // 0 = Monday, 6 = Sunday
    return ((customDaysBitmask >> dayIndex) & 1) == 1;
  }

  int withDayToggled(int dayIndex) {
    return customDaysBitmask ^ (1 << dayIndex);
  }

  bool isScheduledToday() {
    if (!isMonitored) return false;
    if (scheduleMode == 'DAILY') return true;
    final weekday = DateTime.now().weekday; // 1 = Mon ... 7 = Sun
    final dayIndex = weekday - 1;
    return isDayActive(dayIndex);
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'packageName': packageName,
      'source': source.code,
      'limitMb': limitMb,
      'scheduleMode': scheduleMode,
      'customDaysBitmask': customDaysBitmask,
      'notifyAt': notifyAt,
      'isEnforced': isEnforced,
      'isMonitored': isMonitored,
    };
  }

  factory AppRule.fromMap(Map<String, dynamic> map) {
    final rawNotify = map['notifyAt'];
    List<int> notifyList = [50, 70, 90, 100];
    if (rawNotify is List) {
      notifyList = rawNotify.map((e) => (e as num).toInt()).toList();
    } else if (rawNotify is String) {
      notifyList = rawNotify
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();
    }

    return AppRule(
      id: (map['id'] as num?)?.toInt(),
      packageName: map['packageName'] as String,
      source: NetworkSource.fromCode(map['source'] as String),
      limitMb: (map['limitMb'] as num?)?.toInt(),
      scheduleMode: (map['scheduleMode'] as String?) ?? 'DAILY',
      customDaysBitmask: (map['customDaysBitmask'] as num?)?.toInt() ?? 127,
      notifyAt: notifyList,
      isEnforced: (map['isEnforced'] as bool?) ?? true,
      isMonitored: (map['isMonitored'] as bool?) ?? true,
    );
  }
}
