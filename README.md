# 实况合成 · LivePhotoMaker

把"U 盘里的一段 MOV + 一张 JPG"合成为一张真正的 **Live Photo（实况照片）**，直接写入 iPhone 系统相册。

本项目是 **iOS 17+ 的 SwiftUI App 源码工程**（用 XcodeGen 描述工程，不提交 `.xcodeproj`）。
仓库里**没有**编译好的 App、没有 IPA、没有签名证书，构建必须在 macOS + Xcode 上完成——所以本文档的主线是：
**在 Windows 电脑上把源码推上 GitHub → 用 GitHub Actions 的免费 macOS 机器构建 → 下载未签名 IPA → 在 Windows 上用 Sideloadly 用自己的 Apple ID 签名安装。**

---

## 一、先看这一节（重要前提）

| 事项 | 说明 |
| --- | --- |
| 代码状态 | 代码在 Windows 环境下编写，**从未在 Xcode 中编译过，也没有真机验证过**。仓库整理时已做了一轮并发/API 语法审查并修掉了已知问题，但**首次云端构建仍有可能报编译错误**，报错请按第九节的排查步骤贴日志修正。 |
| 运行要求 | iPhone 需 **iOS 17.0 或更高**（使用了 `@Observable`、`ContentUnavailableView` 等 iOS 17 API）。 |
| 电脑要求 | **Windows 完全可以**完成上传、构建、下载、签名安装全过程，不需要 Mac。只有"本机跑 Xcode"这一条路需要 macOS。 |
| 账号要求 | 使用 GitHub Actions 构建**不需要 Apple 开发者账号**；签名安装时使用你自己的 **免费 Apple ID** 即可（App 会在 7 天后失效，重新签一次即可）。 |
| 成果形态 | GitHub Actions 产出的是**未签名 IPA**（`LivePhotoMaker-unsigned.ipa`），必须先签名才能装到 iPhone。 |

---

## 二、五分钟速通

