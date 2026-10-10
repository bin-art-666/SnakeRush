# 蛇影冲刺

一款使用 **HarmonyOS 6、ArkTS 与 ArkUI** 开发的现代化贪吃蛇小游戏。

项目采用深色液态玻璃视觉风格，支持多种控制方式、动态难度、本地排行榜和主题切换。

## 功能特性

- 经典贪吃蛇移动、成长、撞墙与自身碰撞判定
- 简单、普通、困难三档难度与渐进式加速
- 滑动、虚拟方向键、键盘和电视遥控器控制
- 暂停、后台自动暂停、游戏结算和快速重开
- 本地最高分与 Top 10 排行榜
- 经典、冰蓝、霓虹、星空四套代码化主题
- 音效与振动设置
- 手机、平板、2in1、电视和手表响应式布局
- 车机端出于驾驶安全不开放游戏功能
- 页面历史与系统返回键统一返回上一界面
- 状态栏、刘海区域和底部手势区全面屏适配

## 技术栈

| 项目 | 技术 |
| --- | --- |
| 开发语言 | ArkTS |
| UI 框架 | ArkUI |
| 游戏渲染 | ArkUI Grid |
| 本地存储 | Preferences |
| 目标 SDK | HarmonyOS API 26 |
| 兼容 SDK | HarmonyOS API 23 |

## 项目结构

```text
entry/src/main/ets/
├── engine/
│   └── GameEngine.ets       # 游戏循环、移动、碰撞、食物与速度
├── model/
│   └── GameModels.ets       # 游戏状态、设置、排行榜与主题模型
├── service/
│   └── StorageService.ets   # 设置和成绩存储
├── entryability/
│   └── EntryAbility.ets     # 应用生命周期与系统返回处理
└── pages/
    └── Index.ets            # 启动、首页、游戏、排行榜等页面
```

## 本地运行

1. 安装 DevEco Studio 和 HarmonyOS API 26 SDK。
2. 克隆仓库并使用 DevEco Studio 打开项目。
3. 等待 Hvigor 与依赖同步完成。
4. 在 **Project Structure > Signing Configs** 中配置自动签名或调试证书。
5. 选择 `entry` 模块和目标设备后运行。

## 数据与隐私

- 排行榜、设置和最高分仅保存在本机。
- 排行榜统一显示“玩家”。
- 仓库不包含签名证书、私钥、令牌或本机 `local.properties`。

## 构建验证

项目已通过：

- ArkTS 编译
- Debug HAP 构建
- 游戏引擎本地单元测试

## License

本项目用于 HarmonyOS 学习、课程实践与作品展示。
