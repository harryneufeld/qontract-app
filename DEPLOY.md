# Deployment

## Web staging and production — Linux Docker

The deployment templates support Linux Docker staging and production with generic
environment settings and a separately managed HTTPS proxy. Packaging is tracked in
[app #34](https://github.com/harryneufeld/qontract-app/issues/34).

The web client is a static Flutter release served by nginx behind the
deployment's HTTPS reverse proxy. The API URL is **not** compiled in: the
container writes `config.js` at startup from `QONTRACT_API_BASE_URL`, which must
be the API URL reachable by the user's browser (not a Docker-internal service
name). The same image therefore serves staging and production; only the
environment differs. The base href is still a build setting: use `/` for a root
host, or rebuild with `QONTRACT_BASE_HREF=/your-path/` for a subpath deployment.

### Container build and startup

The root `Dockerfile` builds with Flutter 3.41.6 on an amd64 Linux builder and
serves static assets with the official nginx image on port 8080. The server
provides SPA fallback, returns 404 for missing assets/API paths, disables caching
without revalidation, and supplies a no-referrer policy for password-reset links.
The image's `/healthz` checks static-server availability. At startup
`deploy/docker-entrypoint.d/40-qontract-config.sh` validates
`QONTRACT_API_BASE_URL` (HTTPS, ending in `/api`, no credentials, query or
trailing slash; HTTP only for loopback smoke checks) and writes it to
`config.js`; the container refuses to start without a valid value. Changing the
URL needs only a container restart with the new value, not a rebuild.

```bash
cp deploy/staging.env.example deploy/staging.env
# Edit release tag, public API URL, base href and loopback host port.
docker compose --project-name qontract-staging-web --env-file deploy/staging.env config --quiet
docker compose --project-name qontract-staging-web --env-file deploy/staging.env build --pull
docker compose --project-name qontract-staging-web --env-file deploy/staging.env up -d --wait
```

For production use `deploy/production.env` and project name
`qontract-production-web`, keeping a different tag and port. Real env files are
gitignored. Record both app and backend commits; use a release-specific tag and
retain the previous image for rollback. Builds require network access to the
official Flutter Git repository, Debian repositories, pub.dev and container registry.

For root hosting keep `QONTRACT_BASE_HREF=/`. For `/qontract/` set
`QONTRACT_BASE_HREF=/qontract/` and rebuild; assets are placed in that subdirectory
inside the image. The external proxy must preserve this prefix and redirect
`/qontract` to `/qontract/`. Do not strip it. Restrict the public proxy location to
that prefix; the container's fallback also accepts paths outside the prefix for
internal route recovery. Flutter currently uses fragment routes, for example
`/qontract/#/reset-password?token=...`.

### Prebuilt images from GitHub Container Registry

`.github/workflows/docker-publish.yml` builds the `Dockerfile` for
`linux/amd64` and `linux/arm64`, smoke-tests it, and publishes it to
`ghcr.io/harryneufeld/qontract-web`. The image contains no deployment URLs, so
there is one image for all environments:

| Trigger | Tags |
| --- | --- |
| Push to `main` | `main`, `sha-<short-sha>` |
| Tag `vX.Y.Z` | `X.Y.Z`, `X.Y`, `latest`, `sha-<short-sha>` |
| Manual run (Actions → Docker image → Run workflow) | tags for the selected ref |
| Pull request | build and smoke test only, nothing published |

