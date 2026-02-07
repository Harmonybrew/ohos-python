#!/bin/sh
set -e

# 如果存在旧的目录和文件，就清理掉
# 仅清理工作目录，不清理系统目录，因为默认用户每次使用新的容器进行构建（仓库中的构建指南是这么指导的）
rm -rf *.tar.gz \
    *.tgz \
    openssl-3.3.4 \
    zlib-1.3.1 \
    gettext-1.0 \
    libffi-3.5.2 \
    util-linux-2.41.3 \
    xz-5.8.1 \
    bzip2-1.0.8 \
    zstd-1.5.7 \
    ncurses-6.5 \
    readline-8.3 \
    gdbm-1.26 \
    sqlite-autoconf-3510200 \
    Python-3.14.2 \
    python-3.14.2-ohos-arm64

# 准备一些杂项的命令行工具
curl -fSLO https://github.com/Harmonybrew/ohos-coreutils/releases/download/9.9/coreutils-9.9-ohos-arm64.tar.gz
curl -fSLO https://github.com/Harmonybrew/ohos-grep/releases/download/3.12/grep-3.12-ohos-arm64.tar.gz
curl -fSLO https://github.com/Harmonybrew/ohos-gawk/releases/download/5.3.2/gawk-5.3.2-ohos-arm64.tar.gz
curl -fSLO https://github.com/Harmonybrew/ohos-busybox/releases/download/1.37.0/busybox-1.37.0-ohos-arm64.tar.gz
tar -zxf coreutils-9.9-ohos-arm64.tar.gz -C /opt
tar -zxf grep-3.12-ohos-arm64.tar.gz -C /opt
tar -zxf gawk-5.3.2-ohos-arm64.tar.gz -C /opt
tar -zxf busybox-1.37.0-ohos-arm64.tar.gz -C /opt

# 准备鸿蒙版 make、perl
curl -fSLO https://github.com/Harmonybrew/ohos-make/releases/download/4.4.1/make-4.4.1-ohos-arm64.tar.gz
curl -fSLO https://github.com/Harmonybrew/ohos-perl/releases/download/5.42.0/perl-5.42.0-ohos-arm64.tar.gz
tar -zxf make-4.4.1-ohos-arm64.tar.gz -C /opt
tar -zxf perl-5.42.0-ohos-arm64.tar.gz -C /opt

# 准备鸿蒙版 ohos-sdk
sdk_download_url="https://cidownload.openharmony.cn/version/Master_Version/ohos-sdk-public_ohos/20251209_020142/version-Master_Version-ohos-sdk-public_ohos-20251209_020142-ohos-sdk-public_ohos.tar.gz"
curl -fSL -o ohos-sdk.tar.gz $sdk_download_url
mkdir /opt/ohos-sdk
tar -zxf ohos-sdk.tar.gz -C /opt/ohos-sdk
cd /opt/ohos-sdk/ohos
/opt/busybox-1.37.0-ohos-arm64/bin/busybox unzip -q native-ohos-x64-6.1.0.21-Canary1.zip
rm -rf *.zip
cd - >/dev/null

# 把 llvm 软链接成 cc、gcc 等命令
cd /opt/ohos-sdk/ohos/native/llvm/bin
ln -s clang cc
ln -s clang gcc
ln -s clang++ c++
ln -s clang++ g++
ln -s ld.lld ld
ln -s llvm-addr2line addr2line
ln -s llvm-ar ar
ln -s llvm-cxxfilt c++filt
ln -s llvm-nm nm
ln -s llvm-objcopy objcopy
ln -s llvm-objdump objdump
ln -s llvm-ranlib ranlib
ln -s llvm-readelf readelf
ln -s llvm-size size
ln -s llvm-strip strip
cd - >/dev/null

# 准备环境变量
export PATH=/opt/coreutils-9.9-ohos-arm64/bin:$PATH
export PATH=/opt/grep-3.12-ohos-arm64/bin:$PATH
export PATH=/opt/gawk-5.3.2-ohos-arm64/bin:$PATH
export PATH=/opt/busybox-1.37.0-ohos-arm64/bin:$PATH
export PATH=/opt/make-4.4.1-ohos-arm64/bin:$PATH
export PATH=/opt/perl-5.42.0-ohos-arm64/bin:$PATH
export PATH=/opt/ohos-sdk/ohos/native/llvm/bin:$PATH
export CFLAGS="-fPIC"
export CPPFLAGS="-I/opt/deps/include"
export LDFLAGS="-L/opt/deps/lib"
export LD_LIBRARY_PATH="/opt/deps/lib"

