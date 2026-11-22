# Aptabase ArkTS SDK

为 HarmonyOS 应用接入 Aptabase，一个开源、注重隐私的事件分析服务。本库基于 Kotlin SDK 移植，支持 Aptabase Cloud 和自托管实例。[Aptabase](https://aptabase.com/) · [Kotlin SDK 0.1.0](https://github.com/aptabase/aptabase-kotlin/tree/5696f5cf7e1595c207902616f5eba48f283c1b44)

## 安装与初始化

SDK 适用于 HarmonyOS Stage 应用，最低版本为 HarmonyOS 5.0.5（API 17）。

在宿主应用的模块目录（通常是 `entry/`）安装本地 HAR：

```sh
ohpm install /path/to/aptabase.har
```

OHPM 中心仓审核通过后，可按包名安装：

```sh
ohpm install aptabase-arkts@1.0.0
```

使用 Release HAR 时，在宿主项目的 `build-profile.json5` 中将产品的 `buildOption.strictMode.useNormalizedOHMUrl` 设为 `true`。HAR 声明的 `ohos.permission.INTERNET` 会在构建时合并到宿主应用。

从 Aptabase 控制台左侧的 **Instructions** 页面获取 App Key。在宿主的 `UIAbility.onCreate` 中初始化 SDK：

```ts
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { Aptabase } from 'aptabase-arkts';

// 将示例值替换为你的 App Key。
const APTABASE_KEY = 'A-EU-00000000';

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    Aptabase.instance.initialize(this.context, APTABASE_KEY);

    // 可选，记录应用启动。
    Aptabase.instance.trackEvent('app_started');
  }
}
```

### 初始化选项

自托管实例需要传入 `host`。也可以通过 `InitOptions` 指定调试模式和上报版本。把下面的导入合并到文件顶部，再用配置示例替换 `onCreate` 中的初始化调用：

```ts
import { Aptabase, InitOptions, TrackingMode } from 'aptabase-arkts';

// 在 onCreate 中执行。
const options: InitOptions = {
  host: 'https://analytics.example.com',
  trackingMode: TrackingMode.asRelease,
  appVersion: '2.0.0',
};
Aptabase.instance.initialize(this.context, 'A-SH-00000000', options);
```

| 选项 | 说明 |
| --- | --- |
| `host` | `A-SH-*` 必填，填写自托管实例的基地址，可包含反向代理的路径前缀。`A-US-*` 和 `A-EU-*` 自动选择对应的云区域，`A-DEV-*` 使用设备侧的 `http://localhost:3000`。 |
| `trackingMode` | 默认为 `TrackingMode.readFromEnvironment`，读取宿主应用的调试标记。可用 `TrackingMode.asDebug` 或 `TrackingMode.asRelease` 强制指定。 |
| `appVersion` | 覆盖上报的应用版本名称。默认取宿主应用的版本名称，构建号始终取自宿主应用。 |

## 上报事件

SDK 仅上报你主动调用 `trackEvent` 提交的事件。事件可以不带属性，也可以通过 `Map` 提交字符串和数字属性。

```ts
Aptabase.instance.trackEvent('app_started');

const properties = new Map<string, string | number>();
properties.set('name', 'Settings');
properties.set('visit_count', 1);
Aptabase.instance.trackEvent('screen_view', properties);
```

事件在内存中排队并异步发送，最多同时发送五条请求。发送失败后该事件会被丢弃，错误会记入 HiLog。两次事件间隔超过一小时后，SDK 会生成新的随机会话 ID。更多字段和初始化规则见 [HAR 使用说明](aptabase/README.md)。

## 构建与发布

在 DevEco Studio 中以 Release 模式构建 `aptabase` HAR 模块，或在本项目根目录运行：

```sh
devecocli build --modules aptabase --build-mode release
ohpm prepublish aptabase/build/default/outputs/default/aptabase.har
```

首次发布时，在 OHPM 中心仓个人中心添加发布公钥并获取 Publish ID。[OHPM 中心仓](https://ohpm.openharmony.cn/) · [华为 HAR 发布指引](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-har-publish/)

```sh
ohpm config set key_path ~/.ssh_ohpm/mykey
ohpm config set publish_id YOUR_PUBLISH_ID
ohpm publish aptabase/build/default/outputs/default/aptabase.har
```

每次发版更新包版本和更新日志。上报的 SDK 版本由包版本生成。[包配置](aptabase/oh-package.json5) · [更新日志](aptabase/CHANGELOG.md)

## 许可证

[MIT](LICENSE)
