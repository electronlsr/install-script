[English](README.md)

<div align="center">
<a href="https://github.com/trojanpanel"><img src="https://github.com/trojanpanel/install-script/assets/46235235/bfc4f96a-e8b6-499d-956f-a9c212059294" alt="Trojan Panel" width="150" /></a>
<h1>Trojan Panel</h1>
<p>
<a href="https://github.com/trojanpanel/install-script/stargazers"><img src="https://img.shields.io/github/stars/trojanpanel/install-script" alt="GitHub stars"></a>
<a href="https://github.com/trojanpanel/install-script/forks"><img src="https://img.shields.io/github/forks/trojanpanel/install-script" alt="GitHub forks"></a>
<a href="https://github.com/trojanpanel/install-script/issues"><img src="https://img.shields.io/github/issues/trojanpanel/install-script" alt="GitHub issues"></a>
<a href="https://github.com/electronlsr/install-script/blob/main/images.lock.json"><img src="https://img.shields.io/badge/release-3.0.0-blue" alt="GitHub release"></a>
<a href="https://hub.docker.com/r/jonssonyan/trojan-panel"><img src="https://img.shields.io/docker/pulls/jonssonyan/trojan-panel" alt="Docker pulls"></a>
</p>
<h3>支持Xray/Trojan-Go/Hysteria/NaiveProxy的多用户Web管理面板</h3>
<a href="https://github.com/trojanpanel/install-script/assets/46235235/7ac2bba1-b442-442d-b48e-b52f92e0bad8"><img src="https://github.com/trojanpanel/install-script/assets/46235235/7ac2bba1-b442-442d-b48e-b52f92e0bad8" alt="Trojan Panel"/></a>
</div>

## electronlsr 3.0.0 版本

本分支使用 `ghcr.io/electronlsr/trojan-panel`、`trojan-panel-core`、`trojan-panel-ui` 的固定版本镜像。历史单机脚本和 archive 脚本仍是旧版工具，不用于本次升级。

### 3.0.0 的 Trojan 兼容修复

Core 3.0.0 恢复对旧 Trojan 节点隐藏 `xray_flow` 值（例如 `xtls-rprx-vision`）的兼容，沿用现有节点参数和数据，不新增数据库迁移。要先更新受影响的 Core 节点，选择 **10：Safe upgrade Trojan Panel Core**，再输入 `y`；选择 **26** 可继续把本机其他已安装组件升级到 3.0.0，镜像已匹配的组件会跳过。

### 已有服务器请选择菜单 26

使用 root 运行下方联机脚本，然后选择 **26：SAFE UPGRADE all installed Panel components**。只有 Core 的节点服务器只升级 Core；也可用菜单 8/9/10 分别升级前端/后端/Core。**不要卸载重装，也不要对现有脚本安装运行 Compose 或选择全新安装菜单来升级。**

- 支持官方后端/Core v2.3.0、v2.3.1，前端 v2.3.0，以及本分支基于这些版本的旧构建和 v3.0.0。更早或未知数据库版本会在替换前停止，不自动执行历史 SQL 迁移。
- 需要本机 Docker Engine Unix socket、Python 3.6+、GNU tar，以及容纳新旧镜像和挂载数据备份的空间。主要适用于官方脚本的 host 网络部署。升级不会安装系统软件、改动 Docker/防火墙、替换 MariaDB/Redis 或清空 Redis。
- 先拉取所有选中镜像，再中断服务。按镜像 ID 判断是否需要升级，因此官方程序版本号相同也能升级到本分支。
- 保留容器名称、实际环境变量（含密码）、挂载、网络及运行参数。未自定义的镜像启动命令随新镜像更新，自定义启动命令保留。
- 后端升级前通过已安装的 `mariadb-dump`/`mysqldump`，或现有 host 网络的 `trojan-panel-mariadb` 容器，生成 `trojan_panel_db` 逻辑备份。备份失败则停止。远程数据库且无可用客户端时，先安装匹配的数据库备份客户端。
- 选中的应用容器停止后，备份挂载数据、配置、证书和 Core 的 SQLite。备份及 `RECOVERY.txt` 位于 `/var/backups/trojan-panel/<时间戳>/`，仅 root 可读。备份含密码/私钥，务必安全保存一份到服务器之外。只升级节点时，不会备份远端 MySQL，请先在后端服务器备份。
- 保留旧镜像和 `.pre-<时间戳>` 旧容器，并关闭旧容器自动启动。替换/启动失败时尝试恢复原容器。**容器回退不会撤销 MySQL、SQLite 或配置写入。** 恢复数据库前需停止所有写入者（含其他服务器上的 Core）；恢复旧快照会丢失之后的写入，因此不会自动恢复数据库。
- 普通终端断线/中断会触发恢复；强制 SIGKILL、主机断电或 Docker 不可用时，可能需要按保存的记录手工恢复，无法保证自动回退。
- 先升级一台，验证登录、订阅和节点真实流量，再逐台升级。启动检查不等于完整代理流量测试。确认无需回退之前，不要清理保留的旧容器和旧镜像。