# 编 openssl
curl -fSLO https://github.com/openssl/openssl/releases/download/openssl-3.3.4/openssl-3.3.4.tar.gz
tar -zxf openssl-3.3.4.tar.gz
cd openssl-3.3.4
# 修改证书目录和聚合文件路径，让它能在 OpenHarmony 平台上正确地找到证书
sed -i 's|OPENSSLDIR "/certs"|"/etc/ssl/certs"|' include/internal/common.h
sed -i 's|OPENSSLDIR "/cert.pem"|"/etc/ssl/certs/cacert.pem"|' include/internal/common.h
./Configure \
    --prefix=/opt/deps \
    --openssldir=/etc/ssl \
    no-legacy \
    no-module \
    no-engine \
    linux-aarch64
make -j$(nproc)
make install_sw
cd ..

# 编 zlib
curl -fSLO https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
tar -zxf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --prefix=/opt/deps
make -j$(nproc)
make install
cd ..

# 编 gettext
curl -fSLO https://ftp.gnu.org/gnu/gettext/gettext-1.0.tar.gz
tar -zxf gettext-1.0.tar.gz
cd gettext-1.0
./configure --prefix=/opt/deps
make -j$(nproc)
make install
cd ..

# 编 libffi
curl -fSLO https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz
tar -zxf libffi-3.5.2.tar.gz
cd libffi-3.5.2
./configure --prefix=/opt/deps
make -j$(nproc)
make install
cd ..

# 编 util-linux（libuuid）
curl -fSLO https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.41/util-linux-2.41.3.tar.gz
tar -zxf util-linux-2.41.3.tar.gz
cd util-linux-2.41.3
./configure \
    --prefix=/opt/deps \
    --disable-all-programs \
    --enable-libuuid \
    --disable-gtk-doc \
    --disable-nls
make -j$(nproc)
make install
cd ..

# 编 xz（liblzma）
curl -fSLO https://github.com/tukaani-project/xz/releases/download/v5.8.1/xz-5.8.1.tar.gz
tar -zxf xz-5.8.1.tar.gz
cd xz-5.8.1
./configure --prefix=/opt/deps
make -j$(nproc)
make install
cd ..

# 编 bzip2
curl -fSLO https://mirrors.kernel.org/sourceware/bzip2/bzip2-1.0.8.tar.gz
tar -zxf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8
make -f Makefile-libbz2_so
cp libbz2.so.1.0.8 /opt/deps/lib
cp bzlib.h /opt/deps/include
cd ..
cd /opt/deps/lib
ln -s libbz2.so.1.0.8 libbz2.so.1.0
ln -s libbz2.so.1.0.8 libbz2.so.1
ln -s libbz2.so.1.0.8 libbz2.so
cd - >/dev/null

# 编译 zstd
curl -fSL -o zstd-1.5.7.tar.gz https://github.com/facebook/zstd/archive/refs/tags/v1.5.7.tar.gz
tar -zxf zstd-1.5.7.tar.gz
cd zstd-1.5.7
sed -i 's@!defined(__ANDROID__)@!defined(__ANDROID__) \&\& !defined(__OHOS__)@g' lib/common/zstd_deps.h
sed -i 's@!defined(__ANDROID__)@!defined(__ANDROID__) \&\& !defined(__OHOS__)@g' lib/dictBuilder/cover.c
make -j$(nproc)
make install PREFIX=/opt/deps
cd ..

# 编译 ncurses
curl -fSLO https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz
tar -zxf ncurses-6.5.tar.gz
cd ncurses-6.5
./configure \
    --prefix=/opt/deps \
    --enable-termcap \
    --enable-widec \
    --with-shared \
    --with-fallbacks=xterm,xterm-256color,xterm-color,screen,screen-256color,tmux,tmux-256color,linux,vt100,vt102,ansi