1. 把本仓库所有文件上传到你自己的 GitHub 仓库（`.github/workflows/build-ipa.yml` 必须在）。
2. 打开仓库 **Actions** → 左侧 **Build unsigned IPA** → 右侧 **Run workflow** → 等它变绿。
3. 点进这次运行，页面最下方的 **Artifacts** 下载 `LivePhotoMaker-unsigned-ipa`（是个 zip），解压得到 `LivePhotoMaker-unsigned.ipa`。
4. 在 Windows 上装 [Sideloadly](https://sideloadly.io/)，用你的 Apple ID 把这个 IPA 签名并安装到插着的 iPhone 上。
5. iPhone 上 **设置 → 通用 → VPN 与设备管理** 里信任你的开发者证书；再到 **设置 → 隐私与安全性 → 开发者模式** 打开开发者模式并重启。

下面是每一步的详细说明。

---

## 三、第 1 步：把仓库上传到 GitHub

### 3.1 准备工具

- 一个 GitHub 账号：https://github.com
- 任选一种上传方式：
  - **Git for Windows**（推荐）：https://git-scm.com/download/win
  - **GitHub Desktop**（图形化，不敲命令）：https://desktop.github.com/
  - **网页上传**（什么都不装，但容易漏掉 `.github` 这类点开头的文件夹）

### 3.2 创建仓库

GitHub 右上角 `+` → **New repository** → 名称例如 `live-photo-maker` → 可见性建议选 **Private**（私有仓库同样可以免费用 Actions）→ **不要**勾选 Add README / .gitignore / license → **Create repository**。

### 3.3 上传源码：方式 A（Git 命令行）

在本项目文件夹内（就是能看到 `project.yml`、`LivePhotoMaker` 文件夹的那一层）打开 PowerShell 或 Git Bash：

```powershell
git init
git add .
git status
```

先看一眼 `git status` 的输出：应该能看到 `.github/workflows/build-ipa.yml`、`LivePhotoMaker/`、`project.yml`、`scripts/`，并且**没有** `build/`、`dist/`、`Payload/`、`*.ipa`（`.gitignore` 已经排除）。

```powershell
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<你的用户名>/live-photo-maker.git
git push -u origin main
```

把 `<你的用户名>` 换成你自己的；仓库名不同的话一起换。第一次推送会弹浏览器让你登录 GitHub，授权即可。如果提示输入密码，**不能填 GitHub 登录密码**，要填 Personal Access Token（GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token，勾 `repo`），把 token 当密码粘贴。

### 3.4 上传源码：方式 B（网页拖拽）

仓库页面 → **uploading an existing file** → 把 `LivePhotoMaker`、`.github`、`scripts`、`docs` 四个文件夹和 `project.yml`、`README.md`、`.gitignore`、`ExportOptions.plist.example` 一起拖进去 → **Commit changes**。

> ⚠️ 网页上传经常漏掉 `.github` 文件夹（点开头的目录在资源管理器里默认隐藏，拖拽也容易失败）。提交后在仓库里看不到 `.github/workflows/build-ipa.yml` 就用这个补：
> 仓库页面 → **Add file → Create new file** → 文件名填 `.github/workflows/build-ipa.yml`（斜杠会自动建目录）→ 把本地该文件内容整段粘贴 → Commit。
> 这个文件必须**正好**在 `.github/workflows/` 下，放在根目录 Actions 不会识别。

### 3.5 上传源码：方式 C（GitHub Desktop）

GitHub Desktop → **File → Add local repository** 选中本项目文件夹 → 不是 Git 仓库时点 **create a repository** → 填提交信息 → **Commit to main** → 顶部 **Publish repository** → 建议勾上 **Keep this code private**。

更啰嗦的图文级步骤（含常见坑）见 [docs/github-upload.md](docs/github-upload.md)。

---

## 四、第 2 步：在 GitHub 上手动 Run workflow

1. 打开你的仓库页面 → 顶部 **Actions** 标签。
2. 第一次进入如果提示启用，按提示允许（Settings → Actions → General → Allow all actions and reusable workflows）。
3. 左侧列表点 **Build unsigned IPA**。
4. 右侧 **Run workflow** 下拉 → 分支选 `main` → 点绿色 **Run workflow**。
5. 刷新页面，出现一条新的运行记录，状态从黄色（Queued / In progress）变成绿色 ✓ 通常需要 3–10 分钟（首次要装 XcodeGen，会慢一些）。
6. 如果变红 ✗，点进去展开红色那一步看报错，见第九节。

工作流做了什么（想自己核对就看 `.github/workflows/build-ipa.yml`）：

- `runs-on: macos-15`，用 GitHub 免费提供的 macOS 机器（Xcode 16）；
- `brew install xcodegen` 装上工程生成器，`xcodegen generate` 用 `project.yml` 生成 `LivePhotoMaker.xcodeproj`；
- `xcodebuild ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` 编译出不签名的 `LivePhotoMaker.app`；
- 校验 `.app/LivePhotoMaker` 可执行文件存在，并打印 `Info.plist` 里的两条相册权限描述；
- 把 `.app` 塞进 `Payload/`，用 `ditto` 打成 `dist/LivePhotoMaker-unsigned.ipa`，打印 sha256；
- 用 `actions/upload-artifact@v4` 上传，artifact 名 `LivePhotoMaker-unsigned-ipa`，保留 14 天。

---

## 五、第 3 步：下载 artifact

1. 点进那次成功的运行记录。
2. 页面**最底部**的 **Artifacts** 区域 → 点 `LivePhotoMaker-unsigned-ipa` 下载。
3. 下载到的是 `LivePhotoMaker-unsigned-ipa.zip`，解压后里面是 `LivePhotoMaker-unsigned.ipa`。

> artifact 只保留 14 天，过期要重新 Run 一次。
> 未登录 GitHub 账号是下不了私有仓库的 artifact 的。

---

## 六、第 4 步：在 Windows 上用你自己的 Apple ID 签名安装

未签名 IPA 不能直接装，必须用你的 Apple ID 重新签名。Windows 上最常用的是 **Sideloadly**（免费、无需越狱、无需 Mac）。

### 6.1 准备

- Windows 电脑装 **iTunes**（从 Apple 官网或 Microsoft Store 装，Sideloadly 需要它的驱动）和 **Sideloadly**：https://sideloadly.io/
- 一根数据线，iPhone 插上电脑，手机上点 **信任此电脑**。
- 你的 **Apple ID 和密码**（免费账号即可；如果你开了双重认证，请到 https://account.apple.com → 登录与安全 → App 专用密码，生成一个专用密码，Sideloadly 里填这个，**不要填你的 Apple ID 登录密码**）。

### 6.2 签名安装

1. 打开 Sideloadly，`iOS device` 选择你的 iPhone。
2. 把 `LivePhotoMaker-unsigned.ipa` 拖到 **IPA** 框里。
3. `Apple ID` 填你的 Apple ID，密码填上一步的 **App 专用密码**。
4. 点 **Start**，输入 Apple ID 密码确认，等待进度条走完（会显示 `Done`）。
5. 首次安装后，iPhone 上打开 App 会提示"不受信任的开发者"：
   - **设置 → 通用 → VPN 与设备管理** → 找到你的 Apple ID（Developer App）→ **信任**。
6. 如果提示需要开启开发者模式：**设置 → 隐私与安全性 → 开发者模式** → 打开 → 重启手机 → 确认。

### 6.3 免费证书 7 天过期

- 用免费 Apple ID 签名的 App，签名有效期 **7 天**，到期后 App 会打不开（闪退）。
- 处理办法：到期后把 iPhone 连回电脑，用 Sideloadly 再签一次（同一个 IPA、同一个 Apple ID 即可，App 内的导入记录保存在 App 沙盒里，重签覆盖安装通常不会丢）。
- 想彻底免掉 7 天限制：加入 Apple Developer Program（99 美元/年）用你自己的证书签，有效期 1 年；或者见下一节的 TrollStore。

### 6.4 TrollStore 侧载（可选，免签名、不过期）

如果你的 iPhone 系统版本正好在 **TrollStore 支持的范围内**（大致是 iOS 14.0–16.6.1、16.7 RC、17.0；**17.1 及以上不支持**，具体以 TrollStore 官方说明为准）：

1. 先装好 **TrollStore** 本身（需要用对应版本的安装器，多数情况依赖系统漏洞，步骤随版本差异很大，请按 TrollStore 官方指引操作）。
2. 把 `LivePhotoMaker-unsigned.ipa` 传到 iPhone（AirDrop / iCloud Drive / 微信文件传输都行）。
3. 在文件 App 里长按这个 IPA → **共享** → 选 **TrollStore** → TrollStore 会自动用 ldid 签名并安装。
4. 这样装出来的 App **不会 7 天过期**，也不需要 Apple ID。

> TrollStore 只能装在它支持的系统版本上，且本质是利用系统漏洞；如果你的手机已经升到 17.1 以上，请老老实实用 Sideloadly 每 7 天重签一次。
> 另外，用 TrollStore 安装后的 App 若要在系统相册里正常写入，同样需要你在首次运行时允许"添加照片"权限。

---

## 七、可选：在 Mac 上本地构建

如果你有 Mac（或用朋友的），可以不依赖 GitHub：

```bash
brew install xcodegen
bash scripts/build-unsigned-ipa.sh
# 产物：dist/LivePhotoMaker-unsigned.ipa
```

脚本会检查 `xcodegen` / `xcodebuild`，生成工程、编译、校验 `.app` 与两条相册权限描述、打包 IPA 并打印 sha256。
有付费开发者账号时，还可以用 `xcodebuild archive` + `-exportArchive` 配 `ExportOptions.plist`（参考 `ExportOptions.plist.example`）直接导出已签名的 IPA。

---

## 八、项目结构与实现要点

```
.
├── .github/workflows/build-ipa.yml      GitHub Actions：手动触发，构建未签名 IPA
├── LivePhotoMaker/
│   ├── App/LivePhotoMakerApp.swift      @main 入口
│   ├── Models/
│   │   ├── Models.swift                 FolderRole / FoundFile / MediaPair / 导入状态与汇总
│   │   └── AppModel.swift               @Observable 状态机：选文件夹、扫描、导入、去重记录
│   ├── Services/
│   │   ├── FolderRef.swift              security-scoped 文件夹引用 + bookmark
│   │   ├── FolderPicker.swift           UIDocumentPickerViewController 包装（选文件夹）
│   │   ├── MediaScanner.swift           递归扫描 GRLIFE/*.MOV 与 DCIM/*.JPG，按同名去扩展名配对
│   │   ├── LivePhotoImporter.swift      核心：JPG 写 MakerApple 17 + MOV 重封装写元数据 + 写入相册
│   │   └── ThumbnailLoader.swift        JPG 缩略图 + 内存缓存
│   ├── Views/                           ContentView / FolderCardView / PairRowView / FolderPicker
│   └── Assets.xcassets/                 AppIcon（1024×1024）、AccentColor
├── scripts/build-unsigned-ipa.sh        macOS 本地构建脚本
├── project.yml                          XcodeGen 工程描述（权限描述、bundle id 都在这里）
├── ExportOptions.plist.example          付费账号导出签名 IPA 时的模板
├── docs/github-upload.md                上传仓库的详细步骤与常见坑
└── README.md
```

**合成逻辑（为什么这样做出来的才是真 Live Photo）**

1. 生成一个 UUID 作为 asset identifier；
2. 把它写进 JPG 的 `kCGImagePropertyMakerAppleDictionary["17"]`（ImageIO，质量 1.0，写回读校验，失败会明确报错）；
3. 用 `AVAssetReader` / `AVAssetWriter` **不转码**重封装 MOV，同时写入：
   - 顶层元数据 `com.apple.quicktime.content.identifier`（值必须与 JPG 里的一致）；
   - 一条 `mdta/com.apple.quicktime.still-image-time` 定时元数据轨，样本位于影片起点，值为 int8 的 `0xFF`；
4. 用同一个 `PHAssetCreationRequest` 同时 `addResource(.photo)` 和 `addResource(.pairedVideo)` 写入相册——只有这样才能被系统识别成"实况照片"。

**权限**

- `NSPhotoLibraryAddUsageDescription`：写入相册（主流程只需要它）。
- `NSPhotoLibraryUsageDescription`：读取相册。App 会在拥有读取权限时 `fetch` 刚写入的资产、校验 `mediaSubtypes.contains(.photoLive)`；**缺这一条，真机上一旦触发读取就会崩溃**，所以两条都写进了 `project.yml` 的 `INFOPLIST_KEY_*`。

---

## 九、故障排查

| 现象 | 处理 |
| --- | --- |
| Actions 页面没有 **Run workflow** 按钮 | `.github/workflows/build-ipa.yml` 必须在**默认分支**（`main`）上；确认 Actions 已启用；推送后等 1–2 分钟再刷新。 |
| 提示 **No workflows found** | 路径写错或 YAML 语法坏了。必须是 `.github/workflows/build-ipa.yml`，区分大小写。 |
| 构建红色失败在 **Build (unsigned)** | 展开日志找第一条 `error:`。常见是 Swift 语法/API 错误——这个项目此前没有编译验证过，把日志贴给维护者按行修。 |
| 失败在 **Generate Xcode project** | 通常是 `project.yml` 缩进/YAML 问题，或 `brew install xcodegen` 超时，重跑一次即可。 |
| 构建成功但没看到 artifact | 点进运行记录最底部 **Artifacts**；私有仓库必须先登录；超过 14 天会过期。 |
| Sideloadly 报 `Provision.cpp:150` 之类 | Apple ID 密码错（要用 App 专用密码）或双重认证未处理；换专用密码重试。 |
| 装好后点图标闪退 | 证书未被信任（设置 → 通用 → VPN 与设备管理），或免费证书已过 7 天，重签一次。 |
| App 里选文件夹后列表是空的 | U 盘目录结构要对：影片放 `GRLIFE/`（或其子目录），照片放 `DCIM/`（或其子目录）；只认 `.MOV` 与 `.JPG/.JPEG`；文件名去掉扩展名后必须一致（忽略大小写）。 |

---

## 十、已知限制

- **必须真机**：相册写入、实况照片识别在模拟器上不成立；
- 只支持 **JPG/JPEG + MOV** 组合，不支持 HEIC、PNG；
- 生成的实况照片时长取决于原 MOV（常见 3 秒左右），本工具不裁剪不转码，画质无损；
- 只读 U 盘：不会修改或删除源文件；
- 导入过程中请保持 App 在前台，长时间切后台可能被系统挂起；
- U 盘文件系统建议 exFAT/FAT32；NTFS 在 iPhone 上通常只读甚至不可用；
- 导入记录存在 `UserDefaults`（按 文件夹名 + 文件名 + 文件大小 去重），换文件夹或改文件名会被当成新文件。

---

## 十一、本仓库整理说明（相对最初压缩包做过的改动）

为让仓库能直接上传 GitHub、并让云端构建尽量一次通过，整理时做了以下改动（详细清单见交付说明）：

1. `project.yml`：补 `INFOPLIST_KEY_NSPhotoLibraryUsageDescription`（相册**读取**权限描述），保留原有的添加权限描述；
2. `Assets.xcassets/AppIcon.appiconset/`：新增 `AppIcon-1024.png` 并在 `Contents.json` 里补 `filename` 字段（此前只有 `Contents.json`、没有任何图片，会触发图标缺失的构建告警/失败）；
3. `Services/LivePhotoImporter.swift`：
   - 图像属性字典统一为 `[String: Any]` 并显式桥接 CFString 键，消除键类型歧义；
   - 元数据格式描述提取为 `makeStillImageTimeFormatDescription()`，去掉原先 `catch` 块内对已初始化 `let` 常量的重复赋值；
   - `still-image-time` 元数据样本改为在写入视频样本**之前**追加（原顺序会被 `AVAssetWriter` 拒绝），时间戳改用影片起点；
   - `Task.sleep` 换成 `Task.sleep(for:)`；
4. `Services/ThumbnailLoader.swift`：改用 `DispatchQueue` + `withCheckedContinuation`，避免 `Task.detached` 返回非 `Sendable` 的 `UIImage` 触发并发检查问题；
5. `.github/workflows/build-ipa.yml` 与 `scripts/build-unsigned-ipa.sh`：修正 `head` 提前关闭管道在 `pipefail` 下导致失败的问题（改用 `sed`），新增可执行文件、`Info.plist` 权限键校验与 sha256 打印，workflow 增加工具链信息打印、`concurrency` 去重、`timeout-minutes`、artifact 保留 14 天；
6. 本 README 改写为 Windows 用户视角，补充 Actions 手动触发、artifact 下载、Sideloadly 重签、免费证书 7 天过期与 TrollStore 侧载说明。

> 仍需注意：上述修改**没有在真实 Xcode 上编译验证过**（Windows 环境无法编译 iOS 二进制）。首次 Run workflow 若报编译错误，属于预期内风险，请按第九节把日志反馈修码。
