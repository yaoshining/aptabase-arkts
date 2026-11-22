# Aptabase ArkTS SDK

SDK 位于 [aptabase](aptabase)。应用接入、权限、配置和上报行为见 [SDK 使用说明](aptabase/README.md)。

## 构建与发布

使用支持 HarmonyOS API 17 或更高版本的 DevEco Studio 打开项目，在 release 构建模式下构建 `aptabase` HAR 模块。也可在项目根目录运行：

```sh
devecocli build --modules aptabase --build-mode release
```

产物位于 `aptabase/build/default/outputs/default/aptabase.har`。先运行 OHPM 预检：

```sh
ohpm prepublish aptabase/build/default/outputs/default/aptabase.har
```

正式发布前，在 OHPM 中心仓个人中心添加发布公钥并获取 Publish ID。[OHPM 中心仓](https://ohpm.openharmony.cn/) · [华为 HAR 发布指引](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-har-publish/)

```sh
ohpm config set key_path ~/.ssh_ohpm/mykey
ohpm config set publish_id YOUR_PUBLISH_ID
ohpm publish aptabase/build/default/outputs/default/aptabase.har
```

中心仓审核通过后，宿主应用即可按包名安装。每次发版更新 `aptabase/oh-package.json5` 的版本和 `aptabase/CHANGELOG.md`，上报的 SDK 版本由模块包版本生成。

许可证为 [MIT](LICENSE)。
