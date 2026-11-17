<h1 align="center">Kayto</h1>

<p align="center">
  <em>Per-app, per-source internet control for Android.</em>
</p>

<p align="center">
  <a href="#status"><img alt="Status" src="https://img.shields.io/badge/status-alpha-orange"></a>
  <a href="#license"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <a href="https://flutter.dev"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.29-02569B?logo=flutter&logoColor=white"></a>
  <a href="https://kotlinlang.org"><img alt="Kotlin" src="https://img.shields.io/badge/Kotlin-2.x-7F52FF?logo=kotlin&logoColor=white"></a>
  <a href="#platform"><img alt="Platform" src="https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white"></a>
</p>

---

Kayto lets you control mobile data at a level most firewall apps don't reach: **per app, per network source**. Wi-Fi, SIM 1, and SIM 2 are three separate budgets with three separate limits, three separate schedules, and three separate enforcement decisions.

> *"Facebook may use Wi-Fi freely, 95 MB of SIM 1 per day, and 50 MB of SIM 2 on weekdays only. At 100%, cut its SIM 1 access — leave Wi-Fi alone."*

That sentence is Kayto's entire pitch.

## Features

-  **Full app inventory** — every installed app, with icon, name, and package.
-  **Per-source limits** — independent daily limits for Wi-Fi, SIM 1, and SIM 2. Presets: Infinite · 100 MB · 200 MB · 500 MB · Custom.
-  **Flexible scheduling** — "Every day" or a custom day-of-week pattern, set separately per source.
-  **Tiered notifications** — alerts at 50%, 70%, 90%, and 100% of the daily allowance, per app, per source.
-  **Enforcement at 100%** — the exhausted source is blocked for that app only. Wi-Fi keeps working when SIM 1 runs out.
-  **Real-time usage dashboard** — live device speed + per-app cumulative usage, refreshed every 5s.
-  **Light / dark mode**, custom splash screen, about + privacy policy.
-  **Local-only** — no analytics, no ads, no accounts, no cloud sync. Everything stays on your device.

## Status

**v0.1.0 — Alpha. Android-only. In active development.**

| Layer | Progress |
|---|---|
| App inventory + icons |  Done |
| Rule editor (Wi-Fi / SIM 1 / SIM 2) |  Done |
| Settings, theming, permissions |  Done |
| Real-time usage dashboard |  Done |
| VPN enforcement engine |  In progress |
| Notification scheduler |  In progress |
| Google Play release |  Planned |

iOS is not planned for v1. Apple provides no public API for consumer apps to enforce per-app network access.

## Tech Stack

| Layer | Technology |
|---|---|
| UI + state | Flutter 3.29, Riverpod |
| Native engine | Kotlin (VpnService, NetworkStatsManager, PackageManager) |
| Bridge | MethodChannel + EventChannel |
| Persistence | SharedPreferences (rules, settings) |
| Background | WorkManager, BootReceiver, foreground service |

## Architecture
