# TFOpacity

macOS 窗口透明度面板：从列表里选中某一个窗口，单独调节它的不透明度。其它窗口不受影响。

当前版本：**1.0.0**  
平台：Apple Silicon（arm64）macOS 13+

---

## 安装包

仓库不提交二进制。可自行构建，或使用打包产物：

| 文件 | 用途 |
|---|---|
| `TFOpacity.dmg` | 双击打开后，把 `TFOpacity.app` 拖到「应用程序」 |
| `TFOpacity.zip` | 解压后把 `TFOpacity.app` 拖到「应用程序」 |

本机打包后默认也会复制到桌面：

```bash
./scripts/package.sh
```

---

## 使用方法

1. 打开 **TFOpacity**（Spotlight 搜 `TFOpacity`，或在「应用程序」里打开）。
2. 在列表中选中要改的窗口。
3. 拖动或点击「不透明度」条（`0%` 完全透明，`100%` 完全不透明）。
4. 点 **应用**。
5. 需要还原时，选中该窗口，点 **恢复**。
6. 窗口有变化时，点 **刷新列表**。

说明：

- 只改当前选中的那一个窗口。
- 面板本身不会强制置顶；点到别的应用时会正常退到后面。

---

## 重要依赖：yabai

TFOpacity 通过 [yabai](https://github.com/asmvik/yabai) 修改真实窗口透明度。  
**只安装 TFOpacity 不够**，还必须：

1. 安装 yabai  
2. 部分关闭系统完整性保护（SIP）  
3. 配置 scripting addition  

否则面板能打开，但会提示改不了透明度。

### 1. 安装 yabai

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew install asmvik/formulae/yabai
```

### 2. 部分关闭 SIP（Apple Silicon）

1. 关机。  
2. 长按电源键进入「启动选项」→「选项」→ 继续。  
3. 菜单栏「实用工具」→「终端」，执行：

```bash
csrutil enable --without fs --without debug --without nvram
```

4. 重启回系统后执行，再重启一次：

```bash
sudo nvram boot-args=-arm64e_preview_abi
```

5. 可用下面命令核对（应显示 Custom Configuration，且 Filesystem / Debugging / NVRAM 为 disabled）：

```bash
csrutil status
nvram boot-args
```

### 3. 允许辅助功能并配置 scripting addition

1. 「系统设置」→「隐私与安全性」→「辅助功能」中允许 **yabai**。  
2. 写入 sudoers（会弹出密码框）：

```bash
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai
sudo chmod 440 /private/etc/sudoers.d/yabai
```

3. 在 `~/.yabairc` 中启用 load-sa，并保持 **float**（不要开自动平铺），例如：

```sh
#!/usr/bin/env sh

yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
sudo yabai --load-sa

yabai -m config \
    window_opacity on \
    active_window_opacity 1.0 \
    normal_window_opacity 1.0 \
    layout float
```

4. 启动服务：

```bash
yabai --start-service
```

升级 yabai 后，需要重新更新 `/private/etc/sudoers.d/yabai` 里的 sha256。

---

## 首次打开被拦截

本应用目前为 ad-hoc 签名，没有 Apple 开发者证书。第一次打开时若提示无法验证开发者：

1. 「系统设置」→「隐私与安全性」  
2. 找到拦截提示，选择「仍要打开」

---

## 从源码构建

需要：Xcode Command Line Tools、`swiftc`

```bash
git clone <your-repo-url> TFOpacity
cd TFOpacity
./scripts/build.sh          # 产出 build/TFOpacity.app
./scripts/package.sh        # 产出 dist/ 与桌面上的 zip、dmg
```

把构建好的 app 装到本机：

```bash
ditto build/TFOpacity.app /Applications/TFOpacity.app
open /Applications/TFOpacity.app
```

---

## 目录结构

```text
TFOpacity/
├── App/Info.plist          # 应用包信息
├── Sources/TFOpacity.swift # 源码
├── scripts/
│   ├── build.sh            # 编译 .app
│   └── package.sh          # 生成 zip / dmg
├── dist/                   # 打包产物（已 gitignore）
├── README.md
└── .gitignore
```

---

## 已知限制

- 仅 Apple Silicon 构建产物可直接运行；Intel 需在对应机器上重新 `./scripts/build.sh`。  
- 真实窗口透明度依赖 yabai scripting addition，必须部分关闭 SIP。  
- 没有菜单栏常驻图标；关闭窗口即退出应用。  

---

## 恢复 SIP（卸载后可选）

若不需要透明度功能了，可在恢复模式执行：

```bash
csrutil enable
```

并卸载 yabai / 删除 `~/.yabairc` 与 `/private/etc/sudoers.d/yabai`。
