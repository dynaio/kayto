import 'package:intl/intl.dart';

/// Formats raw byte count into a human-readable string (B, KB, MB, GB).
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';

  final formatter = NumberFormat('#,##0.1', 'en_US');
  if (bytes < 1024 * 1024) {
    return '${formatter.format(bytes / 1024)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${formatter.format(bytes / (1024 * 1024))} MB';
  }
  return '${formatter.format(bytes / (1024 * 1024 * 1024))} GB';
}

/// Formats raw bytes-per-second into human-readable network speed.
String formatSpeed(num bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 B/s';

  final formatter = NumberFormat('#,##0.1', 'en_US');
  if (bytesPerSecond < 1024) {
    return '${bytesPerSecond.toInt()} B/s';
  }
  if (bytesPerSecond < 1024 * 1024) {
    return '${formatter.format(bytesPerSecond / 1024)} KB/s';
  }
  if (bytesPerSecond < 1024 * 1024 * 1024) {
    return '${formatter.format(bytesPerSecond / (1024 * 1024))} MB/s';
  }
  return '${formatter.format(bytesPerSecond / (1024 * 1024 * 1024))} GB/s';
}
