# Aptabase ArkTS SDK

[简体中文](./README.md) · **English**

[![HarmonyOS API 17+](https://img.shields.io/badge/platform-HarmonyOS%20API%2017%2B-2563EB?style=flat)](#setup)
[![ArkTS SDK](https://img.shields.io/badge/SDK-ArkTS-5357A6?style=flat)](aptabase/Index.ets)
[![HAR version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fyaoshining%2Faptabase-arkts%2Fmain%2Faptabase%2Foh-package.json5&query=%24.version&label=HAR&prefix=v&color=0F766E&style=flat)](aptabase/CHANGELOG.md)
[![OHPM HAR](https://img.shields.io/badge/OHPM-HAR-0F766E?style=flat)](#build-and-publish)
[![MIT License](https://img.shields.io/badge/license-MIT-64748B?style=flat)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/yaoshining/aptabase-arkts?style=flat&label=stars&color=DB8B16)](https://github.com/yaoshining/aptabase-arkts/stargazers)

Add Aptabase, an open-source, privacy-first event analytics service, to your HarmonyOS app. This ArkTS port of the Kotlin SDK supports Aptabase Cloud and self-hosted instances. [Aptabase](https://aptabase.com/) · [Kotlin SDK 0.1.0](https://github.com/aptabase/aptabase-kotlin/tree/5696f5cf7e1595c207902616f5eba48f283c1b44)

[Setup](#setup) · [Track events](#track-events) · [Build and publish](#build-and-publish) · [Report an issue](https://github.com/yaoshining/aptabase-arkts/issues)

## Setup

The SDK supports HarmonyOS Stage applications running HarmonyOS 5.0.5 (API 17) or later.

To install a local HAR, run this command from your app module directory, usually `entry/`:

```sh
ohpm install /path/to/aptabase.har
```

After the package is approved for the OHPM central registry, install it by name:

```sh
ohpm install aptabase-arkts@1.0.0
```

For a release HAR, set the product’s `buildOption.strictMode.useNormalizedOHMUrl` to `true` in the host project’s `build-profile.json5`. The build merges the HAR’s `ohos.permission.INTERNET` declaration into the host app.

Get your App Key from **Instructions** in the Aptabase dashboard sidebar. Initialize the SDK in your app’s `UIAbility.onCreate`:

```ts
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { Aptabase } from 'aptabase-arkts';

// Replace the example value with your App Key.
const APTABASE_KEY = 'A-EU-00000000';

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    Aptabase.instance.initialize(this.context, APTABASE_KEY);

    // Optional: track app launches.
    Aptabase.instance.trackEvent('app_started');
  }
}
```

### Initialization options

For a self-hosted instance, pass the server’s base URL in `host`. You can also use `InitOptions` to override the tracking mode and reported app version. Add the imports at the top of the file and use the configuration in `onCreate`:

```ts
import { Aptabase, InitOptions, TrackingMode } from 'aptabase-arkts';

// Run in onCreate.
const options: InitOptions = {
  host: 'https://analytics.example.com',
  trackingMode: TrackingMode.asRelease,
  appVersion: '2.0.0',
};
Aptabase.instance.initialize(this.context, 'A-SH-00000000', options);
```

| Option | Description |
| --- | --- |
| `host` | Required for `A-SH-*` keys. Set it to the self-hosted server’s base URL, including any reverse-proxy path prefix. `A-US-*` and `A-EU-*` keys route to their cloud regions. `A-DEV-*` uses `http://localhost:3000` on the device. |
| `trackingMode` | Defaults to `TrackingMode.readFromEnvironment`, which uses the host app’s debug flag. Use `TrackingMode.asDebug` or `TrackingMode.asRelease` to override it. |
| `appVersion` | Overrides the reported app version. The host app supplies the default version name and the build number. |

## Track events

The SDK sends events only when your app calls `trackEvent`. Use a `Map` to attach optional string and numeric properties.

```ts
Aptabase.instance.trackEvent('app_started');

const properties = new Map<string, string | number>();
properties.set('name', 'Settings');
properties.set('visit_count', 1);
Aptabase.instance.trackEvent('screen_view', properties);
```

Events queue in memory and are sent asynchronously, with up to five requests in flight. The SDK drops failed events and logs the errors to HiLog. The first event after more than one hour of inactivity gets a new random session ID.

## Build and publish

Use DevEco Studio to build the `aptabase` HAR module in release mode, or run these commands from the repository root:

```sh
devecocli build --modules aptabase --build-mode release
ohpm prepublish aptabase/build/default/outputs/default/aptabase.har
```

For your first publication, add your public key in the OHPM registry account settings and copy your Publish ID. [OHPM central registry](https://ohpm.openharmony.cn/) · [Huawei's HAR publishing guide](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-har-publish/)

```sh
ohpm config set key_path ~/.ssh_ohpm/mykey
ohpm config set publish_id YOUR_PUBLISH_ID
ohpm publish aptabase/build/default/outputs/default/aptabase.har
```

Update the package version and changelog for each release. The SDK uses the package version when reporting its own version. [Package manifest](aptabase/oh-package.json5) · [Changelog](aptabase/CHANGELOG.md)

## License

[MIT](LICENSE)