Publishing uses the workflow's `GITHUB_TOKEN`; no secrets or repository
variables are needed. Published images use base href `/`; build locally for a
subpath. The package is private, like the repository. To pull it on a server,
log in once with a personal access token (classic) that has the
`read:packages` scope:

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u harryneufeld --password-stdin
```

Then set `QONTRACT_IMAGE=ghcr.io/harryneufeld/qontract-web`, a published
`QONTRACT_RELEASE` tag and that environment's `QONTRACT_API_BASE_URL` in the env
file, and pull instead of build:

```bash
docker compose --project-name qontract-staging-web --env-file deploy/staging.env pull
docker compose --project-name qontract-staging-web --env-file deploy/staging.env up -d --no-build --wait
```

Promote the same tag from staging to production. Prefer the immutable version or
`sha-<short-sha>` tags for deployments and rollback; `main` and `latest` move
with every publish.

### HTTPS proxy and release verification

#### Optional existing Traefik integration

No reverse-proxy service is included. For a separately managed Traefik using its
Docker provider, combine the base file with `deploy/compose.traefik.yml`. Use
Docker Compose 2.24.4 or later. The override explicitly clears published host ports,
joins an existing external Docker network, and adds a TLS router pointing to the
web container's internal port 8080. Keep nginx: it serves the Flutter assets.

Fill these generic settings in your local env file:

| Setting | Meaning |
| --- | --- |
| `TRAEFIK_NETWORK` | Actual Docker network name shared with Traefik; it must already exist. |
| `TRAEFIK_ROUTER` | Globally unique router/service name; staging and production examples differ. |
| `TRAEFIK_HOST` | Public web hostname, without scheme/path, matching the app's public URL. |
| `TRAEFIK_HTTPS_ENTRYPOINT` | Existing TLS entrypoint name configured in Traefik. |

```bash
docker compose --project-name qontract-staging-web --env-file deploy/staging.env -f compose.yml -f deploy/compose.traefik.yml config --quiet
docker compose --project-name qontract-staging-web --env-file deploy/staging.env -f compose.yml -f deploy/compose.traefik.yml build --pull
docker compose --project-name qontract-staging-web --env-file deploy/staging.env -f compose.yml -f deploy/compose.traefik.yml up -d --wait
```

Use the same `-f` files for subsequent stop/start/rollback commands. Production
uses its own env file and project name. The `WEB_PORT` setting is ignored in
Traefik mode because host publishing is removed.

TLS is always enabled in this override. If Traefik supplies certificates through
its entrypoint configuration or certificate store, no resolver label is needed.
If a named ACME resolver is required, set `TRAEFIK_CERT_RESOLVER` to that existing
resolver and add `-f deploy/compose.traefik-acme.yml` after the other files. The
override does not create a resolver, certificate store or HTTP-to-HTTPS redirect;
configure those in the separately managed Traefik deployment. All checked-in
domains/network names are examples or placeholders, never deployment credentials.

The generic rule routes a dedicated hostname. Subpath assets keep their prefix;
do not attach StripPrefix middleware. On a shared hostname, adapt the router rule
to include the chosen PathPrefix and configure a redirect for its missing trailing
slash in your own override. Match the compiled `QONTRACT_BASE_HREF` and the backend
password-reset public URL. The backend has matching optional Traefik overrides
and requires Traefik's actual stable network address as its trusted immediate proxy.

References: [Traefik Docker labels](https://doc.traefik.io/traefik/reference/routing-configuration/other-providers/docker/)
and [Compose merge/reset behavior](https://docs.docker.com/reference/compose-file/merge/).

#### Host-installed proxy alternative

The Compose port binds to host loopback. Configure the existing host HTTPS proxy
to forward the public web domain to `127.0.0.1:8088` for staging (8089 for the
production example). A containerized proxy needs a dedicated private network or
an explicitly configured host connection; its own loopback is not the host's.
Do not widen port bindings without designing that connection. Keep upstream
traffic private and disable public HTTP except for redirects to HTTPS.

The API has a separate browser-reachable HTTPS address in these examples. Follow
the backend's `DEPLOY.md` for CORS, trusted proxy IPs, database choice, document
storage, account bootstrap, SMTP, coordinated backups and rollback. The app
contains no SMTP/database credentials.

#### Release verification

Verify container readiness, login/logout, create/edit contracts, document
upload/download, tenant switching, root/subpath reloads, password-reset browser
URL scrubbing and delivery through the configured SMTP server. Check
`/missing.js` returns 404 and that index/bootstrap responses revalidate. The
static health check does not prove API connectivity. Docker startup, the external
proxy and actual SMTP remain Linux staging checks; a local Flutter build alone
does not verify them. Issue #34 remains open until those checks pass.

To roll back the web client, set `QONTRACT_RELEASE` to the retained prior tag and
run Compose `up -d --no-build --wait` with the same configuration. A prior image
keeps its original base href; the API URL comes from the env file as usual.
Do not rebuild over that tag. Coordinate with the backend's database/session
rollback procedure before rolling back the API.

`tool/deploy_web.sh` and `gh-pages` are historical GitHub Pages artifacts.
Do not use them for the agreed staging/production deployment.

## Android release builds

- **Application ID:** `de.harryneufeld.qontract_app`
- **Version:** taken from `pubspec.yaml` (`version: 1.0.0+1` → versionName `1.0.0`, versionCode `1`)

### Prerequisites

- JDK 17 on `JAVA_HOME`
- Android SDK on `ANDROID_HOME` with `platform-tools`, `platforms;android-36`, `build-tools;36.0.0` installed
- Flutter 3.4x+ (`flutter doctor` should show "Android toolchain" as ✓)

### Local debug APK

Build an APK for local installation and testing (no release keystore required):

```bash
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk` and is
signed with the Android debug key. It is not intended for Play Store release.

To install it on a USB- or Wi-Fi-connected Android phone, first find its ADB
device ID, then install the APK:

```bash
adb devices -l
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

