#!/bin/bash

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

# 定义本地脚本文件名
LOCAL_SCRIPT_NAME="install_docker.sh"

info "使用本地Docker安装脚本: $LOCAL_SCRIPT_NAME"

# 检查本地脚本是否存在
if [ ! -f "$LOCAL_SCRIPT_NAME" ]; then
    error "本地脚本文件 $LOCAL_SCRIPT_NAME 不存在"
fi

# 设置可执行权限
info "设置可执行权限..."
chmod +x "$LOCAL_SCRIPT_NAME"

# 执行安装脚本
info "开始执行Docker安装脚本..."
info "注意：安装过程可能需要root权限，如果需要会自动请求"
echo "-----------------------------------------------------------"
./$LOCAL_SCRIPT_NAME

# 检查安装脚本的退出状态
if [ $? -eq 0 ]; then
    info "Docker安装脚本执行完成"
    
    # 询问用户是否安装Portainer
    read -p "是否安装Portainer容器管理界面？(y/n): " INSTALL_PORTAINER
    
    if [[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]]; then
        info "开始安装Portainer..."
        docker run -d --restart=always --name portainer -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer
        
        if [ $? -eq 0 ]; then
            info "Portainer安装成功！"
            warning "重要提示：请确保您的云服务器已开放9000端口！"
            echo "-----------------------------------------------------------"
            echo "Portainer访问方式："
            echo "1. 通过公网访问：http://您的服务器公网IP:9000"
            echo "2. 首次访问需要设置管理员账号和密码"
            echo "3. 登录后即可通过Web界面管理Docker容器"
            echo "-----------------------------------------------------------"
            info "您可以使用Portainer来方便地管理Docker容器、镜像、网络和卷等资源"
        else
            warning "Portainer安装失败，请手动安装或检查Docker状态"
        fi
    else
        info "用户选择不安装Portainer"
    fi
else
    error "Docker安装脚本执行失败，请查看上面的错误信息"
fi