make -j$(nproc)
make install
cp /opt/deps/include/ncursesw/*.h /opt/deps/include
cd ..

# 编译 readline
curl -fSLO https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz
tar -zxf readline-8.3.tar.gz
cd readline-8.3
./configure --prefix=/opt/deps --with-curses
make -j$(nproc) SHLIB_LIBS="-lncursesw"
make install
cd ..

# 编译 gdbm
curl -fSLO https://ftp.gnu.org/gnu/gdbm/gdbm-1.26.tar.gz
tar -zxf gdbm-1.26.tar.gz
cd gdbm-1.26
./configure \
    --prefix=/opt/deps \
    --enable-libgdbm-compat \
    --without-readline
make -j$(nproc)
make install
cd ..
cd /opt/deps/include
ln -s ndbm.h gdbm-ndbm.h
cd - >/dev/null

# 编译 sqlite
curl -fSLO https://sqlite.org/2026/sqlite-autoconf-3510200.tar.gz
tar -zxf sqlite-autoconf-3510200.tar.gz
cd sqlite-autoconf-3510200
./configure --prefix=/opt/deps --disable-readline
make -j$(nproc)
make install
cd ..

# 编 python 本体
curl -fSLO https://www.python.org/ftp/python/3.14.2/Python-3.14.2.tgz
tar -zxf Python-3.14.2.tgz
cd Python-3.14.2
# 强制走 aarch64-linux-musl 逻辑，让它能复用 musl 的 pip 包
sed -i 's|PLATFORM_TRIPLET="${PLATFORM_TRIPLET#PLATFORM_TRIPLET=}"|PLATFORM_TRIPLET="aarch64-linux-musl"|g' configure
sed -i 's|MULTIARCH=$($CC --print-multiarch 2>/dev/null)|MULTIARCH="aarch64-linux-musl"|g' configure
sed -i '/def get_platform():/a \    return "linux-aarch64"' Lib/sysconfig/__init__.py
sed -i '/def system():/a \    return "Linux"' Lib/platform.py
echo "PLATFORM_TRIPLET=aarch64-linux-musl" > Misc/platform_triplet.c
./configure \
    --build=aarch64-linux-musl \
    --host=aarch64-linux-musl \
    --prefix=/opt/python-3.14.2-ohos-arm64 \
    --with-openssl=/opt/deps \
    --disable-ipv6 \
    --with-readline=readline \
    --with-dbmliborder=gdbm \
    LDFLAGS="-L/opt/deps/lib -Wl,-rpath,'\$\$ORIGIN/../lib' -Wl,-rpath,'\$\$ORIGIN/../../../lib'"
# 强制禁用那些既用不上、又影响编译的特性
sed -i '/HAVE_LINUX_NETFILTER_IPV4_H/d' pyconfig.h
sed -i '/HAVE_LINUX_CAN/d' pyconfig.h
make -j$(nproc)
make install
cp /opt/deps/lib/*so* /opt/python-3.14.2-ohos-arm64/lib
cd ..

# 对这几个脚本做一点小改造，让它们能够做到 “portable”，在任意安装路径下都能正常使用。
cd /opt/python-3.14.2-ohos-arm64/bin
printf '#!/bin/sh\nexec "$(dirname "$(readlink -f "$0")")"/python3.14 -m pip "$@"\n' > pip3
printf '#!/bin/sh\nexec "$(dirname "$(readlink -f "$0")")"/python3.14 -m pip "$@"\n' > pip3.14
printf '#!/bin/sh\nexec "$(dirname "$(readlink -f "$0")")"/python3.14 -m pydoc "$@"\n' > pydoc3.14
cd - >/dev/null

# 这个 python 不支持图形界面，idle 无法正常使用，直接删掉 idle 命令
rm /opt/python-3.14.2-ohos-arm64/bin/idle*

# 履行开源义务，把使用的开源软件的 license 全部聚合起来放到制品中
cat <<EOF > /opt/python-3.14.2-ohos-arm64/licenses.txt
This document describes the licenses of all software distributed with the
bundled application.
==========================================================================

python
=============
$(cat Python-3.14.2/LICENSE)

openssl
=============
==license==
$(cat openssl-3.3.4/LICENSE.txt)
==authors==
$(cat openssl-3.3.4/AUTHORS.md)

zlib
=============
$(cat zlib-1.3.1/LICENSE)

gettext
=============
==license==
$(cat gettext-1.0/COPYING)
==authors==
$(cat gettext-1.0/AUTHORS)

libffi
=============
$(cat libffi-3.5.2/LICENSE)

util-linux
=============
==license==
$(cat util-linux-2.41.3/COPYING)
==authors==
$(cat util-linux-2.41.3/AUTHORS)

xz
=============
==license==
$(cat xz-5.8.1/COPYING)
==authors==
$(cat xz-5.8.1/AUTHORS)

bzip2
=============
$(cat bzip2-1.0.8/LICENSE)

zstd
=============
$(cat zstd-1.5.7/COPYING)

ncurses
=============
==license==
$(cat ncurses-6.5/COPYING)
==authors==
$(cat ncurses-6.5/AUTHORS)

readline
=============
==license==
$(cat readline-8.3/COPYING)

gdbm
=============
==license==
$(cat gdbm-1.26/COPYING)
==authors==
$(cat gdbm-1.26/AUTHORS)

sqlite
=============
==license==
$(sed -n '1,10p' sqlite-autoconf-3510200/sqlite3.h)
EOF

# 打包最终产物。
# 手动通过管道操作来进行压缩是为了规避 toybox 的 gzip 命令的缺陷。
# 如果直接 tar -zcf 打包（调用的是 /bin 目录下的 gzip），压缩包体积有 300MB；如果这样打（调用的是 busybox 的 gzip），压缩包体积只有 100MB。
cp -r /opt/python-3.14.2-ohos-arm64 ./
busybox tar -cf - python-3.14.2-ohos-arm64 | busybox gzip > python-3.14.2-ohos-arm64.tar.gz 

# 这一步是针对手动构建场景做优化。
# 在 docker run --rm -it 的用法下，有可能文件还没落盘，容器就已经退出并被删除，从而导致压缩文件损坏。
# 使用 sync 命令强制让文件落盘，可以避免那种情况的发生。
sync
