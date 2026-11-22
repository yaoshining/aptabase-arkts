# Aptabase ArkTS SDK

面向 HarmonyOS Stage 应用的 Aptabase 事件分析 SDK，移植自 [Aptabase Kotlin SDK 0.1.0](https://github.com/aptabase/aptabase-kotlin/tree/5696f5cf7e1595c207902616f5eba48f283c1b44)。支持 HarmonyOS 5.0.5（API 17）及以上版本。SDK 只发送应用主动调用 `trackEvent` 提交的事件。

## 安装

使用本地构建的 HAR 时，在宿主应用模块目录执行：

```sh
ohpm install /path/to/aptabase.har
```

中心仓审核通过后，可以通过包名安装：

```sh
ohpm install aptabase-arkts@1.0.0
```

宿主工程应启用 `buildOption.strictMode.useNormalizedOHMUrl` 以使用 release HAR。HAR 声明了 `ohos.permission.INTERNET`，构建时会合并到宿主的权限配置中。

## 接入

在宿主的 `UIAbility` 或 `AbilityStage` 的 `onCreate` 中初始化。App Key 可在 Aptabase 控制台的 **Instructions** 页面获取。

```ts
import { Aptabase } from 'aptabase-arkts';

// 在 onCreate 中执行：
Aptabase.instance.initialize(this.context, 'A-EU-00000000');
Aptabase.instance.trackEvent('app_started');

const props = new Map<string, string | number>();
props.set('name', 'Settings');
props.set('visit_count', 1);
Aptabase.instance.trackEvent('screen_view', props);
```

使用自托管实例时传入服务器基地址，可以包含反向代理的路径前缀。生产环境请使用 HTTPS。

```ts
import { Aptabase, InitOptions, TrackingMode } from 'aptabase-arkts';

const options: InitOptions = {
  host: 'https://analytics.example.com',
  trackingMode: TrackingMode.asRelease,
  appVersion: '2.0.0',
};
Aptabase.instance.initialize(this.context, 'A-SH-00000000', options);
```

| 选项 | 行为 |
| --- | --- |
| `host` | `A-SH-*` 必填。US 和 EU 使用对应的 Aptabase Cloud 区域。DEV 使用设备侧的 `http://localhost:3000`。 |
| `trackingMode` | 默认 `TrackingMode.readFromEnvironment`，读取宿主应用的调试标记。也可使用 `asDebug` 或 `asRelease` 强制指定。 |
| `appVersion` | 覆盖上报的版本名称。默认读取宿主应用的版本名称，构建号依旧来自宿主安装包。 |

## 上报行为

- 每条事件异步 POST 到 `/api/v0/event`，并发上限为五。内存中最多有 64 条待发送事件，队列满时丢弃新事件。连接和读取超时各为 5 秒。网络或 HTTP 错误记录到 HiLog，发送失败的事件会被丢弃。
- 会话 ID 使用随机 UUID。两次事件间隔超过一小时或重新初始化后，下次上报会生成新 ID。
- 事件包含 UTC 时间、会话 ID、事件名、自定义属性，以及 HarmonyOS 版本、设备型号、语言、应用版本、构建号、调试标记和 SDK 版本。SDK 不读取设备序列号或广告标识。
- 自定义属性接受字符串和数字，调用时序列化。事件以当前配置排队。初始化前或初始化失败后，新的 `trackEvent` 调用直接返回。

## 停止事件上报

用户撤回统计授权时，调用 `Aptabase.instance.stop()`。SDK 会立即停用上报、清空队列并清除当前会话。在支持 Remote Communication Kit 的设备上，SDK 会主动取消在途请求。其他设备会释放请求对象，已发出的连接可能持续到超时。服务端已经收到的事件仍由服务端处理。

再次获得授权时，调用 `initialize()` 开始新会话。每次初始化都会先停止上一次上报。
