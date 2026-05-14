#!/bin/sh
set -e

WORKDIR=$(pwd)

# 如果存在旧的目录和文件，就清理掉
# 仅清理工作目录，不清理系统目录，因为默认用户每次使用新的容器进行构建（仓库中的构建指南是这么指导的）
rm -rf *.tar.gz \
    *.tgz \
    deps \
    Python-3.14.5 \
    python-3.14.5-ohos-arm64

# 下载一些命令行工具，并将它们软链接到 bin 目录中
cd /opt
echo "coreutils 9.10
busybox 1.37.0
grep 3.12
gawk 5.3.2
make 4.4.1
tar 1.35
gzip 1.14
perl 5.42.0" >/tmp/tools.txt
while read -r name ver; do
    curl -fLO https://github.com/Harmonybrew/ohos-$name/releases/download/$ver/$name-$ver-ohos-arm64.tar.gz
done </tmp/tools.txt
ls | grep tar.gz$ | xargs -n 1 tar -zxf
rm -rf *.tar.gz
ln -sf $(pwd)/*-ohos-arm64/bin/* /bin/

# 准备 ohos-sdk
curl -fL -o ohos-sdk-full_6.1-Release.tar.gz https://cidownload.openharmony.cn/version/Master_Version/OpenHarmony_6.1.0.31/20260311_020435/version-Master_Version-OpenHarmony_6.1.0.31-20260311_020435-ohos-sdk-full_6.1-Release.tar.gz
tar -zxf ohos-sdk-full_6.1-Release.tar.gz
rm -rf ohos-sdk-full_6.1-Release.tar.gz ohos-sdk/windows ohos-sdk/linux
cd ohos-sdk/ohos
busybox unzip -q native-*.zip
busybox unzip -q toolchains-*.zip
rm -rf *.zip
cd $WORKDIR

# 把 llvm 里面的命令封装一份放到 /bin 目录下，只封装必要的工具。
# 为了照顾 clang （clang 软链接到其他目录使用会找不到 sysroot），
# 对所有命令统一用这种封装的方案，而非软链接。
essential_tools="clang
clang++
clang-cpp
ld.lld
lldb
llvm-addr2line
llvm-ar
llvm-cxxfilt
llvm-nm
llvm-objcopy
llvm-objdump
llvm-ranlib
llvm-readelf
llvm-size
llvm-strings
llvm-strip"
for executable in $essential_tools; do
    cat <<EOF > /bin/$executable
#!/bin/sh
exec /opt/ohos-sdk/ohos/native/llvm/bin/$executable "\$@"
EOF
    chmod 0755 /bin/$executable
done

# 把 llvm 软链接成 cc、gcc 等命令
cd /bin
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

export CFLAGS="-fPIC"
export CPPFLAGS="-I/opt/deps/include -D__MUSL__"
export LDFLAGS="-L/opt/deps/lib"
export LD_LIBRARY_PATH="/opt/deps/lib"

mkdir $WORKDIR/deps
cd $WORKDIR/deps

# 编译 openssl
curl -fLO https://github.com/openssl/openssl/releases/download/openssl-3.6.1/openssl-3.6.1.tar.gz
tar -zxf openssl-3.6.1.tar.gz
cd openssl-3.6.1
# 修改证书目录和聚合文件路径，让它能在 OpenHarmony 平台上正确地找到证书
sed -i 's|OPENSSLDIR "/certs"|"/etc/ssl/certs"|' include/internal/common.h
sed -i 's|OPENSSLDIR "/cert.pem"|"/etc/ssl/certs/cacert.pem"|' include/internal/common.h
./Configure --prefix=/opt/deps --openssldir=/etc/ssl no-legacy no-module no-engine linux-aarch64
make -j$(nproc)
make install_dev
cd ..

# 编 zlib
curl -fLO https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
tar -zxf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --prefix=/opt/deps
make -j$(nproc)
make install
cd ..

# 编 gettext
curl -fLO https://ftp.gnu.org/gnu/gettext/gettext-1.0.tar.gz
tar -zxf gettext-1.0.tar.gz
cd gettext-1.0
./configure --prefix=/opt/deps
make -j$(nproc)
make install
cd ..

# 编 libffi
curl -fLO https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz
tar -zxf libffi-3.5.2.tar.gz
cd libffi-3.5.2
./configure --prefix=/opt/deps
make -j$(nproc)
make install
cd ..

# 编 util-linux（libuuid）
curl -fLO https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.41/util-linux-2.41.3.tar.gz
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
curl -fLO https://github.com/tukaani-project/xz/releases/download/v5.8.1/xz-5.8.1.tar.gz
tar -zxf xz-5.8.1.tar.gz
cd xz-5.8.1
./configure --prefix=/opt/deps
make -j$(nproc)
make install
cd ..

# 编 bzip2
curl -fLO https://mirrors.kernel.org/sourceware/bzip2/bzip2-1.0.8.tar.gz
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
curl -fLO https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz
tar -zxf ncurses-6.5.tar.gz
cd ncurses-6.5
./configure \
    --prefix=/opt/deps \
    --enable-termcap \
    --enable-widec \
    --with-shared \
    --with-terminfo-dirs=/opt/python-3.14.5-ohos-arm64/share/terminfo:/data/python-3.14.5-ohos-arm64/share/terminfo \
    --with-fallbacks=xterm,xterm-256color,xterm-color,screen,screen-256color,tmux,tmux-256color,linux,vt100,vt102,ansi
make -j$(nproc)
make install
cp /opt/deps/include/ncursesw/*.h /opt/deps/include
cd ..

# 编译 readline
curl -fLO https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz
tar -zxf readline-8.3.tar.gz
cd readline-8.3
./configure --prefix=/opt/deps --with-curses
make -j$(nproc) SHLIB_LIBS="-lncursesw"
make install
cd ..

# 编译 gdbm
curl -fLO https://ftp.gnu.org/gnu/gdbm/gdbm-1.26.tar.gz
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
curl -fLO https://sqlite.org/2026/sqlite-autoconf-3510200.tar.gz
tar -zxf sqlite-autoconf-3510200.tar.gz
cd sqlite-autoconf-3510200
./configure --prefix=/opt/deps --disable-readline
make -j$(nproc)
make install
cd ..

cd $WORKDIR

# 编 python 本体
curl -fLO https://www.python.org/ftp/python/3.14.5/Python-3.14.5.tgz
tar -zxf Python-3.14.5.tgz
cd Python-3.14.5
# 强制走 aarch64-linux-musl 逻辑，让它能复用 musl 的 pip 包
sed -i 's|PLATFORM_TRIPLET="${PLATFORM_TRIPLET#PLATFORM_TRIPLET=}"|PLATFORM_TRIPLET="aarch64-linux-musl"|g' configure
sed -i 's|MULTIARCH=$($CC --print-multiarch 2>/dev/null)|MULTIARCH="aarch64-linux-musl"|g' configure
sed -i '/def get_platform():/a \    return "linux-aarch64"' Lib/sysconfig/__init__.py
sed -i '/def system():/a \    return "Linux"' Lib/platform.py
echo "PLATFORM_TRIPLET=aarch64-linux-musl" > Misc/platform_triplet.c
./configure \
    --build=aarch64-linux-musl \
    --host=aarch64-linux-musl \
    --prefix=/opt/python-3.14.5-ohos-arm64 \
    --with-openssl=/opt/deps \
    --disable-ipv6 \
    --with-readline=readline \
    --with-dbmliborder=gdbm \
    LDFLAGS="-L/opt/deps/lib -Wl,-rpath,'\$\$ORIGIN/../lib' -Wl,-rpath,'\$\$ORIGIN/../../../lib'"
make -j$(nproc)
make install
cp /opt/deps/lib/*so* /opt/python-3.14.5-ohos-arm64/lib
cd ..

# 对这几个脚本做一点小改造，让它们能够做到 “portable”，在任意安装路径下都能正常使用。
cd /opt/python-3.14.5-ohos-arm64/bin
printf '#!/bin/sh\nexec "$(dirname "$(readlink -f "$0")")"/python3.14 -m pip "$@"\n' > pip3
printf '#!/bin/sh\nexec "$(dirname "$(readlink -f "$0")")"/python3.14 -m pip "$@"\n' > pip3.14
printf '#!/bin/sh\nexec "$(dirname "$(readlink -f "$0")")"/python3.14 -m pydoc "$@"\n' > pydoc3.14
cd - >/dev/null

# 这个 python 不支持图形界面，idle 无法正常使用，直接删掉 idle 命令
rm /opt/python-3.14.5-ohos-arm64/bin/idle*

# 将 terminfo 数据库携带到制品中
cp -r /opt/deps/share/terminfo /opt/python-3.14.5-ohos-arm64/share/

# 进行代码签名
cd /opt/python-3.14.5-ohos-arm64
find . -type f \( -perm -0111 -o -name "*.so*" \) | while read FILE; do
    if file -b "$FILE" | grep -iqE "elf|sharedlib|ELF|shared object"; then
        echo "Signing binary file $FILE"
        ORIG_PERM=$(stat -c %a "$FILE")
        /opt/ohos-sdk/ohos/toolchains/lib/binary-sign-tool sign -inFile "$FILE" -outFile "$FILE" -selfSign 1
        chmod "$ORIG_PERM" "$FILE"
    fi
done
cd $WORKDIR

# 履行开源义务，把使用的开源软件的 license 全部聚合起来放到制品中
cat <<EOF > /opt/python-3.14.5-ohos-arm64/licenses.txt
This document describes the licenses of all software distributed with the
bundled application.
==========================================================================

python
=============
$(cat Python-3.14.5/LICENSE)

openssl
=============
==license==
$(cat deps/openssl-3.6.1/LICENSE.txt)
==authors==
$(cat deps/openssl-3.6.1/AUTHORS.md)

zlib
=============
$(cat deps/zlib-1.3.1/LICENSE)

gettext
=============
==license==
$(cat deps/gettext-1.0/COPYING)
==authors==
$(cat deps/gettext-1.0/AUTHORS)

libffi
=============
$(cat deps/libffi-3.5.2/LICENSE)

util-linux
=============
==license==
$(cat deps/util-linux-2.41.3/COPYING)
==authors==
$(cat deps/util-linux-2.41.3/AUTHORS)

xz
=============
==license==
$(cat deps/xz-5.8.1/COPYING)
==authors==
$(cat deps/xz-5.8.1/AUTHORS)

bzip2
=============
$(cat deps/bzip2-1.0.8/LICENSE)

zstd
=============
$(cat deps/zstd-1.5.7/COPYING)

ncurses
=============
==license==
$(cat deps/ncurses-6.5/COPYING)
==authors==
$(cat deps/ncurses-6.5/AUTHORS)

readline
=============
==license==
$(cat deps/readline-8.3/COPYING)

gdbm
=============
==license==
$(cat deps/gdbm-1.26/COPYING)
==authors==
$(cat deps/gdbm-1.26/AUTHORS)

sqlite
=============
==license==
$(sed -n '1,10p' deps/sqlite-autoconf-3510200/sqlite3.h)
EOF

# 打包最终产物
cp -r /opt/python-3.14.5-ohos-arm64 ./
tar -zcf python-3.14.5-ohos-arm64.tar.gz python-3.14.5-ohos-arm64

# 这一步是针对手动构建场景做优化。
# 在 docker run --rm -it 的用法下，有可能文件还没落盘，容器就已经退出并被删除，从而导致压缩文件损坏。
# 使用 sync 命令强制让文件落盘，可以避免那种情况的发生。
sync
