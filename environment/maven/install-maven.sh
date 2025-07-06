#!/bin/bash

# Maven 安装脚本
# 适用于 CentOS 7.9 及其他 Linux 发行版
# 作者: 小傅哥
# 版本: 1.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检测终端是否支持颜色
if [[ ! -t 1 ]] || [[ "$TERM" == "dumb" ]] || [[ -z "$TERM" ]] || [[ "$TERM" == "unknown" ]]; then
    # 禁用颜色
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

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

# 默认配置参数
DEFAULT_INSTALL_DIR="/usr/local/maven"
DEFAULT_SOURCE_DIR="$(dirname "$0")"
MAVEN_PACKAGE="apache-maven-3.8.8.zip"
MAVEN_VERSION="3.8.8"
PROFILE_FILE="/etc/profile"
BASHRC_FILE="/etc/bashrc"

# 运行时变量
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
SOURCE_DIR="$DEFAULT_SOURCE_DIR"
SILENT_MODE=false
FORCE_INSTALL=false
CUSTOM_PACKAGE_PATH=""

usage() {
    cat << EOF
使用方法: $0 [选项]

选项:
  -d, --install-dir DIR     指定Maven安装目录 (默认: $DEFAULT_INSTALL_DIR)
  -s, --source-dir DIR      指定Maven包存放目录 (默认: $DEFAULT_SOURCE_DIR)
  -p, --package-path PATH   指定Maven包的完整路径
  -f, --force              强制安装，覆盖已存在的Maven
  -q, --quiet              静默模式，减少输出
  -h, --help               显示此帮助信息

示例:
  $0                                    # 默认安装
  $0 -d /opt/maven                     # 自定义安装目录
  $0 -p /path/to/maven-package.zip     # 使用本地包
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

# 检查已安装的Maven
check_existing_maven() {
    if command -v mvn >/dev/null 2>&1; then
        MAVEN_VERSION_CURRENT=$(mvn -version 2>/dev/null | head -n 1 | awk '{print $3}' || echo "未知")
        log_warning "检测到已安装的Maven版本: $MAVEN_VERSION_CURRENT"
        
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

# 检查Java环境
check_java() {
    if ! command -v java >/dev/null 2>&1; then
        log_error "未检测到Java环境，Maven需要Java运行环境"
        log_info "请先安装JDK，然后再安装Maven"
        exit 1
    fi
    
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    [[ $SILENT_MODE == false ]] && log_info "检测到Java版本: $JAVA_VERSION"
}

# 安装依赖包
install_dependencies() {
    [[ $SILENT_MODE == false ]] && log_info "检查并安装依赖包..."
    
    if command -v yum >/dev/null 2>&1; then
        yum update -y >/dev/null 2>&1 || true
        yum install -y unzip >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update >/dev/null 2>&1 || true
        apt-get install -y unzip >/dev/null 2>&1 || true
    fi
}

# 验证Maven包
validate_package() {
    local package_path
    
    if [[ -n "$CUSTOM_PACKAGE_PATH" ]]; then
        package_path="$CUSTOM_PACKAGE_PATH"
    else
        package_path="$SOURCE_DIR/$MAVEN_PACKAGE"
    fi
    
    if [[ ! -f "$package_path" ]]; then
        # 获取脚本的完整绝对路径
        local script_dir=$(cd "$(dirname "$0")" && pwd)
        
        log_error "Maven包不存在: $package_path"
        log_info "请下载Maven安装包并放置到正确位置:"
        log_info "下载地址: https://drive.weixin.qq.com/s?k=ACMA4AfQABUI0aRnml"
        log_info "下载完成后，请将 apache-maven-3.8.8.zip 文件放置到: $script_dir/"
        exit 1
    fi
    
    # 验证包格式
    if ! unzip -t "$package_path" >/dev/null 2>&1; then
        log_error "Maven包格式无效或已损坏: $package_path"
        log_info "请重新下载Maven安装包:"
        log_info "下载地址: https://drive.weixin.qq.com/s?k=ACMA4AfQABUI0aRnml"
        exit 1
    fi
    
    [[ $SILENT_MODE == false ]] && log_success "Maven包验证通过" >&2
    echo "$package_path"
}

# 安装Maven
install_maven() {
    local package_path=$1
    
    [[ $SILENT_MODE == false ]] && log_info "开始安装Maven $MAVEN_VERSION 到: $INSTALL_DIR"
    
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
    
    # 解压Maven
    [[ $SILENT_MODE == false ]] && log_info "解压Maven包..."
    if [[ $SILENT_MODE == true ]]; then
        unzip -q "$package_path" -d "$INSTALL_DIR" >/dev/null 2>&1
    else
        unzip -q "$package_path" -d "$INSTALL_DIR"
    fi
    
    # 移动文件到正确位置（去掉版本号目录）
    local maven_extracted_dir=$(find "$INSTALL_DIR" -maxdepth 1 -name "apache-maven-*" -type d | head -n 1)
    if [[ -n "$maven_extracted_dir" ]]; then
        # 使用 shopt 启用 dotglob 以包含隐藏文件
        shopt -s dotglob
        # 移动所有文件（包括隐藏文件）
        mv "$maven_extracted_dir"/* "$INSTALL_DIR"/ 2>/dev/null || true
        # 恢复 dotglob 设置
        shopt -u dotglob
        # 强制删除空目录
        rm -rf "$maven_extracted_dir"
    fi
    
    # 验证安装
    if [[ ! -f "$INSTALL_DIR/bin/mvn" ]]; then
        log_error "Maven安装失败，mvn可执行文件不存在"
        exit 1
    fi
    
    log_success "Maven解压完成"
}

# 配置环境变量
configure_environment() {
    [[ $SILENT_MODE == false ]] && log_info "配置环境变量..."
    
    # 备份配置文件
    if [[ -f "$PROFILE_FILE" ]]; then
        cp "$PROFILE_FILE" "$PROFILE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 移除旧的Maven配置
    sed -i '/MAVEN_HOME/d' "$PROFILE_FILE" 2>/dev/null || true
    sed -i '/M2_HOME/d' "$PROFILE_FILE" 2>/dev/null || true
    
    # 添加新的Maven配置
    cat >> "$PROFILE_FILE" << EOF

# Maven Environment - Added by Maven installer
export MAVEN_HOME=$INSTALL_DIR
export M2_HOME=$INSTALL_DIR
export PATH=\$MAVEN_HOME/bin:\$PATH
EOF
    
    # 同时配置bashrc（某些系统需要）
    if [[ -f "$BASHRC_FILE" ]]; then
        sed -i '/MAVEN_HOME/d' "$BASHRC_FILE" 2>/dev/null || true
        sed -i '/M2_HOME/d' "$BASHRC_FILE" 2>/dev/null || true
        
        cat >> "$BASHRC_FILE" << EOF

# Maven Environment - Added by Maven installer
export MAVEN_HOME=$INSTALL_DIR
export M2_HOME=$INSTALL_DIR
export PATH=\$MAVEN_HOME/bin:\$PATH
EOF
    fi
    
    # 立即在当前会话中生效环境变量
    export MAVEN_HOME="$INSTALL_DIR"
    export M2_HOME="$INSTALL_DIR"
    export PATH="$MAVEN_HOME/bin:$PATH"
    
    # 重新加载配置文件
    source "$PROFILE_FILE" 2>/dev/null || true
    
    log_success "环境变量配置完成"
    [[ $SILENT_MODE == false ]] && log_info "环境变量已在当前会话中生效"
}

# 验证安装
verify_installation() {
    [[ $SILENT_MODE == false ]] && log_info "验证安装..."
    
    # 重新加载环境变量
    source "$PROFILE_FILE" 2>/dev/null || true
    export MAVEN_HOME="$INSTALL_DIR"
    export M2_HOME="$INSTALL_DIR"
    export PATH="$MAVEN_HOME/bin:$PATH"
    
    # 检查Maven版本
    if "$INSTALL_DIR/bin/mvn" -version >/dev/null 2>&1; then
        local maven_version=$("$INSTALL_DIR/bin/mvn" -version 2>&1 | head -n 1)
        log_success "Maven安装成功!"
        [[ $SILENT_MODE == false ]] && echo "$maven_version"
    else
        log_error "Maven安装验证失败"
        exit 1
    fi
}

# 显示安装信息
show_installation_info() {
    if [[ $SILENT_MODE == false ]]; then
        # 检测终端是否支持颜色，如果不支持则使用纯文本
        if [[ ! -t 1 ]] || [[ "$TERM" == "dumb" ]] || [[ -z "$TERM" ]] || [[ "$TERM" == "unknown" ]]; then
            cat << EOF

=== Maven $MAVEN_VERSION 安装完成 ===
安装路径: $INSTALL_DIR
Maven版本: $("$INSTALL_DIR/bin/mvn" -version 2>&1 | head -n 1)

注意事项:
1. 环境变量已在当前会话中生效，可直接使用 mvn 命令
2. 新开终端会话会自动加载环境变量
3. 验证安装: mvn -version
4. 如果 mvn 命令不生效，请执行: source /etc/profile
5. 配置文件备份在: $PROFILE_FILE.backup.*

环境变量:
MAVEN_HOME=$INSTALL_DIR
M2_HOME=$INSTALL_DIR
PATH=\$MAVEN_HOME/bin:\$PATH
EOF
        else
            cat << EOF

${GREEN}=== Maven $MAVEN_VERSION 安装完成 ===${NC}
安装路径: $INSTALL_DIR
Maven版本: $("$INSTALL_DIR/bin/mvn" -version 2>&1 | head -n 1)

${YELLOW}注意事项:${NC}
1. 环境变量已在当前会话中生效，可直接使用 mvn 命令
2. 新开终端会话会自动加载环境变量
3. 验证安装: mvn -version
4. 如果 mvn 命令不生效，请执行: source /etc/profile
5. 配置文件备份在: $PROFILE_FILE.backup.*

${BLUE}环境变量:${NC}
MAVEN_HOME=$INSTALL_DIR
M2_HOME=$INSTALL_DIR
PATH=\$MAVEN_HOME/bin:\$PATH
EOF
        fi
    fi
}

# 主函数
main() {
    [[ $SILENT_MODE == false ]] && log_info "开始Maven安装程序..."
    
    check_root
    detect_system
    check_java
    check_existing_maven
    install_dependencies
    
    local package_path=$(validate_package)
    install_maven "$package_path"
    configure_environment
    verify_installation
    show_installation_info
    
    # 强制在脚本结束前再次设置环境变量
    export MAVEN_HOME="$INSTALL_DIR"
    export M2_HOME="$INSTALL_DIR"
    export PATH="$MAVEN_HOME/bin:$PATH"
    
    if [[ $SILENT_MODE == false ]]; then
        cleanup
    fi
    
    log_success "Maven $MAVEN_VERSION 安装完成!"
    
    # 最后提示用户如何验证
    if [[ $SILENT_MODE == false ]]; then
        echo
        log_info "请在新终端中执行 'mvn -version' 验证安装"
        log_info "如果命令不生效，请执行: source /etc/profile"
    fi
}

# 清理临时文件
cleanup() {
    if [[ -z "$CUSTOM_PACKAGE_PATH" ]]; then
        read -p "是否保留Maven安装包? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            rm -f "$SOURCE_DIR/$MAVEN_PACKAGE"
            log_info "安装包已删除"
        fi
    fi
}

# 错误处理
trap 'log_error "安装过程中发生错误，退出码: $?"' ERR

# 执行主函数
main "$@"