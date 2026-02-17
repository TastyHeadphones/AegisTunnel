# AegisTunnel Monorepo

Swift 6 architecture for an Apple-native tunnel client with real transport implementations for legitimate secure connectivity to user-owned infrastructure.

No circumvention presets or bypass tuning are included.

## Repository Layout

```text
AegisTunnel/
  AegisCore/
    Package.swift
    Sources/AegisCore/
      Controllers/TransportController.swift
      Errors/TransportError.swift
      Factories/DefaultTransportFactory.swift
      Logging/Logger.swift
      Models/
        Profile.swift
        TransportType.swift
        TransportOptions.swift
        UpstreamEndpoint.swift
        TransportStatus.swift
        TransportMetrics.swift
        TransportCapabilities.swift
        TransportDiagnostics.swift
        TransportSnapshot.swift
        Credentials.swift
      Networking/
        NetworkConnectionChannel.swift
        NetworkTLSConfigurator.swift
        TransportRuntime.swift
        TransportSecretDecoder.swift
      Pipeline/
        AsyncBackpressureQueue.swift
        TunnelPipe.swift
      Protocols/
        Transport.swift
        TransportFactory.swift
        ProfileRepository.swift
        SecretStore.swift
      Repositories/JSONProfileRepository.swift
      Security/TLSPinningVerifier.swift
      Transports/Real/
        MASQUETransport.swift
        HttpConnectTLSTransport.swift
        Socks5TLSTransport.swift
        MtlsTcpTunnelTransport.swift
        QuicTunnelTransport.swift
      Wire/
        HTTPConnectWire.swift
        Socks5Wire.swift
        MuxV1.swift
        QUICVarInt.swift
    Tests/AegisCoreTests/
      HTTPConnectWireTests.swift
      Socks5WireTests.swift
      TLSPinningVerifierTests.swift
      MuxAndBackpressureTests.swift
      QUICVectorTests.swift
      TransportControllerTests.swift
      TransportIntegrationTests.swift
      JSONProfileRepositoryTests.swift
      MockSecretStoreTests.swift
      Support/
        MockSecretStore.swift
        LoopbackServers.swift
  Apps/
    AegisShared/
      Sources/AegisShared/
        AppBootstrap.swift
        AppViewModel.swift
        ProfileDraft.swift
        KeychainSecretStore.swift
        OSLogLogger.swift
        LogStore.swift
        LogEntry.swift
    SharedUI/
      Sources/SharedUI/
        AegisRootView.swift
        ProfileListView.swift
        ProfileEditorView.swift
        ConnectionDashboardView.swift
        DiagnosticsView.swift
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

## Implemented Real Transports

All transport implementations conform to `Transport` and use async/await, actors, and non-blocking I/O:

1. `MASQUETransport`
- QUIC connection with HTTP/3-style CONNECT-UDP bootstrap.
- Datagram capsule forwarding with QUIC varint framing.
- Runtime diagnostics and metrics.

2. `HttpConnectTLSTransport`
- HTTP CONNECT handshake through user-configured proxy.
- Optional TLS/mTLS, trust evaluation, pinning support.

3. `Socks5TLSTransport`
- RFC 1928 / RFC 1929 client path (NO AUTH + USERNAME/PASSWORD).
- CONNECT command path implemented end-to-end.
- UDP associate capability surfaced as best-effort flag.

4. `MtlsTcpTunnelTransport`
- Direct TLS/mTLS tunnel.
- MUX v1 framing implemented (`openStream`, `closeStream`, `data`).

5. `QuicTunnelTransport`
- Direct QUIC transport via Network.framework.
- Stream-capable with datagram capability flags.

## Core Models and Contracts

- `UpstreamEndpoint` includes host, port, `TLSMode`, SNI, pinning, ALPN.
- `TransportOptions` is strongly typed and codable per transport.
- `Profile` stores `transportType` + typed `transportOptions`.
- Secret references are UUID credential IDs; secret values are retrieved through `SecretStore`.

## Tunnel Pipe Bridge

`TunnelPipe` provides:
- packet read/write loops
- cancellation-aware task lifecycle
- bounded backpressure queue (`AsyncBackpressureQueue`)
- metrics updates through the active transport

## App Layer Updates

- SwiftUI + Observation only (`@Observable`, `@State`, `@Bindable`).
- Profile editor now supports:
  - transport selection
  - proxy/target fields
  - TLS mode + SNI + ALPN
  - pinning hashes and credential IDs
  - proxy username/password and client identity reference
- Dashboard now shows:
  - status
  - bytes/packets/duration
  - capability flags
- Diagnostics view shows:
  - last handshake error
  - certificate evaluation summary
  - negotiated ALPN
  - QUIC version summary

## NetworkExtension Integration

Both iOS and macOS packet tunnel providers now:
- load profiles from persisted repository
- initialize `TransportController` with `DefaultTransportFactory`
- connect selected profile
- apply tunnel network settings
- bridge `NEPacketTunnelFlow` and transport with `TunnelPipe`
- support `startTunnel`, `stopTunnel`, `handleAppMessage`, `sleep`, `wake`

No hardcoded endpoint values are embedded in transport logic; selection is profile-driven.

## Build and Test

### Core package tests

```bash
cd /Users/young/Github/AegisTunnel/AegisCore
swift test
```

### Optional SOCKS loopback integration tests

```bash
cd /Users/young/Github/AegisTunnel/AegisCore
RUN_SOCKS_LOOPBACK=1 swift test --filter TransportIntegrationTests
```

### Xcode targets

1. Create/open workspace at `/Users/young/Github/AegisTunnel`.
2. Add `AegisCore` as local package dependency.
3. Add sources under `Apps/` and `Extensions/` to corresponding targets.
4. Set deployment targets to iOS 26+ and macOS 26+ in Xcode target settings.
5. Configure signing, app groups, network extension capabilities, and keychain groups.

## Entitlements Placeholders

Placeholder entitlement files already include keys for:
- `com.apple.developer.networking.networkextension`
- `com.apple.security.application-groups`
- `keychain-access-groups`

Replace placeholder values before shipping:
- `group.com.example.aegistunnel`
- `$(AppIdentifierPrefix)com.example.aegistunnel`
- bundle IDs / team IDs / system extension identifiers

## Security Notes

- Uses Apple TLS trust evaluation + optional SHA-256 pinning.
- Uses `CryptoKit` for pin hash generation.
- Uses only standards-based protocol flows and user-owned endpoint configuration.
- No stealth/bypass automation logic or restricted-service presets are provided.
