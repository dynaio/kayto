import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../native/channels/native_channel.dart';

class NetworkSpeed {
  final int rxBps;
  final int txBps;
  final bool unsupported;

  const NetworkSpeed({
    this.rxBps = 0,
    this.txBps = 0,
    this.unsupported = false,
  });

  int get totalBps => rxBps + txBps;
}

final realtimeSpeedProvider =
    StreamProvider.autoDispose<NetworkSpeed>((ref) async* {
  // Initial baseline call to set baseline in native layer
  try {
    final init = await NativeChannel.getRealtimeDeviceSpeed();
    final unsupported = (init['unsupported'] as bool?) ?? false;
    yield NetworkSpeed(unsupported: unsupported);
  } catch (_) {
    yield const NetworkSpeed();
  }

  // Poll every 1 second while dashboard is mounted
  final ticker = Stream.periodic(const Duration(seconds: 1));
  await for (final _ in ticker) {
    try {
      final res = await NativeChannel.getRealtimeDeviceSpeed();
      final unsupported = (res['unsupported'] as bool?) ?? false;
      final rxBps = (res['rxBps'] as num?)?.toInt() ?? 0;
      final txBps = (res['txBps'] as num?)?.toInt() ?? 0;
      yield NetworkSpeed(
        rxBps: rxBps,
        txBps: txBps,
        unsupported: unsupported,
      );
    } catch (_) {
      // keep stream alive
    }
  }
});
