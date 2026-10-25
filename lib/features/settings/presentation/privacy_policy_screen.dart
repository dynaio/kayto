import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kayto Privacy Policy',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Last updated: October 2026',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(
              theme,
              title: '1. Introduction',
              body:
                  'Kayto ("we", "our", or "the app") is an on-device data budget manager and network traffic controller engineered by Berassil Abdelkader. Kayto gives users granular, per-app, and per-network-source (Wi-Fi, SIM 1, SIM 2) bandwidth limits with tiered notifications and hard enforcement, all without requiring device root.',
            ),
            _buildSection(
              theme,
              title: '2. Zero Data Collection & Privacy First',
              body:
                  'Kayto is designed from the ground up with a strict zero-data-collection philosophy. We do not collect, store, transmit, share, or sell any personal data, identifiers, device fingerprints, browsing history, or network payloads. All configuration rules, usage counters, and enforcement stats remain strictly stored on your physical device.',
            ),
            _buildSection(
              theme,
              title: '3. Local VPN & Network Packet Processing',
              body:
                  'Kayto creates an on-device VPN interface using Android’s standard VpnService. This local VPN is used exclusively as a packet gate to inspect packet headers (specifically UID and IP headers) and enforce your configured bandwidth rules.\n\n'
                  '• No remote servers: Your internet traffic is NOT routed to, proxied through, or inspected by any remote server.\n'
                  '• No content inspection: Payload data, URLs, search queries, messages, and HTTPS encryption contents are never read, altered, or logged.\n'
                  '• Instant drop: If an application exhausts its configured budget, packets matching that app and active interface are dropped immediately on-device; all allowed traffic flows directly to destination servers.',
            ),
            _buildSection(
              theme,
              title: '4. Permissions Required & Technical Justifications',
              body:
                  'Kayto requests only the minimum set of permissions necessary to function:\n\n'
                  '• android.permission.BIND_VPN_SERVICE: Required to create the local TUN interface for per-app bandwidth gating.\n'
                  '• android.permission.PACKAGE_USAGE_STATS (Usage Access): Required to query NetworkStatsManager for daily cumulative data consumption per app across Wi-Fi and individual cellular subscriptions.\n'
                  '• android.permission.POST_NOTIFICATIONS: Required to send timely alerts when apps reach your chosen budget thresholds (50%, 70%, 90%, 100%) and foreground service status.\n'
                  '• android.permission.FOREGROUND_SERVICE (and SPECIAL_USE): Required to maintain reliable budget enforcement in the background.\n'
                  '• android.permission.RECEIVE_BOOT_COMPLETED: Required to re-establish your active budget enforcement rules upon device restart.\n'
                  '• android.permission.READ_PHONE_STATE: Used exclusively to identify active dual-SIM subscription IDs so usage can be attributed accurately to SIM 1 versus SIM 2.',
            ),
            _buildSection(
              theme,
              title: '5. Third-Party Services, SDKs & Trackers',
              body:
                  'Kayto contains zero third-party telemetry, tracking, advertising, or cloud analytics SDKs. No Google Analytics, no Firebase Analytics, no Facebook SDK, no crash reporting beacons. The application operates in complete offline isolation regarding external telemetry.',
            ),
            _buildSection(
              theme,
              title: '6. Data Storage & Deletion',
              body:
                  'All application rules, historical usage snapshots, and user preferences are saved locally on your device within encrypted app-private storage (SQLite and SharedPreferences). Uninstalling Kayto or clearing application data via Android Settings instantly and permanently deletes all stored configurations and records.',
            ),
            _buildSection(
              theme,
              title: '7. Children’s Privacy',
              body:
                  'Because Kayto does not collect any personal data from any user, it is fully safe and compliant for users of all ages, including children under 13.',
            ),
            _buildSection(
              theme,
              title: '8. Contact & Developer Information',
              body:
                  'If you have questions, feedback, or security inquiries regarding Kayto or this policy, please contact:\n\n'
                  'Berassil Abdelkader\n'
                  'AI Engineer & Independent Developer\n'
                  'Mascara, Algeria\n'
                  'Email: berassil.abdelkader@gmail.com\n'
                  'Website: https://berassil-abdelkader.web.app',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
