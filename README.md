# 记账 · Ledger

> 一款**简约高级**的个人记账应用，HarmonyOS NEXT（纯血鸿蒙）原生应用。
> 基于 ArkTS + ArkUI 开发，数据全部存储在手机本地，离线可用，无需任何网络权限。

<div align="center">

![iOS 风格记账](https://img.shields.io/badge/平台-HarmonyOS%20NEXT-0d9488?style=flat-square)
![开发语言](https://img.shields.io/badge/语言-ArkTS-blue?style=flat-square)
![版本](https://img.shields.io/badge/版本-1.1.0-lightgrey?style=flat-square)

</div>

> 📝 更新记录见 [CHANGELOG.md](CHANGELOG.md)

## ✨ 功能特性

| 页面 | 功能 |
|------|------|
| **概览** | 本月余额、收入/支出汇总、支出分类环形图、最近交易、月份切换 |
| **记一笔** | 支出/收入切换、自定义数字键盘、emoji 分类、备注、日期选择 |
| **账单** | 按日期分组、关键词搜索、支出/收入筛选、长按删除 |
| **预算** | 月度预算、进度条（超 70% 变黄 / 超 90% 变红）、分类管理 |
| **设置** | 深/浅色主题切换、分类增删改、颜色选择器 |
| **数据** | 全部本地存储（Preferences），离线可用，不申请任何权限 |

## 🖥️ 开发环境

| 组件 | 版本 |
|------|------|
| DevEco Studio | 5.0+（本项目在 6.1.1 上开发验证） |
| HarmonyOS SDK | API 12+（本项目使用 API 24） |
| Node.js | 随 DevEco Studio 自动安装 |

## 🚀 快速开始（构建运行）

```bash
# 1. 克隆项目
git clone https://github.com/<你的用户名>/HarmonyLedger.git

# 2. 用 DevEco Studio 打开项目
#    File → Open → 选择 HarmonyLedger 文件夹
#    等待右下角依赖同步完成

# 3. 配置签名（首次必做）
#    File → Project Structure → Signing Configs
#    → 登录华为账号 → 勾选 Automatically generate signature

# 4. 连接手机运行
#    开启开发者模式 + USB 调试 → 点击顶栏 ▶ Run
```

> ⚠️ 若提示 `compileSdkVersion / compatibleSdkVersion 值不正确`，请将
> `build-profile.json5` 中 `compatibleSdkVersion` 改为你本机 SDK 对应的版本。

## 📲 安装部署（普通用户）

> 以下步骤适用于拿到安装包（`.hap` 文件）的普通用户，全程无需电脑、无需开发者环境。

### 方式一：桌面直接安装（推荐）

1. 通过微信 / 华为分享 / 网盘等任意方式获取安装包 `entry-default-signed.hap`（约 400KB）
2. 将文件发送到手机（微信：发送给「文件传输助手」后下载；华为设备：华为分享秒传）
3. 在手机 **文件管理器** 中找到该文件并点击
4. 首次安装会提示「允许安装未知来源应用」→ 点击 **设置 → 允许**（华为设备路径：设置 → 应用 → 权限管理）
5. 返回点击安装包 → **安装** → 完成后桌面出现「记账」图标

> ⚠️ 说明：此安装包使用调试签名，仅限个人使用，**不能**上架华为应用市场。

### 方式二：开发者直连部署（开发者使用）

适用于开发者将应用直接安装到已连接电脑的设备：

```bash
# 1. 确认设备已连接（开启 USB 调试）
hdc list targets

# 2. 安装（-r 表示覆盖安装）
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap

# 3. 启动应用
hdc shell aa start -a EntryAbility -b com.feng.ledger
```

### 卸载

桌面长按「记账」图标 → 卸载。卸载后本地记账数据将一并清除。

## 📁 项目结构

```
HarmonyLedger/
├── AppScope/                  # 应用级配置（图标、名称、bundleName）
├── entry/                     # 入口模块
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/  # 应用生命周期入口
│       │   ├── model/         # 数据模型 + Preferences 持久化层
│       │   ├── common/        # 主题系统（深/浅色设计令牌）
│       │   └── pages/         # 5 个页面
│       │       ├── Index.ets      # 概览（余额/环形图/最近交易）
│       │       ├── AddRecord.ets  # 记一笔（数字键盘/分类/日期）
│       │       ├── Records.ets    # 账单（搜索/筛选/长按删除）
│       │       ├── Budget.ets     # 预算（进度条/分类管理）
│       │       └── Settings.ets   # 设置（主题/分类增删改）
│       └── resources/         # 图标、字符串、颜色资源
├── build-profile.json5        # 工程构建配置（SDK 版本、签名）
└── hvigorfile.ts              # hvigor 构建脚本
```

## 🎨 设计语言

- **暗色优先**：`#0F0F0F` 底色 + 金色 `#D4A574` 点缀，圆角卡片 + 柔和阴影
- **等宽数字**：金额使用 tabular-nums 等宽字形，数据对齐更精致
- **自定义环形图**：纯 ArkUI Circle 实现，无第三方图表库
- **浅色模式**：设置页一键切换，设计令牌全局同步

## 📄 许可证

本项目仅供学习交流使用。
