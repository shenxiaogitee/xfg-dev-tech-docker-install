#!/bin/bash

# JDK 1.8 安装脚本 - 增强版
# 适用于 CentOS 7.9 及其他 Linux 发行版
# 作者: 小傅哥
# 版本: 2.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 配置参数
JDK_VERSION="1.8.0_202"
JDK_PACKAGE="jdk-8u202-linux-x64.tar.gz"
JDK_DOWNLOAD_URL="https://drive.weixin.qq.com/s?k=ACMA4AfQABUsJlf2xB"
DEFAULT_INSTALL_DIR="/usr/local/java"
DEFAULT_SOURCE_DIR="/tmp"
PROFILE_FILE="/etc/profile"
BASHRC_FILE="/etc/bashrc"

# 解析命令行参数
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
SOURCE_DIR="$DEFAULT_SOURCE_DIR"
SILENT_MODE=false
FORCE_INSTALL=false
SKIP_DOWNLOAD=false
CUSTOM_PACKAGE_PATH=""

usage() {
    cat << EOF
使用方法: $0 [选项]

选项:
  -d, --install-dir DIR     指定JDK安装目录 (默认: $DEFAULT_INSTALL_DIR)
  -s, --source-dir DIR      指定JDK包下载/存放目录 (默认: $DEFAULT_SOURCE_DIR)
  -p, --package-path PATH   指定JDK包的完整路径 (跳过下载)
  -f, --force              强制安装，覆盖已存在的JDK
  -q, --quiet              静默模式，减少输出
  --skip-download          跳过下载，使用本地包
  -h, --help               显示此帮助信息

示例:
  $0                                    # 默认安装
  $0 -d /opt/java -s /home/user        # 自定义目录
  $0 -p /path/to/jdk-package.tar.gz    # 使用本地包
  $0 -f -q                             # 强制静默安装
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -s|--source-dir)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -p|--package-path)
            CUSTOM_PACKAGE_PATH="$2"
            SKIP_DOWNLOAD=true
            shift 2
            ;;
        -f|--force)
            FORCE_INSTALL=true
            shift
            ;;
        -q|--quiet)
            SILENT_MODE=true
            shift
            ;;
        --skip-download)
            SKIP_DOWNLOAD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            usage
            exit 1
            ;;
    esac
done

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检测系统信息
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    [[ $SILENT_MODE == false ]] && log_info "检测到系统: $OS $VER"
}

# 检查已安装的Java
check_existing_java() {
    if command -v java >/dev/null 2>&1; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
        log_warning "检测到已安装的Java版本: $JAVA_VERSION"
        
        if [[ $FORCE_INSTALL == false ]]; then
            read -p "是否继续安装? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "安装已取消"
                exit 0
            fi
        fi
    fi
}

# 安装依赖包
install_dependencies() {
    [[ $SILENT_MODE == false ]] && log_info "检查并安装依赖包..."
    
    if command -v yum >/dev/null 2>&1; then
        yum update -y >/dev/null 2>&1 || true
        yum install -y wget curl tar gzip >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update >/dev/null 2>&1 || true
        apt-get install -y wget curl tar gzip >/dev/null 2>&1 || true
    fi
}

# 下载JDK包
download_jdk() {
    if [[ $SKIP_DOWNLOAD == true ]]; then
        [[ $SILENT_MODE == false ]] && log_info "跳过下载步骤"
        return 0
    fi
    
    local package_path="$SOURCE_DIR/$JDK_PACKAGE"
    
    # 检查是否已存在
    if [[ -f "$package_path" ]]; then
        [[ $SILENT_MODE == false ]] && log_info "JDK包已存在: $package_path"
        return 0
    fi
    
    [[ $SILENT_MODE == false ]] && log_info "开始下载JDK包..."
    [[ $SILENT_MODE == false ]] && log_warning "请手动从以下地址下载JDK包: $JDK_DOWNLOAD_URL"
    [[ $SILENT_MODE == false ]] && log_info "下载完成后，请将文件放置到: $package_path"
    
    # 等待用户下载
    while [[ ! -f "$package_path" ]]; do
        read -p "下载完成后按回车继续，或输入 'q' 退出: " -r
        if [[ $REPLY == "q" || $REPLY == "Q" ]]; then
            log_info "安装已取消"
            exit 0
        fi
    done
    
    log_success "JDK包准备完成"
}

# 验证JDK包
validate_package() {
    local package_path
    
    if [[ -n "$CUSTOM_PACKAGE_PATH" ]]; then
        package_path="$CUSTOM_PACKAGE_PATH"
    else
        package_path="$SOURCE_DIR/$JDK_PACKAGE"
    fi
    
    if [[ ! -f "$package_path" ]]; then
        log_error "JDK包不存在: $package_path"
        exit 1
    fi
    
    # 验证包格式
    if ! tar -tzf "$package_path" >/dev/null 2>&1; then
        log_error "JDK包格式无效或已损坏: $package_path"
        exit 1
    fi
    
    [[ $SILENT_MODE == false ]] && log_success "JDK包验证通过"
    echo "$package_path"
}

