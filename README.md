# Batt ⚡️ - High-Performance macOS Battery Intelligence

A sleek, native macOS application built with Swift and SwiftUI that delivers uninflated raw battery telemetry, instantaneous drop rate inspection (sensitive to screen brightness changes), per-app battery consumption attribution, sudden high-drop alerts, 1-week historical data storage, and comprehensive user settings.

---

## ✨ Features

### 1. True Uninflated Battery Chemistry
* **Bypasses Apple's Smoothing**: Apple's default menu bar icon rounds numbers and applies artificial curves (e.g. lingering at 100% or rounding up).
* **Direct Hardware Registers**: Batt queries `AppleSmartBattery` in `IORegistry` (`AppleRawCurrentCapacity` and `AppleRawMaxCapacity`) to show true physical battery percentage (e.g. `77.89%` with user-selectable 1 or 2 decimal precision).
* **Side-by-Side Comparison**: Displays your Mac's uninflated percentage alongside Apple's reported integer and highlights the inflation offset.

### 2. Live Drop Rate Inspector (Brightness-Sensitive)
* **Dedicated Live Button**: Click **"Inspect Live Drop Rate"** to activate 1.0-second high-precision sampling.
* **Instantaneous Telemetry**: Directly reads hardware `InstantAmperage` and `AppleRawBatteryVoltage`.
* **Precision Sensitivity**: Adjusting screen brightness or keyboard backlights will immediately register on the live gauge (e.g. jumping from `-5.2 W` / `-5.5%/hr` to `-11.4 W` / `-12.1%/hr`).
* **Real-Time Oscillograph**: Plots a live 60-second waveform curve of discharge rate fluctuations.

### 3. Per-App Battery Consumption
* **Process Attribution**: Uses Darwin `libproc` (`proc_taskinfo`) to measure process CPU deltas and attributes actual battery discharge to running apps.
* **Drop in Percentage Terms**: See exactly how much battery each application consumed (e.g. `Safari: -2.14% battery drained`, `Xcode: -5.80%`).
* **Energy & Instant Power**: Displays consumption in `Wh`, `mAh`, or `Joules`, plus real-time wattage.
* **Native App Icons**: Shows app icons, PIDs, and relative impact progress bars.

### 4. Instantaneous High Drop Rate Alerts
* **Spike Detection**: Continuously monitors discharge rate and triggers instantaneous alerts when power draw surges above user-configurable thresholds (e.g. > 16.0 W or > 20%/hr).
* **Culprit Identification**: Identifies the top applications running during the spike.
* **Dual Alert System**: Delivers native macOS system notifications via `UserNotifications` and displays an in-app banner.

### 5. Multi-Unit Measurement Engine
Customize your preferred units across every view:
* **Power**: Watts (`W`), milliwatts (`mW`)
* **Discharge Rate**: Percentage per hour (`%/hr`), percentage per minute (`%/min`), Watts (`W`), milliamperes (`mA`)
* **Energy**: Watt-hours (`Wh`), milliampere-hours (`mAh`), Joules (`J`)
* **Current**: milliamperes (`mA`), Amperes (`A`)
* **Voltage**: Volts (`V`), millivolts (`mV`)

### 6. 7-Day Local Storage & Charts
* **Rolling 7-Day Retention**: Automatically logs battery snapshots and per-app consumption, pruning any entries older than 7 days to keep disk storage under 2 MB.
* **Interactive Charts**:
  * 24-Hour & 7-Day True Battery Percentage Curves (powered by SwiftUI `Charts`)
  * Discharge Rate History
  * Daily Consumption Breakdown table (Date, Total % dropped, Average Watts, Peak Watts)
* **Data Management**: View database size, export data, or clear history anytime.

### 7. Comprehensive Settings & Launch at Login
* **Appearance**: System, Light, and Dark themes with live switching.
* **Tracking & Performance**: Background interval (1s, 5s, 10s recommended, 30s, 60s), adaptive idle saver.
* **Menu Bar Display Formats**: Choose between True Raw %, Raw % + Drop Rate, Raw % + Watts, Watts Only, or Icon Only.
* **Auto Start with PC**: Integrated with modern macOS `SMAppService.mainApp` for clean startup item registration.

---

## 🚀 Building and Running

### Build Release `.app` Bundle
Run the build script to compile with Swift 6 and assemble the standalone `Batt.app` bundle:
```bash
./Scripts/build_app.sh
```
This generates `Batt.app` with custom high-resolution icons (`AppIcon.icns`), `Info.plist`, and ad-hoc code signature.

### Launching Batt
Double-click `Batt.app` in Finder, or run:
```bash
open Batt.app
```

### Running Unit Tests
```bash
swift test
```

---

## 🏗 Architecture

```
Batt/
├── Package.swift               // Swift 6 package manifest (macOS 14+)
├── Sources/Batt/
│   ├── App/
│   │   └── BattApp.swift       // SwiftUI @main with MenuBarExtra & WindowGroup
│   ├── Core/
│   │   ├── BatteryInfo.swift   // Telemetry models (Snapshot, SpikeAlert)
│   │   ├── BatteryMonitor.swift// IOKit & AppleSmartBattery reader
│   │   ├── ProcessEnergyTracker.swift // Darwin libproc per-app attribution
│   │   ├── DropRateEngine.swift// 1s live sampling & spike detector
│   │   ├── UnitsFormatter.swift// Multi-unit conversions & formatting
│   │   └── LaunchAtLoginManager.swift // SMAppService login item manager
│   ├── Storage/
│   │   └── HistoryStore.swift  // 7-day rolling storage & retention pruner
│   ├── State/
│   │   ├── AppState.swift      // Central observable state coordinator
│   │   └── SettingsState.swift // UserDefaults preferences & theme
│   └── Views/
│       ├── Components/         // GaugeMeter, MetricCard, LiveSparkline
│       ├── Dashboard/          // BatteryGaugeCard, LiveDropRate, AppConsumption, HistoryCharts, Alerts
│       ├── MenuBar/            // MenuBarView & MenuBarIconView
│       └── Settings/           // Multi-tab SettingsView
├── Resources/
│   ├── AppIcon.icns            // 1024x1024 multi-resolution macOS app icon
│   └── Info.plist              // App bundle configuration
└── Scripts/
    ├── generate_icon.swift     // Dynamic icon generator using AppKit
    └── build_app.sh            // Release build & bundling script
```