全新安装也使用同一固定版本镜像。三个应用镜像支持下列架构；上游数据库及反向代理镜像有各自的平台限制。全新安装保留上游的部署设置，本次不进行额外的安全配置改造。

精确的多架构镜像摘要、源码提交和成功发布流程见 [images.lock.json](images.lock.json)。安装脚本的 CI 还会对每个架构进行匿名拉取。

### 脚本检查

```shell
bash -n install_script.sh
python3 -m unittest discover -s tests -v
bash tests/test_installer.sh
```

以上是静态和模拟 Docker 测试，不会以 root 执行安装脚本或连接现有部署。`scripts/safe_upgrade.py` 内嵌于单文件脚本，修改后运行 `python3 scripts/embed_upgrade.py` 并重新测试。

## 特点

- 极速搭建: 一键安装脚本，降低部署门槛，快速搭建系统
- 国际化: 系统语言支持中文/English/한국인/فارسی
- 多代理支持: 节点类型支持Xray/Trojan-Go/Hysteria/NaiveProxy
- 分布式: 前后端分离开发，减少模块之间耦合度，可以自由组合部署在多个服务器
- 功能强大: 支持登录注册/用户管理/节点管理/邮件管理/黑名单管理/自定义伪装网站/系统看板等
- 所见即所得: 支持多节点管理，自动化管理远程节点，自动化申请/续签证书，面板内编辑节点，远程服务实时修改节点配置

## 系统要求

系统: CentOS 7+ / Ubuntu 18+ / Debian 10+

CPU: linux/amd64 / linux/arm/v6 / linux/arm/v7 / linux/arm64 / linux/s390x / linux/ppc64le / linux/386

内存: ≥ 1G

## 安装

- 联机（推荐）

    ```shell
    curl -fsSL https://raw.githubusercontent.com/electronlsr/install-script/main/install_script.sh -o /tmp/trojan-panel-install.sh && bash /tmp/trojan-panel-install.sh
    ```

- 单机

    ```shell
    source <(curl -L https://github.com/trojanpanel/install-script/raw/main/install_script_standalone.sh)
    ```

- [安装旧版本](README_ARCHIVE_ZH.md)

## 其他

Telegram Channel: https://t.me/jonssonyan_channel

You can subscribe to my channel on YouTube: https://www.youtube.com/@jonssonyan

## 文档

访问 [https://trojanpanel.github.io](https://trojanpanel.github.io) 查看完整文档

## 更新日志

访问 [https://trojanpanel.github.io/change/change-log.html](https://trojanpanel.github.io/change/change-log.html) 查看完整日志

## 报告缺陷与问题

[Issues](https://github.com/electronlsr/install-script/issues)

## 致谢

- [trojan](https://github.com/trojan-gfw/trojan)
- [trojan-go](https://github.com/p4gefau1t/trojan-go)
- [Xray-core](https://github.com/XTLS/Xray-core)
- [hysteria](https://github.com/HyNetwork/hysteria)
- [naiveproxy](https://github.com/klzgrad/naiveproxy)

## Star随时间变化

[![Stargazers over time](https://starchart.cc/trojanpanel/install-script.svg)](https://github.com/trojanpanel/install-script)
