#!/bin/bash

# JDK 删除脚本 - 增强版
# 适用于 CentOS 7.9 及其他 Linux 发行版
# 彻底清理JDK安装和环境配置
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
DEFAULT_INSTALL_DIR="/usr/local/java"
PROFILE_FILE="/etc/profile"
BASHRC_FILE="/etc/bashrc"
USER_PROFILE="$HOME/.bashrc"
USER_BASH_PROFILE="$HOME/.bash_profile"
USER_PROFILE_FILE="$HOME/.profile"

# 运行时变量
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
SILENT_MODE=false
FORCE_REMOVE=false
BACKUP_CONFIGS=true

usage() {
    cat << EOF
使用方法: $0 [选项]

选项:
  -d, --install-dir DIR     指定JDK安装目录 (默认: $DEFAULT_INSTALL_DIR)
  -f, --force              强制删除，不询问确认
  -q, --quiet              静默模式，减少输出
  --no-backup              不备份配置文件
  -h, --help               显示此帮助信息

示例:
  $0                       # 交互式删除（会询问确认）
  $0 -f                    # 强制删除
  $0 -d /opt/java          # 删除指定目录的JDK
  $0 -f -q                 # 强制静默删除
  $0 --no-backup           # 删除时不备份配置文件
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_REMOVE=true
            shift
            ;;
        -q|--quiet)
            SILENT_MODE=true
            shift
            ;;
        --no-backup)
            BACKUP_CONFIGS=false
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

# 检测当前Java安装
detect_java() {
    [[ $SILENT_MODE == false ]] && log_info "检测当前Java安装..."
    
    # 检查java命令
    if command -v java >/dev/null 2>&1; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
        JAVA_HOME_CURRENT=$(readlink -f $(which java) | sed 's|/bin/java||')
        [[ $SILENT_MODE == false ]] && log_info "检测到Java版本: $JAVA_VERSION"
        [[ $SILENT_MODE == false ]] && log_info "Java安装路径: $JAVA_HOME_CURRENT"
    else
        [[ $SILENT_MODE == false ]] && log_warning "未检测到Java命令"
    fi
    
    # 检查JAVA_HOME环境变量
    if [[ -n "$JAVA_HOME" ]]; then
        [[ $SILENT_MODE == false ]] && log_info "当前JAVA_HOME: $JAVA_HOME"
    else
        [[ $SILENT_MODE == false ]] && log_warning "未设置JAVA_HOME环境变量"
    fi
    
    # 检查指定的安装目录
    if [[ -d "$INSTALL_DIR" ]]; then
        [[ $SILENT_MODE == false ]] && log_info "找到JDK安装目录: $INSTALL_DIR"
    else
        [[ $SILENT_MODE == false ]] && log_warning "JDK安装目录不存在: $INSTALL_DIR"
    fi
}

# 确认删除操作
confirm_removal() {
    if [[ $FORCE_REMOVE == true || $SILENT_MODE == true ]]; then
        return 0
    fi
    
    echo
    log_warning "=== 即将执行以下删除操作 ==="
    echo "1. 删除JDK安装目录: $INSTALL_DIR"
    echo "2. 清理环境变量配置 (JAVA_HOME, PATH, CLASSPATH)"
    echo "3. 清理以下配置文件中的Java相关配置:"
    echo "   - $PROFILE_FILE"
    echo "   - $BASHRC_FILE"
    echo "   - $USER_PROFILE (如果存在)"
    echo "   - $USER_BASH_PROFILE (如果存在)"
    echo "   - $USER_PROFILE_FILE (如果存在)"
    if [[ $BACKUP_CONFIGS == true ]]; then
        echo "4. 备份配置文件 (添加.backup.日期时间后缀)"
    fi
    echo
    
    read -p "确认执行删除操作? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "删除操作已取消"
        exit 0
    fi
}

# 备份配置文件
backup_config_file() {
    local config_file="$1"
    
    if [[ -f "$config_file" && $BACKUP_CONFIGS == true ]]; then
        local backup_file="$config_file.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup_file"
        [[ $SILENT_MODE == false ]] && log_info "备份配置文件: $config_file -> $backup_file"
    fi
}

# 清理配置文件中的Java环境变量
clean_java_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 0
    fi
    
    [[ $SILENT_MODE == false ]] && log_info "清理配置文件: $config_file"
    
    # 备份配置文件
    backup_config_file "$config_file"
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 删除Java相关的环境变量配置
    # 删除包含JAVA_HOME、CLASSPATH的行，以及相关的export和PATH设置
    grep -v -E '^[[:space:]]*export[[:space:]]+JAVA_HOME' "$config_file" > "$temp_file" || true
    grep -v -E '^[[:space:]]*export[[:space:]]+CLASSPATH' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" || true
    grep -v -E '^[[:space:]]*JAVA_HOME[[:space:]]*=' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" || true
    grep -v -E '^[[:space:]]*CLASSPATH[[:space:]]*=' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" || true
    
    # 处理PATH中的JAVA_HOME引用
    sed -i 's|:\$JAVA_HOME/bin||g' "$temp_file" 2>/dev/null || true
    sed -i 's|\$JAVA_HOME/bin:||g' "$temp_file" 2>/dev/null || true
    sed -i 's|:\${JAVA_HOME}/bin||g' "$temp_file" 2>/dev/null || true
    sed -i 's|\${JAVA_HOME}/bin:||g' "$temp_file" 2>/dev/null || true
    
    # 删除Java相关的注释行
    grep -v -E '^[[:space:]]*#.*[Jj]ava.*[Ee]nvironment' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" || true
    grep -v -E '^[[:space:]]*#.*JDK.*installer' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" || true
    
    # 删除连续的空行，只保留单个空行
    awk '/^$/ { if (++n <= 1) print; next }; { n=0; print }' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file"
    
    # 替换原文件
    mv "$temp_file" "$config_file"
    
    [[ $SILENT_MODE == false ]] && log_success "已清理配置文件: $config_file"
}

