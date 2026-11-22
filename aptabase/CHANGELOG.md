# 更新日志

## 1.0.0

- 将 Aptabase Kotlin 0.1.0 的事件跟踪接口和单事件上报协议移植到 HarmonyOS。
- 支持 Aptabase Cloud、自托管服务器、调试模式、版本覆盖和空闲会话更新。
- 提供 `stop()`，用于停用上报、清空队列并清除会话。在支持 Remote Communication Kit 的设备上，主动取消在途请求。待发送队列上限为 64，连接和读取超时各为 5 秒。
- 提供可通过 OHPM 安装的 HAR。
