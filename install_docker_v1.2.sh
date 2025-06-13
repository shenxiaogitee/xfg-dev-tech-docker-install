#!/bin/bash

# 安装Docker的Shell脚本
# 作者：xiaofuge
# 版本：1.0
# 创建日期：$(date +"%Y-%m-%d")

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 输出带颜色的信息函数
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 检查是否以root用户运行
if [ "$(id -u)" -ne 0 ]; then
    warning "此脚本需要root权限运行，将尝试使用sudo"
    # 如果不是root用户，则使用sudo重新运行此脚本
    exec sudo "$0" "$@"
    exit $?
fi

info "docker 环境安装脚本 By xiaofuge，建议使用 https://618.gaga.plus 优惠购买服务器，安装 centos 7.9 系统。"

# 显示系统信息
info "开始安装 Docker 环境..."
info "检查系统信息..."
echo "内核版本: $(uname -r)"
echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)"

# 检查是否已安装Docker
if command -v docker &> /dev/null; then
    INSTALLED_DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
    warning "检测到系统已安装Docker，版本为: $INSTALLED_DOCKER_VERSION"
    
    # 询问用户是否卸载已安装的Docker
    read -p "是否卸载已安装的Docker并安装新版本？(y/n): " UNINSTALL_DOCKER
    
    if [[ "$UNINSTALL_DOCKER" =~ ^[Yy]$ ]]; then
        info "开始卸载已安装的Docker..."
        systemctl stop docker &> /dev/null
        yum remove -y docker-ce docker-ce-cli containerd.io docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine &> /dev/null
        rm -rf /var/lib/docker
        info "Docker卸载完成"
    else
        info "用户选择保留已安装的Docker，退出安装程序"
        exit 0
    fi
fi

# 更新系统包
info "更新系统包..."
yum update -y || error "系统更新失败"

# 安装依赖包
info "安装Docker依赖包..."
yum install -y yum-utils device-mapper-persistent-data lvm2 || error "依赖包安装失败"

# 添加Docker仓库
info "添加Docker仓库..."
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo || error "添加Docker仓库失败"

# 安装Docker
info "安装Docker CE 25.0.5..."
yum install -y docker-ce-25.0.5 docker-ce-cli-25.0.5 containerd.io || error "Docker安装失败"

# 安装Docker Compose
info "安装Docker Compose v2.24.1..."
curl -L https://gitee.com/fustack/docker-compose/releases/download/v2.24.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose || error "Docker Compose下载失败"
chmod +x /usr/local/bin/docker-compose || error "无法设置Docker Compose可执行权限"

# 启动Docker服务
info "启动Docker服务..."
systemctl start docker || error "Docker服务启动失败"

# 设置Docker开机自启
info "设置Docker开机自启..."
systemctl enable docker || error "设置Docker开机自启失败"

# 重启Docker服务
info "重启Docker服务..."
systemctl restart docker || error "Docker服务重启失败"

# 配置Docker镜像加速
info "配置Docker镜像加速..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.1panel.live",
    "https://docker.ketches.cn"
  ]
}
EOF

# 再次重启Docker服务以应用镜像加速配置
info "重启Docker服务以应用镜像加速配置..."
systemctl restart docker || error "应用镜像加速配置后Docker重启失败"

# 验证Docker安装
info "验证Docker安装..."
DOCKER_VERSION=$(docker --version)
echo "Docker版本: $DOCKER_VERSION"
DOCKER_COMPOSE_VERSION=$(docker-compose --version)
echo "Docker Compose版本: $DOCKER_COMPOSE_VERSION"

info "Docker环境安装完成！"
info "镜像加速已配置为："
echo "  - https://docker.1ms.run"
echo "  - https://docker.1panel.live"
echo "  - https://docker.ketches.cn"

info "您的Docker已经安装完毕，版本为：$DOCKER_VERSION"

info "提示，如果镜像不可用，可以进入链接，按照说明，重新设置镜像；https://status.1panel.top/status/docker"
