# ohos-python

本项目为 OpenHarmony 平台编译了 python，并发布预构建包。

## 获取软件包

前往 [release 页面](https://github.com/Harmonybrew/ohos-python/releases) 获取。

## 用法
**1\. 在鸿蒙 PC 中使用**

因系统安全规格限制等原因，暂不支持通过“解压 + 配 PATH” 的方式使用这个软件包。

你可以尝试将 tar 包打成 hnp 包再使用，详情请参考 [DevBox](https://gitcode.com/OpenHarmonyPCDeveloper/devbox) 的方案。

**2\. 在鸿蒙开发板中使用**

用 hdc 把它推到设备上，然后以“解压 + 配 PATH” 的方式使用。

示例：
```sh
hdc file send python-3.14.2-ohos-arm64.tar.gz /data
hdc shell

cd /data
tar -zxf python-3.14.2-ohos-arm64.tar.gz
export PATH=$PATH:/data/python-3.14.2-ohos-arm64/bin

# 现在可以使用 python3 命令了
```

**3\. 在 [鸿蒙容器](https://github.com/hqzing/docker-mini-openharmony) 中使用**

在容器中用 curl 下载这个软件包，然后以“解压 + 配 PATH” 的方式使用。

示例：
```sh
docker run -itd --name=ohos ghcr.io/hqzing/docker-mini-openharmony:latest
docker exec -it ohos sh

cd /root
curl -L -O https://github.com/Harmonybrew/ohos-python/releases/download/3.14.2/python-3.14.2-ohos-arm64.tar.gz
tar -zxf python-3.14.2-ohos-arm64.tar.gz -C /opt
export PATH=$PATH:/opt/python-3.14.2-ohos-arm64/bin

# 现在可以使用 python3 命令了
```

## 从源码构建

**1\. 手动构建**

这个项目使用本地编译（native compilation，也可以叫本机编译或原生编译）的做法来编译鸿蒙版 python，而不是交叉编译。

需要在 [鸿蒙容器](https://github.com/hqzing/docker-mini-openharmony) 中运行项目里的 build.sh，以实现 python 的本地编译。

示例：
```sh
git clone https://github.com/Harmonybrew/ohos-python.git
cd ohos-python

docker run \
  --rm \
  -it \
  -v "$PWD":/workdir \
  -w /workdir \
  ghcr.io/hqzing/docker-mini-openharmony:latest \
  ./build.sh
```

**2\. 使用流水线构建**

如果你熟悉 GitHub Actions，你可以直接复用项目内的工作流配置，使用 GitHub 的流水线来完成构建。

这种情况下，你使用的是 GitHub 提供的构建机，不需要自己准备构建环境。

只需要这么做，你就可以进行你的个人构建：
1. Fork 本项目，生成个人仓
2. 在个人仓的“Actions”菜单里面启用工作流
3. 在个人仓提交代码或发版本，触发流水线运行

## 常见问题

**1\. 部分 pip 三方库无法正常使用**

本项目并没有对 python 进行任何“鸿蒙适配”处理，仅仅是使用 ohos-sdk 进行了简单的重编译，它的业务逻辑是走 aarch64-linux-musl 平台的业务逻辑，下载的三方库（主要指包含 C 扩展的三方库）也是 aarch64-linux-musl 的三方库。

基于鸿蒙对 Linux 的兼容性，很多三方库是可以正常工作的。但并非所有三方库都能被完美兼容，不可避免会遇到一些不能正常工作的三方库，这个表现是预期之内的。

**2\. 软件包不能做到完全便携**

python 这个软件本身的设计就没有刻意去实现 portable/relocatable，它编出来的制品里面有一些地方硬编码了编译时的 prefix，它会根据这个 prefix 去读取各种文件。如果软件的实际使用位置和 prefix 不一致，就有可能会产生一些预期之外的表现。

在基础的使用场景下，这个问题不会暴露出来，即使软件的实际使用位置和 prefix 不一致，我们也能正常使用 python3 和 pip3 等命令。但在深度的使用场景下就很容易遇到这方面的问题了。

如果你遇到了这方面的问题，有两种处理方案：
1. 将软件包放置到 prefix 目录下使用。本项目编包的时候设置的 prefix 是 /opt/python-3.14.2-ohos-arm64。
2. 自己重新编一个包，将 prefix 设置成你期望的安装路径。

**3\. 交互式解释器表现异常**

本项目在编译 python 的时候没有把 readline 和 ncurses 编进去（因为在静态链接的场景下遇到了难以解决的问题），所以交互式解释器无法正常使用，例如上下左右之类的键盘按键可能会无响应。
