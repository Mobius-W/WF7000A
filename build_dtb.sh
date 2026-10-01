#!/usr/bin/env bash
# ============================================================
#  RK3399 wf7000 DTB 一键编译脚本（在 Linux 虚拟机里运行）
#
#  用法：
#    1) 把本脚本放进虚拟机，并自行把 rk3399-wf7000.dts 放到
#       内核树的 arch/arm64/boot/dts/rockchip/ 目录下
#       （脚本不复制 dts，由你自己放置）
#    2) chmod +x build_dtb.sh
#    3) ./build_dtb.sh
# ============================================================
set -e

KERNEL_DIR="$HOME/linux-6.1.y-rockchip"
DTS_IN_TREE="arch/arm64/boot/dts/rockchip/rk3399-wf7000.dts"
CROSS="aarch64-linux-gnu-"

# 1) 首次运行装依赖（去掉下面注释即可，装完可再注释掉）
# sudo apt-get update && sudo apt-get install -y git make gcc-aarch64-linux-gnu- bison flex libssl-dev bc python3

# 2) 取内核源码（仅首次下载；多镜像依次尝试，防止 GitHub 拉不下来）
if [ ! -d "$KERNEL_DIR" ]; then
  echo "==> clone 内核源码 ..."
  KERNEL_MIRRORS=(
    "https://ghproxy.com/https://github.com/unifreq/linux-6.1.y-rockchip"
    "https://gitclone.com/github.com/unifreq/linux-6.1.y-rockchip"
    "https://mirror.ghproxy.com/https://github.com/unifreq/linux-6.1.y-rockchip"
    "https://github.com/unifreq/linux-6.1.y-rockchip"
  )
  cloned=0
  for repo in "${KERNEL_MIRRORS[@]}"; do
    echo "    尝试镜像: $repo"
    if git clone --depth 1 -b main "$repo" "$KERNEL_DIR" 2>/dev/null; then
      cloned=1
      break
    fi
    echo "    失败，换下一个 ..."
  done
  [ "$cloned" -eq 1 ] || { echo "错误: 所有镜像都拉取失败"; exit 1; }
fi
cd "$KERNEL_DIR"

# 3) 确认 dts 已在树内（由你自行放置，脚本不复制）
[ -f "$DTS_IN_TREE" ] || { echo "错误: 未找到 $DTS_IN_TREE，请先把 rk3399-wf7000.dts 放入该目录"; exit 1; }

# 4) 没有 .config 就先生成 arm64 默认配置
[ -f .config ] || make ARCH=arm64 CROSS_COMPILE=$CROSS defconfig

# 5) 编译 dtb（-j 用满所有核）
make ARCH=arm64 CROSS_COMPILE=$CROSS rockchip/rk3399-wf7000.dtb -j"$(nproc)"

# 6) 拷回 home 目录
OUT="$HOME/rk3399-wf7000.dtb"
cp arch/arm64/boot/dts/rockchip/rk3399-wf7000.dtb "$OUT"
echo "完成 -> $OUT"