# 安装JDK
install_jdk() {
    local package_path=$1
    
    [[ $SILENT_MODE == false ]] && log_info "开始安装JDK到: $INSTALL_DIR"
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 备份现有安装
    if [[ -d "$INSTALL_DIR" ]] && [[ $(ls -A "$INSTALL_DIR" 2>/dev/null) ]]; then
        if [[ $FORCE_INSTALL == true ]]; then
            [[ $SILENT_MODE == false ]] && log_warning "清理现有安装目录"
            rm -rf "$INSTALL_DIR"/*
        else
            log_error "安装目录不为空: $INSTALL_DIR (使用 -f 强制覆盖)"
            exit 1
        fi
    fi
    
    # 解压JDK
    [[ $SILENT_MODE == false ]] && log_info "解压JDK包..."
    if [[ $SILENT_MODE == true ]]; then
        tar -xzf "$package_path" -C "$INSTALL_DIR" --strip-components=1 >/dev/null 2>&1
    else
        tar -xzf "$package_path" -C "$INSTALL_DIR" --strip-components=1
    fi
    
    # 验证安装
    if [[ ! -f "$INSTALL_DIR/bin/java" ]]; then
        log_error "JDK安装失败，java可执行文件不存在"
        exit 1
    fi
    
    log_success "JDK解压完成"
}

# 配置环境变量
configure_environment() {
    [[ $SILENT_MODE == false ]] && log_info "配置环境变量..."
    
    # 备份配置文件
    if [[ -f "$PROFILE_FILE" ]]; then
        cp "$PROFILE_FILE" "$PROFILE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 移除旧的Java配置
    sed -i '/JAVA_HOME/d' "$PROFILE_FILE" 2>/dev/null || true
    sed -i '/CLASSPATH/d' "$PROFILE_FILE" 2>/dev/null || true
    
    # 添加新的Java配置
    cat >> "$PROFILE_FILE" << EOF

# Java Environment - Added by JDK installer
export JAVA_HOME=$INSTALL_DIR
export PATH=\$JAVA_HOME/bin:\$PATH
export CLASSPATH=\$JAVA_HOME/jre/lib/ext:\$JAVA_HOME/lib/tools.jar
EOF
    
    # 同时配置bashrc（某些系统需要）
    if [[ -f "$BASHRC_FILE" ]]; then
        sed -i '/JAVA_HOME/d' "$BASHRC_FILE" 2>/dev/null || true
        sed -i '/CLASSPATH/d' "$BASHRC_FILE" 2>/dev/null || true
        
        cat >> "$BASHRC_FILE" << EOF

# Java Environment - Added by JDK installer
export JAVA_HOME=$INSTALL_DIR
export PATH=\$JAVA_HOME/bin:\$PATH
export CLASSPATH=\$JAVA_HOME/jre/lib/ext:\$JAVA_HOME/lib/tools.jar
EOF
    fi
    
    log_success "环境变量配置完成"
}

# 验证安装
verify_installation() {
    [[ $SILENT_MODE == false ]] && log_info "验证安装..."
    
    # 重新加载环境变量
    source "$PROFILE_FILE" 2>/dev/null || true
    export JAVA_HOME="$INSTALL_DIR"
    export PATH="$JAVA_HOME/bin:$PATH"
    
    # 检查Java版本
    if "$INSTALL_DIR/bin/java" -version >/dev/null 2>&1; then
        local java_version=$("$INSTALL_DIR/bin/java" -version 2>&1 | head -n 1)
        log_success "Java安装成功!"
        [[ $SILENT_MODE == false ]] && echo "$java_version"
        
        # 检查javac
        if "$INSTALL_DIR/bin/javac" -version >/dev/null 2>&1; then
            local javac_version=$("$INSTALL_DIR/bin/javac" -version 2>&1)
            [[ $SILENT_MODE == false ]] && echo "$javac_version"
        fi
    else
        log_error "Java安装验证失败"
        exit 1
    fi
}

# 显示安装信息
show_installation_info() {
    if [[ $SILENT_MODE == false ]]; then
        cat << EOF

${GREEN}=== JDK 安装完成 ===${NC}
安装路径: $INSTALL_DIR
Java版本: $("$INSTALL_DIR/bin/java" -version 2>&1 | head -n 1)

${YELLOW}注意事项:${NC}
1. 请重新登录或执行 'source $PROFILE_FILE' 使环境变量生效
2. 验证安装: java -version
3. 配置文件备份在: $PROFILE_FILE.backup.*

${BLUE}环境变量:${NC}
JAVA_HOME=$INSTALL_DIR
PATH=\$JAVA_HOME/bin:\$PATH
CLASSPATH=\$JAVA_HOME/jre/lib/ext:\$JAVA_HOME/lib/tools.jar
EOF
    fi
}

# 清理临时文件
cleanup() {
    if [[ $SKIP_DOWNLOAD == false && -f "$SOURCE_DIR/$JDK_PACKAGE" ]]; then
        read -p "是否删除下载的JDK包? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$SOURCE_DIR/$JDK_PACKAGE"
            log_info "临时文件已清理"
        fi
    fi
}

# 主函数
main() {
    [[ $SILENT_MODE == false ]] && log_info "开始JDK 1.8 安装程序..."
    
    check_root
    detect_system
    check_existing_java
    install_dependencies
    
    # 创建源目录
    mkdir -p "$SOURCE_DIR"
    
    download_jdk
    local package_path=$(validate_package)
    install_jdk "$package_path"
    configure_environment
    verify_installation
    show_installation_info
    
    if [[ $SILENT_MODE == false ]]; then
        cleanup
    fi
    
    log_success "JDK 1.8 安装完成!"
}

# 错误处理
trap 'log_error "安装过程中发生错误，退出码: $?"' ERR

# 执行主函数
main "$@"