# macOS native build diagnosis and verified fix

## Environment and scope

Verified with Flutter 3.47.5 / Dart 3.13.4, Xcode 16.2 (16C5032a),
Apple Swift 6.0.3, macOS SDK 15.2 and CocoaPods 1.16.2 on arm64.
Changes are project-local. No pub-cache source patches, global Flutter/Xcode
changes, backend changes, signing/Team/entitlement/keychain configuration changes,
credentials, live Muse requests, or commits were made. Video playback code and
native video implementation remain in place; nothing was stubbed or removed.

## 1. Retain project-local CocoaPods integration

`pubspec.yaml` sets `flutter.config.enable-swift-package-manager: false`.
The earlier SwiftPM build failed with:

```
FVPViewProvider.h:9:9: error: Module 'Flutter' not found
(in target 'video_player_avfoundation_objc' from project 'video_player_avfoundation')
```

The plugin header tests `TARGET_OS_OSX` before importing a platform header;
the failing SwiftPM target took the iOS branch (`@import Flutter`) on macOS.
CocoaPods removed this header/platform failure. Existing SwiftPM integration can
remain: Flutter regenerates its package without plugin dependencies for this
option. `macos/Podfile.lock` records the native plugin set.

Official reference:
https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers#turn-off-swiftpm-for-a-single-project

This is a compatibility workaround, not a permanent SwiftPM migration strategy;
Flutter warns that disabling SwiftPM will not be allowed in a future release.

## 2. Reproduced SDK incompatibility before changing dependencies

With CocoaPods enabled and the original lock on `video_player_avfoundation`
2.12.3, running `flutter build macos --debug` again exited 1:

```
AVFactory.swift:120:56: error: extra argument 'isolation' in call
return try await avAsset.load(property, isolation: isolation)
```

The earlier unsigned Xcode compile also reported incompatible `isolation:` calls
in `VideoPlayer.swift:569`. The SDK/API mismatch, not signing, was the blocker.

## 3. Upstream evidence and smallest compatible dependency constraint

Reviewed pub.dev package metadata plus the published source archives for 2.10.0,
2.11.0, 2.11.1, and 2.12.0 through 2.12.3. Relevant sources:

- https://pub.dev/api/packages/video_player_avfoundation
- https://pub.dev/packages/video_player_avfoundation/changelog
- https://pub.dev/api/archives/video_player_avfoundation-2.12.1.tar.gz
- https://pub.dev/api/archives/video_player_avfoundation-2.12.2.tar.gz
- https://pub.dev/api/archives/video_player_avfoundation-2.12.3.tar.gz
- https://pub.dev/api/packages/video_player

The changelog identifies 2.12.2 as the native-player Swift conversion. Both
2.12.2 and 2.12.3 call `avAsset.load(property, isolation: isolation)` in
`AVFactory.swift` and `videoTrack.load(.naturalSize, isolation: #isolation)` in
`VideoPlayer.swift`; those overloads are unavailable in this SDK. Release 2.12.3
fixes an async-disposal crash but does not remove these calls. Release 2.12.1 is
the newest published release before that conversion and has no `isolation:`
calls in its Darwin Swift/Objective-C sources. It retains the 2.12.0 AirPlay
behavior and adds the zero-`minFrameDuration` crash fix. Its requirements are
Dart ^3.11.0 / Flutter >=3.41.0, satisfied by this installation.

The app's existing `video_player: ^2.10.1` constraint remains unchanged, as does
its resolved version 2.14.1. That resolved package accepts
`video_player_avfoundation: ^2.11.0` and platform interface ^6.9.0. Native
implementation 2.12.1 fits that range and accepts platform interface ^6.8.0.
Therefore no dependency override or top-level video-player downgrade is needed.

Added a normal direct dependency constraint:

```yaml
video_player_avfoundation: '>=2.12.1 <2.12.2'
```

This intentionally selects the newest compatible implementation for Xcode 16.2
and prevents a future `pub get` from restoring the known failing Swift versions.
Revisit the upper bound when upgrading the Xcode/SDK or when upstream supplies
compatible calls. This federated implementation constraint affects both macOS
and iOS; iOS compilation was not tested here.

Exact generated dependency changes:

- `pubspec.lock`: only `video_player_avfoundation` changes, 2.12.3 -> 2.12.1,
  transitive -> direct main, with the published archive checksum updated.
  All other resolved package versions remain unchanged.
- `macos/Podfile.lock`: only that plugin's podspec checksum changes,
  `083b698055ffef969fbd8b70f2952858b9afe21f` ->
  `e54d03b3b19f64f2c557354f72ce538387541ba6`.
  The pod's internal version label remains 0.0.1; pubspec.lock records the actual
  Dart plugin release.

## 4. Real native build and regression results

After the constraint change:

- `flutter pub get`: exit 0, selects `video_player_avfoundation` 2.12.1.
- `flutter build macos --debug`: exit 0 after CocoaPods installation;
  `Built build/macos/Build/Products/Debug/muse_app.app`.
- `flutter analyze`: exit 0, no issues found.
- `flutter test --reporter expanded`: exit 0, all 170 tests passed.
- `file` confirms the built executable is Mach-O 64-bit arm64.
- `codesign --verify --deep --strict --verbose=2`: exit 0, valid on disk and
  satisfies its Designated Requirement, including the native video framework.
- `codesign -dvv` reports an Apple Development signature and the existing Team.
  Signing did not block this build; no `CODE_SIGNING_ALLOWED=NO` fallback or
  signing-setting changes were needed.

Artifact:

```
/Volumes/CAI_MAC/mycode/muse2api/muse_app/build/macos/Build/Products/Debug/muse_app.app
```

Local diagnostic logs are in `/Users/nhatngo/.hermes/cache/scratch/`:
`muse-native-before.log`, `muse-native-after.log`, `muse-analyze-final.log`, and
`muse-test-final.log`. Published archives used for comparison are in
`muse-video-upstream/` beneath that scratch directory, not in the project or
patched into the pub cache.

## Remaining warnings and validation limits

The native build emits a nonfatal `NativeVideoViewFactory.createArgsCodec()`
optionality warning and the existing Flutter Assemble script-output warning.
Flutter also warns that `flutter_secure_storage_macos` lacks SwiftPM support;
CocoaPods handles it and it does not block compilation.

This is a compiled development Debug artifact, not a notarized/distribution
release. Existing development signing succeeded, but distribution signing,
notarization, launch/runtime playback, AirPlay, secure-storage/keychain behavior,
and real Muse integration have not been validated. No app launch, credentials,
or live-service requests were used to establish compilation success.