# 删除JDK安装目录
remove_jdk_directory() {
    if [[ -d "$INSTALL_DIR" ]]; then
        [[ $SILENT_MODE == false ]] && log_info "删除JDK安装目录: $INSTALL_DIR"
        
        # 检查目录是否包含Java相关文件
        if [[ -f "$INSTALL_DIR/bin/java" || -f "$INSTALL_DIR/bin/javac" ]]; then
            rm -rf "$INSTALL_DIR"
            [[ $SILENT_MODE == false ]] && log_success "JDK安装目录已删除"
        else
            log_warning "目录 $INSTALL_DIR 不包含Java文件，跳过删除"
        fi
    else
        [[ $SILENT_MODE == false ]] && log_warning "JDK安装目录不存在: $INSTALL_DIR"
    fi
}

# 清理环境变量配置
clean_environment_configs() {
    [[ $SILENT_MODE == false ]] && log_info "清理环境变量配置..."
    
    # 清理系统级配置文件
    clean_java_config "$PROFILE_FILE"
    clean_java_config "$BASHRC_FILE"
    
    # 清理用户级配置文件（如果存在）
    if [[ -f "$USER_PROFILE" ]]; then
        clean_java_config "$USER_PROFILE"
    fi
    
    if [[ -f "$USER_BASH_PROFILE" ]]; then
        clean_java_config "$USER_BASH_PROFILE"
    fi
    
    if [[ -f "$USER_PROFILE_FILE" ]]; then
        clean_java_config "$USER_PROFILE_FILE"
    fi
}

# 清理当前会话的环境变量
clean_current_session() {
    [[ $SILENT_MODE == false ]] && log_info "清理当前会话的环境变量..."
    
    unset JAVA_HOME
    unset CLASSPATH
    
    # 从PATH中移除Java相关路径
    if [[ -n "$PATH" ]]; then
        # 移除包含java的路径
        PATH=$(echo "$PATH" | tr ':' '\n' | grep -v -E '/java/|/jdk|/jre' | tr '\n' ':' | sed 's/:$//')
        export PATH
    fi
    
    [[ $SILENT_MODE == false ]] && log_success "当前会话环境变量已清理"
}

# 验证删除结果
verify_removal() {
    [[ $SILENT_MODE == false ]] && log_info "验证删除结果..."
    
    local issues_found=false
    
    # 检查java命令是否还存在
    if command -v java >/dev/null 2>&1; then
        local remaining_java=$(which java)
        log_warning "仍然检测到Java命令: $remaining_java"
        issues_found=true
    fi
    
    # 检查JAVA_HOME是否还存在
    if [[ -n "$JAVA_HOME" ]]; then
        log_warning "JAVA_HOME环境变量仍然存在: $JAVA_HOME"
        issues_found=true
    fi
    
    # 检查安装目录是否还存在
    if [[ -d "$INSTALL_DIR" ]]; then
        log_warning "JDK安装目录仍然存在: $INSTALL_DIR"
        issues_found=true
    fi
    
    if [[ $issues_found == false ]]; then
        [[ $SILENT_MODE == false ]] && log_success "JDK删除验证通过"
    else
        log_warning "删除过程中发现一些问题，请检查上述警告信息"
    fi
}

# 显示删除完成信息
show_completion_info() {
    if [[ $SILENT_MODE == false ]]; then
        cat << EOF

${GREEN}=== JDK 删除完成 ===${NC}
删除的安装目录: $INSTALL_DIR
清理的配置文件:
  - $PROFILE_FILE
  - $BASHRC_FILE
EOF
        
        if [[ -f "$USER_PROFILE" ]]; then
            echo "  - $USER_PROFILE"
        fi
        
        if [[ -f "$USER_BASH_PROFILE" ]]; then
            echo "  - $USER_BASH_PROFILE"
        fi
        
        if [[ -f "$USER_PROFILE_FILE" ]]; then
            echo "  - $USER_PROFILE_FILE"
        fi
        
        cat << EOF

${YELLOW}注意事项:${NC}
1. 环境变量已从当前会话中清理
2. 请重新登录或重启终端使所有更改完全生效
3. 如果需要恢复配置，可以使用备份文件 (*.backup.*)
4. 验证删除: 执行 'java -version' 应该提示命令不存在

${BLUE}如需重新安装JDK:${NC}
请使用 install-java.sh 脚本进行安装
EOF
    fi
}

# 主函数
main() {
    [[ $SILENT_MODE == false ]] && log_info "开始JDK删除程序..."
    
    check_root
    detect_java
    confirm_removal
    
    remove_jdk_directory
    clean_environment_configs
    clean_current_session
    verify_removal
    show_completion_info
    
    log_success "JDK删除完成!"
}

# 错误处理
trap 'log_error "删除过程中发生错误，退出码: $?"' ERR

# 执行主函数
main "$@"