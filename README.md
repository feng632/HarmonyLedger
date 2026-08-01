# 记账 · Ledger

> 一款**简约高级**的个人记账应用，HarmonyOS NEXT（纯血鸿蒙）原生应用。
> 基于 ArkTS + ArkUI 开发，数据全部存储在手机本地，离线可用，无需任何网络权限。

<div align="center">

![iOS 风格记账](https://img.shields.io/badge/平台-HarmonyOS%20NEXT-0d9488?style=flat-square)
![开发语言](https://img.shields.io/badge/语言-ArkTS-blue?style=flat-square)
![版本](https://img.shields.io/badge/版本-1.0.0-lightgrey?style=flat-square)

</div>

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

## 📦 分享给朋友（部署指南）

> 下面两种方式任选。**方式一**适用于朋友在你身边（几分钟搞定），
> **方式二**适用于任意远程分享（一次配置，终身受益）。

### 方式一：调试包分享（同一台电脑 + 设备在身边）

> 原理：调试签名（Debug Profile）绑定设备的唯一 ID。朋友手机的签名不同，
> 需要在你电脑上重新生成包含朋友设备的签名，再构建安装。

**1. 准备朋友手机**
```
设置 → 关于手机 → 连续点击"版本号" 7 次 → 开启开发者模式
设置 → 系统与更新 → 开发者选项 → 开启 USB 调试
```

**2. 连接朋友手机到你的电脑**
- 数据线连接（必须支持数据传输），手机上选择"允许 USB 调试"

**3. 在 DevEco 中重新配置签名**
```
File → Project Structure → Signing Configs
→ 设备列表中选择朋友的手机
→ 勾选 Automatically generate signature（自动为朋友手机生成新签名）
→ Apply / OK
```

**4. 重新构建签名包**
```
Build → Build Hap(s)/APP(s) → Build Hap(s)
```
产物位置：`entry/build/default/outputs/default/entry-default-signed.hap`

**5. 安装到朋友手机**（命令行）

```bash
# hdc 路径：DevEco Studio 安装目录下的 sdk/default/openharmony/toolchains/hdc.exe
# 先确认朋友手机已连接
hdc list targets

# 安装（-r 表示覆盖安装）
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap

# 独立启动（不依赖调试会话）
hdc shell aa start -a EntryAbility -b com.feng.ledger
```

**6. 验证**
- 拔掉数据线，从朋友手机桌面点击"记账"图标
- 若应用正常打开并保持运行 → 部署成功
- 若报签名错误 → 重复第 3 步（确保签名包含了朋友设备）

> ⚠️ 调试签名包**不能**通过微信/网盘远程分享（设备绑定），
> 只能在本机 + 设备直连场景使用。每个新朋友都需重复上述流程。

### 方式二：发布包分享（任意设备，无需电脑）

> 原理：申请华为**发布证书**（免费，实名认证即可），发布签名不绑定设备，
> 任何 HarmonyOS NEXT 手机都能安装，与应用市场安装无异。

**1. 注册开发者账号并实名**
```
访问 https://developer.huawei.com/consumer/cn/
注册华为开发者联盟账号 → 完成个人实名认证（免费）
```

**2. 申请发布证书与 Profile**
```
开发者平台 → 我的项目 → 证书管理（AGC）
→ 创建发布证书（按引导生成密钥对，下载 .cer 证书）
→ 创建发布 Profile（应用包名 com.feng.ledger）
```

**3. DevEco 配置发布签名**
```
File → Project Structure → Signing Configs
→ Sign in 登录华为账号
→ 取消 Automatically generate signature
→ 手动选择：
    Store file     → 你的 .p12 密钥库
    Key alias      → 密钥别名
    Profile        → 发布的 .p7b 文件
```

**4. 构建发布包**
```
Build → Build Hap(s)/APP(s) → Build Hap(s)（选择 release）
```
产物：`entry/build/default/outputs/default/entry-default-signed.hap`

**5. 分享安装包**
- 通过微信 / 华为分享 / 网盘等任意方式发送 `.hap` 文件（约 400KB）
- 朋友在手机文件管理器中点击安装 → 首次需授权"安装未知应用"
- 安装后即独立运行，无需任何调试环境

> ✅ 发布签名包**一次生成，永久使用**。以后更新版本只需重新构建发送即可。

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
