# AegisTunnel Monorepo Skeleton

This repository provides an Apple-native Swift 6 architecture skeleton for a cross-platform tunnel-style client.

Important: all transport implementations are stubs only. There is no real tunneling, proxying, bypass, or circumvention logic.

## Module Layout

```text
AegisTunnel/
  AegisCore/                               # Swift Package (logic only, no UI)
    Package.swift
    Sources/AegisCore/
      Controllers/TransportController.swift
      Factories/TransportFactory.swift
      Factories/StubTransportFactory.swift
      Logging/Logger.swift
      Models/
      Protocols/
      Repositories/JSONProfileRepository.swift
      Transports/
      Utilities/LockedBox.swift
    Tests/AegisCoreTests/
  Apps/
    AegisShared/                           # Shared app orchestration + adapters
      Sources/AegisShared/
        AppBootstrap.swift
        AppViewModel.swift
        KeychainSecretStore.swift
        OSLogLogger.swift
        LogStore.swift
        ProfileDraft.swift
    SharedUI/                              # Shared SwiftUI views
      Sources/SharedUI/
        AegisRootView.swift
        ProfileListView.swift
        ProfileEditorView.swift
        ConnectionDashboardView.swift
        LiveLogView.swift
    AegisTunnel-iOS/
      Sources/AegisTunnel_iOSApp.swift
      AegisTunnel-iOS.entitlements
    AegisTunnel-macOS/
      Sources/AegisTunnel_macOSApp.swift
      AegisTunnel-macOS.entitlements
  Extensions/
    AegisTunnelPacketTunnel-iOS/
      PacketTunnelProvider.swift
      AegisTunnelPacketTunnel-iOS.entitlements
    AegisTunnelPacketTunnel-macOS/
      PacketTunnelProvider.swift
      AegisTunnelPacketTunnel-macOS.entitlements
```

## Core Architecture (AegisCore)

- `Transport` protocol defines `connect()`, `disconnect()`, `status`, and `metrics`.
- `TransportController` actor owns active transport lifecycle and publishes `TransportSnapshot` via `AsyncStream`.
- Immutable value models:
  - `Profile`
  - `TransportStatus`
  - `TransportMetrics`
  - `TransportSnapshot`
- Persistence:
  - `ProfileRepository` protocol
  - `JSONProfileRepository` actor (file-based `Codable` JSON)
- Secrets abstraction:
  - `SecretStore` protocol
- Logging abstraction:
  - `Logger` protocol + `NoopLogger`
- Stub transport implementations:
  - `DemoTransport`
  - `TLSTunnelTransportStub`
  - `QUICTunnelTransportStub`

## App Layer

- SwiftUI + Observation only (`@Observable`, `@State`, bindings).
- `AppViewModel` (`@MainActor`) coordinates repository, secrets, and `TransportController`.
- `OSLogLogger` provides concrete logging and feeds `LogStore` for live UI logs.
- `KeychainSecretStore` provides Apple Keychain-backed secrets.
- Shared UI surfaces:
  - Profile list/create/edit/delete
  - Active profile selection
  - Connect/disconnect controls
  - Status + metrics dashboard
  - Live log stream

## NetworkExtension Scaffolding

`PacketTunnelProvider` targets for iOS and macOS are placeholders with lifecycle methods only:

- `startTunnel`
- `stopTunnel`
- `handleAppMessage`
- `sleep`
- `wake`

No packet processing or tunnel implementation is included.

## Build and Test

### Core package

```bash
cd /Users/young/Github/AegisTunnel/AegisCore
swift test
```

### Apps + extensions (Xcode wiring)

1. Create an Xcode workspace at `/Users/young/Github/AegisTunnel`.
2. Add `AegisCore` as a local Swift Package dependency.
3. Create targets:
   - iOS App target (`AegisTunnel-iOS`)
   - macOS App target (`AegisTunnel-macOS`)
   - iOS Packet Tunnel extension
   - macOS Packet Tunnel extension
   - Optional framework targets for `AegisShared` and `SharedUI` source folders
4. Add source folders from `Apps/` and `Extensions/` to matching targets.
5. Set deployment targets in Xcode to `iOS 26+` and `macOS 26+`.
6. Assign the included `.entitlements` files as placeholders and replace bundle/group identifiers.

## Entitlements Placeholders

Placeholder entitlement files include keys for:

- `com.apple.developer.networking.networkextension`
- `com.apple.security.application-groups`
- `keychain-access-groups`

Before signing/deployment, replace:

- `group.com.example.aegistunnel`
- `$(AppIdentifierPrefix)com.example.aegistunnel`
- Bundle IDs and Team IDs in target settings

## Security / Compliance Notes

- This skeleton intentionally excludes any real transport/tunnel/circumvention implementation.
- Stub transports only simulate connection state and metrics for architecture/testability workflows.