Launch qontract from the phone's app launcher. The application ID is
`de.harryneufeld.qontract_app`.

### Release signing

Release builds are signed with a dedicated release keystore. The signing
material lives **outside** the repo (never commit the keystore or
`key.properties` — both are gitignored):

1. Create a keystore (one-time):

   ```bash
   keytool -genkeypair -v \
     -keystore <path>/qontract-release.jks -storetype JKS \
     -alias qontract -keyalg RSA -keysize 2048 -validity 10000 \
     -dname "CN=Qontract, OU=Dev, O=Harry Neufeld, C=DE"
   ```

2. Copy `android/key.properties.example` to `android/key.properties` and fill
   in `storeFile` (absolute path), `keyAlias`, `storePassword`, `keyPassword`.

`android/app/build.gradle.kts` picks up `key.properties` automatically: when
it is present, release builds are signed with the release keystore; when
absent, they fall back to debug signing so local development keeps working.

> **Keep the keystore and its passwords safe.** Google Play ties an app to
> its signing key forever — if it is lost, the app can no longer be updated.

### Building

```bash
flutter build appbundle --release   # Play Store: build/app/outputs/bundle/release/app-release.aab
flutter build apk --release         # direct APK: build/app/outputs/flutter-apk/app-release.apk
```

Verify the AAB is signed with the release key (not debug) by comparing
the signing certificate embedded in the AAB with the keystore certificate —
both SHA-256 fingerprints must be identical (and the subject `CN=Qontract`,
not `Android Debug`):

```bash
cd build/app/outputs/bundle/release
unzip -p app-release.aab META-INF/QONTRACT.RSA \
  | openssl pkcs7 -inform DER -print_certs \
  | openssl x509 -noout -subject -fingerprint -sha256
keytool -exportcert -alias qontract -keystore <key.jks> -storepass <storepass> -rfc \
  | openssl x509 -noout -fingerprint -sha256
```

(`apksigner verify` does not support AAB input in build-tools 36.x — it
fails with "Missing AndroidManifest.xml"; the fingerprint check above is
the reliable procedure.)

### Historical ARM64 Linux build-host notes (QEMU shims)

