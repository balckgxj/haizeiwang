# iOS 打包指南（无 Mac 方案：GitHub Actions 云构建 + Sideloadly 签名）

> 更新：2026-11-15。本工程已补全 iOS 编译路径：CMake iOS 分支 + `proj.ios` 启动工程 +
> 云端构建流水线。Windows 电脑即可完成全部操作，不需要 Mac。

## 总体流程

```
本机 git push  →  GitHub Actions（免费 macOS 云电脑）编译出未签名 ipa
              →  网页下载 ipa 到 Windows
              →  Sideloadly 用你的 Apple ID 签名
              →  数据线安装到 iPhone
```

有效期：普通（免费）Apple ID 签名的 App **7 天有效**，到期需连电脑重新签名一次
（Sideloadly 一键重签，游戏数据不丢）。升级到 $99/年 开发者账号可延至 1 年。

## 一、首次准备（一次性）

1. 注册 GitHub 账号（https://github.com，免费）。
2. 新建一个 **Private 仓库**（如 `haizeiwang`，不要公开，含游戏资源）。

## 二、推送代码到 GitHub

在本机（Windows）执行：

```powershell
cd E:\PCGame\Haizeiwang
git init
git add .
git commit -m "iOS build support"
git branch -M ios-build
git remote add origin https://github.com/<你的用户名>/haizeiwang.git
git push -u origin ios-build
```

- 推送约 650MB（engine 预编译库 + 游戏资源），视网速 5~20 分钟。
- `build/`（8.4GB）、`_tools/`、`reference/` 已被 .gitignore 排除，不会上传。
- 推送时浏览器会弹出 GitHub 登录授权。

## 三、云端编译

推送后自动触发；也可到 GitHub 仓库页面 → Actions → **iOS Build** → Run workflow 手动触发。

- 耗时约 15~30 分钟（免费私有仓库只能用 Intel 版 `macos-13` 云电脑，macos-14/Apple Silicon
  需付费计划或公开仓库，报错形如 `configuration 'macos-14-arm64-us-xl' is not supported`）。
- 成功后在 run 详情页底部 **Artifacts** 下载 `Haizeiwang-ios-unsigned`（即 ipa）。
- 失败时把 Actions 页面红色报错（或 build-log artifact）发给 AI 排查，改完重新推送即可，
  迭代很快。

## 四、Sideloadly 签名 + 安装（Windows）

1. 下载安装 Sideloadly：https://sideloadly.io（Windows 版）。
2. iPhone 用数据线连电脑，首次需在 iPhone 上点"信任"。
3. Sideloadly 里：拖入 ipa → 输入你的 Apple ID → Start。
4. iPhone 上：设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID 证书。
   （iOS 16+ 还需：设置 → 隐私与安全性 → 开发者模式 → 打开并重启）
5. 桌面出现游戏图标即可玩。7 天后过期：数据线连电脑，Sideloadly 重新签一次。

## 五、连接本机服务器

手机和电脑连**同一个 WiFi**，然后：

1. 查电脑局域网 IP：`ipconfig`（IPv4 地址，如 192.168.1.100）。
2. 改手机端配置：游戏 Documents 目录下 `netConfig.cfg` 的 `ip` 改成电脑 IP
   （端口 9999 不变）；`version_win32.cfg` 里 8080 的 `sever` 同理。
   （后续可做 App 内配置界面，见 TODO）
3. Windows 防火墙放行端口：管理员 PowerShell 执行
   ```powershell
   New-NetFirewallRule -DisplayName "DZM Game" -Direction Inbound -Protocol TCP -LocalPort 9999,8080 -Action Allow
   ```
4. 电脑上照常启动 MySQL + Java 服务端，手机进游戏登录。

## 六、工程侧改动记录（本次）

| 文件 | 改动 |
|---|---|
| `CMakeLists.txt`（根） | 新增 IOS 分支：MACOSX_BUNDLE app、`-force_load` 替代 `/WHOLEARCHIVE`、Xcode 签名/部署属性 |
| `client/CMakeLists.txt` | iOS 用 `platform_bridge/libOS/iOS`（.mm）桥接源 + `GamePlatform.mm`；`/FI` 改 `-include`；链 Foundation/UIKit/Security 等框架 |
| `proj.ios/` | 新增：模板拷贝的 main.m、AppController.mm、RootViewController.mm、Info.plist（横屏）、LaunchScreen |
| `client/compat/haizei_compat.h` | `CCMessageBox` 非 Windows 落日志；新增 MSVC CRT 名字映射（`_stricmp`→`strcasecmp` 等） |
| `.github/workflows/ios-build.yml` | 云构建流水线：cmake iOS 工具链 → xcodebuild 未签名 → 打包 ipa artifact |
| `.gitignore` | 排除 build/_tools/reference 等 |

## TODO / 已知限制

- CI 首跑大概率有少量编译错误（老代码 Clang 兼容性），按日志迭代修复。
- 未签名 ipa 首次安装需开发者模式 + 信任证书（见第四节）。
- 游戏内服列表 HTTP（8080）走手机浏览器可测：`http://<电脑IP>:8080/gameserver/dzm/1.8/servers_list.php`。
- App 图标目前是 cocos 默认图标，可后续替换 `proj.ios/Images.xcassets`。
- Lua 胶水（Gamelua.cpp）未参与编译，与 Windows 版一致；游戏主流程为 C++ 页面不受影响。
