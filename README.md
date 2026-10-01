# RK3399 wf7000 DTB 编译说明

把 Android vendor 反编译出的 `wf7000.dts` 改成可在 **6.1.y-rockchip** 内核下编译的
板级设备树 `rk3399-wf7000.dts`（RK3399 Excavator/Sapphire 改版，HDMI 输出、无 WiFi、
含 Power 键 + 6 个 ADC 键），并一键编译成 `.dtb`。

> 这不是"格式转换"——Android 和 Linux 的 DTB 本就是同一种格式。真正做的是按 mainline
> binding 重写。mainline 已有同款板子的 `rk3399-sapphire-excavator.dts`，本 dts 以它
> 为基线把显示路由从 eDP 改成 HDMI。

## 文件清单

| 文件 | 作用 |
|---|---|
| `rk3399-wf7000.dts` | 板级设备树源文件（目标产物来源） |
| `build_dtb.sh` | Linux 下一键编译脚本（虚拟机/物理机均可） |
| `wf7000.dts` | 原始 Android vendor 反编译产物，仅作硬件接线参考，不参与编译 |

## 环境要求

- 一台 Linux 环境（推荐 **Ubuntu 22.04+** 虚拟机，或 WSL2）
- 能访问网络（脚本内置多镜像，GitHub 直连拉不下来会自动换镜像）
- 磁盘空闲 **≥ 5 GB**（建议预留 8–10 GB）

## 空间占用估算（仅编 dtb，不编 vmlinux）

| 项目 | 大小 |
|---|---|
| `git clone --depth 1` 源码树（下载） | ~400–600 MB |
| 源码 checkout 后占用 | ~1.2–1.5 GB |
| 编译 dtb 过程产物（host 工具等） | ~300–500 MB |
| **建议预留空闲** | **≥ 5 GB（稳妥 8–10 GB）** |

## 一键编译

1. 虚拟机装好 Ubuntu。
2. 运行脚本前，**自行**把 `rk3399-wf7000.dts` 放入内核树的
   `arch/arm64/boot/dts/rockchip/` 目录（脚本不负责复制 dts）。
3. 在虚拟机里：

   ```bash
   chmod +x build_dtb.sh
   ./build_dtb.sh
   ```

4. 产物：虚拟机 `~` 目录下的 `rk3399-wf7000.dtb`。

脚本会自动：装依赖（首次需去注释）→ 多镜像克隆内核 → 校验 dts 已在树内
→ 生成 `.config` → 编译 dtb → 拷回 home 目录。

## 把文件弄进虚拟机的其他方式

| 方式 | 做法 |
|---|---|
| 共享文件夹（推荐） | VirtualBox/VMware 挂载，虚拟机里 `/mnt/shared` 直接读 |
| scp | `scp rk3399-wf7000.dts ubuntu@虚拟机IP:~/` |
| U 盘/拖拽 | 直接拷进虚拟机文件系统 |

## 依赖（脚本首次运行前手动装，或去掉脚本内注释自动装）

```bash
sudo apt-get install -y git make gcc-aarch64-linux-gnu- bison flex libssl-dev bc python3
```

## 部署到板子

把 `rk3399-wf7000.dtb` 放到板子的 `/boot/dtbs/<内核版本>/rockchip/`，二选一：

- `extlinux/extlinux.conf` 里写：
  ```
  FDT /dtbs/<内核版本>/rockchip/rk3399-wf7000.dtb
  ```
- 或 U-Boot 命令行：`setenv fdtfile rockchip/rk3399-wf7000.dtb`

## 已知注意点

- **rt5651 音频 GPIO**：`hp-det-gpios = gpio4 RK_PC4`、`spk-con-gpio = gpio0 RK_PB3`
  取自 Excavator 公板；耳机检测异常时改这里。
- **bootargs**：`rk3399-linux.dtsi` 里写死 `root=PARTUUID=614e0000-0000`（Armbian 约定），
  若 rootfs 不在该分区，在 `&chosen` 覆盖 bootargs。
- **ADC 键阈值**为 1.8V/10bit 理论换算值，若按键串位用 `evtest` 读实际电压微调
  `press-threshold-microvolt`。
- 编译若报某 `&label` 不存在，把报错行发回即可修正（dts 的 label 取自
  `rk3399-excavator-sapphire.dtsi` + `rk3399-linux.dtsi` 已验证的 include 链）。

## GitHub Actions 自动编译

把本仓库推到 GitHub 后，每次 push 修改 `rk3399-wf7000.dts` 会自动在云端编译并产出 dtb：

1. 在 GitHub 新建仓库，把本目录所有文件（含 `.github/workflows/`）推送上去。
2. 仓库 **Settings → Actions → General** 确认 Workflow 权限为读/写（用于上传 Artifact）。
3. push 后到仓库 **Actions** 标签页看 `Build rk3399-wf7000 DTB` 任务。
4. 任务结束后在 **Artifacts** 里下载 `rk3399-wf7000-dtb`（即编译好的 dtb）。

也可在 Actions 页面手动 **Run workflow** 触发。编译环境为 `ubuntu-latest`，
多镜像克隆内核，dts 由 workflow 自动放入内核树，无需手动操作。

## 不装 git 的纯网页上传方法

不想装 git 客户端，也能全程在 GitHub 网页完成（新建仓库 + 传文件 + 触发编译）：

1. 登录 github.com → 右上角 **+ → New repository**，填名字，选 **Public**（或 Private），
   不要勾任何初始化文件（留空），点 **Create repository**。
2. 进仓库后点 **Add file → Upload files**，把整个工作目录拖进去
   （含 `rk3399-wf7000.dts`、`build_dtb.sh`、`README.md`、`.gitignore`、
   以及 `.github/` 文件夹）。GitHub 会保留 `.github/workflows/` 目录结构。
3. 拉到底点 **Commit changes**，这次提交即触发 Actions。
4. 顶部 **Actions** 标签页看 `Build rk3399-wf7000 DTB`，结束后在 **Artifacts**
   下载 `rk3399-wf7000-dtb`。

> 若网页拖拽文件夹不便，可改用 **Add file → Create new file**，路径填
> `.github/workflows/build-dtb.yml` 并把 workflow 内容粘贴进去，其余文件用 Upload files。
> 之后每次改 dts，在网页里点开文件 → 铅笔图标编辑 → Commit，就会重新编译。

进阶：在仓库页面按键盘 **`.`** 键（或访问 `github.dev/你的名/仓库名`）可打开网页版
VS Code（github.dev），像本地编辑器一样改文件并提交，同样无需安装任何软件。

## 直接下载编译产物（本仓库新增）

本仓库的 workflow 在编译成功后，除了上传 Artifact，还会把 `rk3399-wf7000.dtb`
发布成固定 tag 的 Release 附件，**无需登录即可直接下载**：

- 最新产物：https://github.com/Mobius-W/wf7000a/releases/latest/download/rk3399-wf7000.dtb
- Release 页面：https://github.com/Mobius-W/wf7000a/releases/tag/dtb-latest

每次编译会删除并重建 `dtb-latest` 标签，所以上面的链接永远指向最新一次的产物。
Artifact（需登录、保留 90 天）仍然可用，两条路任选。