A previous build host was aarch64, but the Android toolchain ships **x86_64**
Linux binaries only (Flutter's Android AOT `gen_snapshot`, `aapt2`, the
NDK `clang`/`lld`/`llvm-strip`, and the SDK's `cmake`/`ninja`). On an
x86_64 host none of this is needed — the commands above just work.

On that host each of those binaries was replaced by a small `#!/bin/sh`
wrapper that runs the original (kept next to it as `<name>.x64`) under
`qemu-x86_64` with a minimal x86_64 userspace root:

- `qemu-x86_64` + root fs: `/opt/data/android/qemu/root`
  (needs `libz.so.1` for the NDK clang — installed from Debian's
  `zlib1g` amd64 package).
- Flutter AOT: `flutter/bin/cache/artifacts/engine/android-<abi>-release/
  linux-arm64/gen_snapshot` (arm64, arm, x64 targets).
- AGP: the extracted `aapt2` in `~/.gradle`'s transform cache.
- NDK: everything in `…/ndk/*/toolchains/llvm/prebuilt/linux-x86_64/bin`
  (clang, clang++, lld — `ld.lld` must keep argv[0] `ld.lld`, hence the
  `/opt/data/android/qemu/argv0/ld.lld` symlink shim — and
  `llvm-strip`/`llvm-readelf`, which are plain `#!/bin/sh` wrappers
  around the host's native GNU `strip`/`readelf`).
- SDK cmake: `/opt/data/android/sdk/cmake/3.22.1/bin/{cmake,ninja}`.

The shims are cache-local (nothing repo-tracked). If a cache is wiped or
the NDK/cmake version changes, re-create the wrappers as above. Cost: the
first release build takes ~15 min under QEMU (AOT + CMake configure are
the slow parts); incremental builds are fast.

The AAB must be verified **after** every release build (see "Building"
above: the signing-cert fingerprint check). Note: a green
`flutter build appbundle --release` also implies debug symbols were
stripped — AGP exits non-zero if `*.so.sym` entries leak into the AAB.

### Deploying (Google Play)

1. First time only: create the app in [Google Play Console](https://play.google.com/console)
   with application ID `de.harryneufeld.qontract_app`, complete the developer
   account + app content forms.
2. Play Console → Production (or Internal) testing → create a new release →
   upload the `app-release.aab` → finish the release.
3. Bump `version: x.y.z+N` in `pubspec.yaml` before every new release
   (versionCode must always increase).

## iOS release builds

A signed, TestFlight-ready `.ipa` for iOS. **Requires a macOS host with Xcode**
(archive + export run `xcodebuild`, which does not exist on Linux/Windows;
the archive itself must be produced on a Mac,
e.g. a CI macOS runner or a local Mac).

Everything in the repo is wired for it; what's left is Apple-side setup that
only Harry (or whoever holds the Apple ID / App Store Connect access) can do.

### Prerequisites (one-time, Apple-side)

- **Apple Developer Program** membership (active, paid) for the signing team.
- **App Store distribution certificate** + an **App Store provisioning
  profile** for the app id `de.harryneufeld.qontract_app`, created in the
  [Apple Developer portal](https://developer.apple.com/account/resources/certificates/list)
  (Certificates & Profiles). Download the profile; it bundles the cert.
- The **10-character team id** of that account.
- **App Store Connect** access to upload the build (an [API Key](
  https://appstoreconnect.apple.com/access/integrations/api) is the preferred
  non-interactive method — see below).

These credentials must **never** be committed. The team id is the only value
the build needs from the environment, and it lives in
`ios/Runner/xcconfig/Secrets.xcconfig` (committed **empty** on purpose).

### Signing configuration (already in the repo)

- **Bundle id:** `de.harryneufeld.qontract_app` (matches Android, single
  source in `ios/Runner.xcodeproj/project.pbxproj`).
- **Automatic signing:** `CODE_SIGN_STYLE = Automatic` on the Runner target,
  so Xcode resolves the App Store cert + profile for `$DEVELOPMENT_TEAM` +
  the bundle id automatically (with `-allowProvisioningUpdates`).
- `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig`
  `#include` `ios/Runner/xcconfig/Secrets.xcconfig`, which is where you set
  `DEVELOPMENT_TEAM` (leave empty to use the default team of the Apple ID
  logged into Xcode).

### Building (on a Mac)

```bash
# 1. One-time on this Mac
xcode-select --install
sudo xcodebuild -license accept

# 2. Fill your team id into the (empty) committed file — do not push it
sed -i '' 's/^DEVELOPMENT_TEAM = *$/DEVELOPMENT_TEAM = ABCD1234EF/' \
  ios/Runner/xcconfig/Secrets.xcconfig

# 3. Build + export a signed, TestFlight-ready .ipa
./tool/build_ios_release.sh
# optional: bake in a real backend instead of the local-dev default
QONTRACT_API_BASE_URL=https://api.example.com ./tool/build_ios_release.sh
```

The script:

1. runs `flutter build ipa --release` (full pipeline: `pub get` →
   `xcodebuild archive -configuration Release -allowProvisioningUpdates` →
   `xcodebuild -exportArchive`),
2. resolves the **newest** produced `.ipa` under `build/ios/`,
3. prints the App Store Connect upload command and a signing-check reminder.

> **Bump `version: x.y.z+N` in `pubspec.yaml` before every release**
> (`version` → `CFBundleShortVersionString`, `N` → `CFBundleVersion`; the
> build number must always increase, same rule as Android).

### Uploading to App Store Connect

Non-interactive (recommended; uses an App Store Connect **API Key** — a
`.p8` key + key id + issuer id, kept out of the repo):

```bash
xcrun altool --upload-app --type ios -f <path>.ipa \
  --apiKey <APP_STORE_CONNECT_API_KEY_ID> --apiIssuer <ISSUER_ID> \
  --private-ks-key-path <path>/AuthKey_<ID>.p8
```

Then in [App Store Connect](https://appstoreconnect.apple.com): the build
appears → pass App Store Review (or promote to an Internal / Beta group) →
**TestFlight** is available immediately for internal testers; external
TestFlight testers can be added from the same screen.

### Verifying the release is properly signed

A green `flutter build ipa` already implies the App Store cert + profile were
applied. To double-check the embedded signing is **App Store distribution**
(not development):

```bash
# on the Mac that built it
unzip -o -q <path>.ipa -d /tmp/qipa
codesign -dv --verbose=2 /tmp/qipa/Payload/*.app | sed -n '1,6p'
# look for "Authority=Apple ... App Store" / "TeamIdentifier=<your team>"
```
