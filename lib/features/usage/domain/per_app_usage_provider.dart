import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../native/channels/native_channel.dart';
import '../../../native/models/usage_record.dart';

/// Periodic 5-second polling of cumulative usage for monitored apps only.
/// Pauses automatically when Dashboard is unmounted (autoDispose).
final perAppUsageSnapshotProvider =
    StreamProvider.autoDispose<List<UsageRecord>>((ref) async* {
  final appsState = ref.watch(appsProvider);
  final monitored = appsState.monitoredPackages.toList();

  try {
    final initial = await NativeChannel.getPerAppUsageSnapshot(
      monitored.isNotEmpty ? monitored : null,
    );
    yield initial;
  } catch (_) {
    yield const [];
  }

  final ticker = Stream.periodic(const Duration(seconds: 5));
  await for (final _ in ticker) {
    try {
      final currentMonitored = ref.read(appsProvider).monitoredPackages.toList();
      final records = await NativeChannel.getPerAppUsageSnapshot(
        currentMonitored.isNotEmpty ? currentMonitored : null,
      );
      yield records;
    } catch (_) {}
  }
});
