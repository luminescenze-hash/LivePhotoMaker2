# 上传到 GitHub 并构建 unsigned IPA

本文假设你使用的是 Windows，目标是把项目上传到 GitHub，然后用 GitHub Actions 的 macOS 机器构建出 `LivePhotoMaker-unsigned.ipa`。

整个过程**不需要 Apple 开发者账号**；构建完成后，安装时再用 Sideloadly / AltStore + 你的 Apple ID 签名。

---

## 一、准备

1. 注册 / 登录 GitHub：https://github.com
2. 推荐安装 **Git for Windows**：https://git-scm.com/download/win
   - 安装时保持默认选项即可，会自带 Git Credential Manager。
3. 确认 Git 可用：

```bash
git --version
```

看到版本号即可。

---

## 二、在 GitHub 创建仓库

1. 登录 GitHub，右上角 `+` → **New repository**
2. 填写：
   - **Repository name**：例如 `live-photo-maker`
   - **Description**：可不填
   - **Visibility**：建议选 **Private**（私有仓库也能用 Actions；源码不会公开）
   - **Initialize this repository with**：
     - **不要勾选** Add a README file
     - **不要勾选** Add .gitignore
     - **不要勾选** Choose a license
3. 点击 **Create repository**

创建后会看到一个空仓库页面，里面有 `…or upload an existing file` 的链接，以及仓库地址：

```
https://github.com/<你的用户名>/live-photo-maker.git
```

---

## 三、上传哪些文件

只需要上传下面这些（保持目录结构）：

```
.github/
└── workflows/
    └── build-ipa.yml          ← 必须，GitHub Actions 靠它构建

LivePhotoMaker/                ← 必须，全部源码
├── App/
├── Models/
├── Services/
├── Views/
└── Assets.xcassets/

scripts/
└── build-unsigned-ipa.sh      ← 可选（有 Mac 时本地构建用）

README.md
project.yml                    ← 必须，CI 用 XcodeGen 生成工程
.gitignore
ExportOptions.plist.example    ← 可选，有开发者账号签名导出时用
docs/
└── github-upload.md           ← 本文
```

**不要上传：**

- `build/`、`dist/`、`Payload/`、`DerivedData/`
- `*.ipa`、`*.xcarchive`
- 本地生成的 `LivePhotoMaker.xcodeproj/`
- 真实的 `ExportOptions.plist`、`.p12`、`.mobileprovision`
- 任何 Apple ID 密码、GitHub Token、证书私钥

`.gitignore` 已经把这些排除掉了。

---

## 四、上传方式 A：Git 命令行（推荐）

在项目根目录（就是能看到 `project.yml` 的那一层文件夹）打开终端（Git Bash / PowerShell 均可），执行：

```bash
git init
git add .
git status
```

先确认 `git status` 里能看到 `.github/workflows/build-ipa.yml`、`LivePhotoMaker/`、`project.yml` 等文件，且没有把 `dist/`、`build/` 加进去。

然后：

```bash
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<你的用户名>/live-photo-maker.git
git push -u origin main
```

> 把 `<你的用户名>` 换成你的 GitHub 用户名；仓库名不是 `live-photo-maker` 的话同步替换。

第一次 `git push` 时：

- 如果弹出浏览器让你登录 GitHub，直接用浏览器授权即可（Git Credential Manager）；
- 如果没有弹出，而是要求输入用户名和密码：
  - 用户名填 GitHub 用户名；
  - 密码**不能**用登录密码，要在 GitHub：
    `Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token (classic)`，
    勾选 `repo` 权限，生成后把 token 当作密码粘贴。
  - Token 只保存在本机凭据管理器，不要发给别人。

推送完成后刷新 GitHub 仓库页面，应该能看到全部文件。

---

## 五、上传方式 B：网页上传（不装 Git）

1. 打开刚创建的空仓库页面；
2. 点击 **uploading an existing file**；
3. 一次性把以下内容拖进浏览器：
   - `LivePhotoMaker` 文件夹
   - `.github` 文件夹
   - `scripts` 文件夹
   - `README.md`、`project.yml`、`.gitignore`、`ExportOptions.plist.example`
4. 页面下方填写提交信息（例如 `Initial commit`），点击 **Commit changes**。

注意两个常见问题：

- **网页上传可能漏掉 `.github` 这种带点的文件夹**。如果上传后仓库里看不到 `.github/workflows/build-ipa.yml`，用这个办法补：
  1. 仓库页面 → **Add file → Create new file**
  2. 文件名输入：`.github/workflows/build-ipa.yml`
  3. 把本机该文件的内容完整粘贴进去
  4. Commit
- **文件夹结构必须保留**。`build-ipa.yml` 必须位于 `.github/workflows/` 下，不能直接放在仓库根目录，否则 Actions 不会识别。

---

## 六、上传方式 C：GitHub Desktop（图形化）

1. 下载安装 GitHub Desktop 并登录；
2. 菜单 **File → Add local repository**，选择本项目的上一级文件夹（能看到 `project.yml` 的那一层）；
   - 如果提示不是 Git 仓库，点击 **create a repository** 即可；
3. 左下角填写提交信息，点击 **Commit to main**；
4. 顶部 **Publish repository**：
   - Name 填 `live-photo-maker`
   - 建议勾选 **Keep this code private**
5. 发布完成后按下一步运行 Actions。

---

## 七、运行 GitHub Actions 构建 IPA

1. 打开仓库页面 → **Actions** 标签；
2. 如果第一次进入提示启用 Actions，按提示启用（Settings → Actions → General → Allow all actions）；
3. 左侧选择 **Build unsigned IPA**；
4. 右侧点击 **Run workflow** → 选择 `main` 分支 → **Run workflow**；
5. 刷新页面，等待任务变成绿色 ✓（通常几分钟）；
6. 点进这次运行，页面**最下方**的 **Artifacts** 区域下载：
   `LivePhotoMaker-unsigned-ipa`
7. 下载得到的是一个 zip，解压后里面就是：
   `LivePhotoMaker-unsigned.ipa`

> 这个 IPA 是**未签名**的，不能直接装到 iPhone。下一步用 Sideloadly / AltStore 签名安装。
>
> 免费 Apple ID 签名的 App 通常 7 天过期，到期重新签名即可。

---

## 八、常见问题

**Actions 页面没有 “Run workflow” 按钮？**
- 确认 `.github/workflows/build-ipa.yml` 在**默认分支**（通常是 `main`）上；
- 确认仓库的 Actions 已启用；
- 推送后等 1–2 分钟再刷新。

**Workflow 显示 “No workflows found”？**
- 路径不对。必须是 `.github/workflows/build-ipa.yml`，区分大小写；
- 或者文件内容 YAML 格式损坏。

**构建失败？**
- 在 Actions 运行页面展开红色步骤，把报错日志贴给我；
- 常见是 Swift 编译错误（这个项目尚未在 Xcode 中编译验证过）或 XcodeGen 配置问题，我会按日志修。

**私有仓库能免费用 Actions 吗？**
- 能，Free 计划包含一定的 Actions 分钟数；macOS runner 按 10 倍系数计费，一次构建通常几分钟，日常使用一般够用。
- 公开仓库的 Actions 通常免费。

**上传后 `.xcodeproj` 不存在，正常吗？**
- 正常。CI 里会用 `xcodegen generate` 根据 `project.yml` 生成工程，不需要提交 `.xcodeproj`。
