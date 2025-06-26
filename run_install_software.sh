#!/bin/bash

# 启用调试模式（可选）
export DEBUG=0

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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

header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${YELLOW}[DEBUG]${NC} $1"
    fi
}

# 检查是否以root用户运行
if [ "$(id -u)" -ne 0 ]; then
    warning "此脚本需要root权限运行，将尝试使用sudo"
    # 如果不是root用户，则使用sudo重新运行此脚本
    exec sudo "$0" "$@"
    exit $?
fi

# 检查Docker是否已安装
if ! command -v docker &> /dev/null; then
    error "Docker未安装，请先运行install_docker.sh安装Docker"
fi

# 检查docker-compose是否已安装
if ! command -v docker-compose &> /dev/null; then
    info "正在安装docker-compose..."
    curl -L "https://gitee.com/fustack/docker-compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    if ! command -v docker-compose &> /dev/null; then
        error "docker-compose安装失败，请手动安装"
    else
        info "docker-compose安装成功"
    fi
fi

# 检查software目录是否存在
if [ ! -d "$(pwd)/software" ]; then
    error "software目录不存在，请从 https://github.com/fuzhengwei/xfg-dev-tech-docker-install 下载项目，并上传到云服务器 / 根目录下"
fi

# 检查docker-compose-software.yml文件是否存在
if [ ! -f "$(pwd)/software/docker-compose-software.yml" ]; then
    error "docker-compose-software.yml文件不存在，请检查software目录是否完整"
fi

# 检查docker-compose-software-aliyun.yml文件是否存在
if [ ! -f "$(pwd)/software/docker-compose-software-aliyun.yml" ]; then
    error "docker-compose-software-aliyun.yml文件不存在，请检查software目录是否完整"
fi

# 获取当前磁盘空间信息
disk_info=$(df -h / | tail -1)
disk_total=$(echo $disk_info | awk '{print $2}')
disk_used=$(echo $disk_info | awk '{print $3}')
disk_avail=$(echo $disk_info | awk '{print $4}')
disk_used_percent=$(echo $disk_info | awk '{print $5}')

info "当前磁盘空间信息：总空间 ${disk_total}，已使用 ${disk_used}，可用 ${disk_avail}，使用率 ${disk_used_percent}"

# 定义软件列表及其大小估计（单位：MB）
declare -A software_sizes=(
    ["nacos"]=500
    ["mysql"]=600
    ["phpmyadmin"]=100
    ["redis"]=50
    ["redis-admin"]=50
    ["rabbitmq"]=300
    ["elasticsearch"]=500
    ["logstash"]=300
    ["kibana"]=200
    ["xxl-job-admin"]=150
    ["prometheus"]=100
    ["grafana"]=100
    ["ollama"]=200
    ["pgvector"]=150
    ["pgvector-admin"]=50
)

# 定义软件的账号密码信息
declare -A software_credentials=(
    ["nacos"]="账号：nacos 密码：nacos 访问地址：http://服务器IP:8848/nacos"
    ["mysql"]="账号：root 密码：123456 端口：13306"
    ["phpmyadmin"]="访问地址：http://服务器IP:8899 (连接到MySQL)"
    ["redis"]="端口：16379"
    ["redis-admin"]="账号：admin 密码：admin 访问地址：http://服务器IP:8081"
    ["rabbitmq"]="账号：admin 密码：admin 访问地址：http://服务器IP:15672"
    ["elasticsearch"]="访问地址：http://服务器IP:9200"
    ["logstash"]="端口：4560,50000,9600"
    ["kibana"]="访问地址：http://服务器IP:5601"
    ["xxl-job-admin"]="账号：admin 密码：123456 访问地址：http://服务器IP:9090/xxl-job-admin"
    ["prometheus"]="访问地址：http://服务器IP:9090"
    ["grafana"]="访问地址：http://服务器IP:4000"
    ["ollama"]="访问地址：http://服务器IP:11434"
    ["pgvector"]="账号：postgres 密码：postgres 端口：5432 数据库：springai"
    ["pgvector-admin"]="账号：admin@qq.com 密码：admin 访问地址：http://服务器IP:5050"
)

# 检查已安装的软件
check_installed() {
    local software=$1
    if docker ps -a --format '{{.Names}}' | grep -q "^${software}$"; then
        return 0 # 已安装
    else
        return 1 # 未安装
    fi
}

# 选择使用哪个配置文件
echo "-----------------------------------------------------------"
header "选择配置文件："
echo "-----------------------------------------------------------"
echo "1. 使用原始配置文件 (推荐，但可能需要从Docker Hub拉取镜像)"
echo "2. 使用阿里云镜像配置文件 (国内网络环境推荐)"
echo "-----------------------------------------------------------"
read -p "请选择配置文件 [1/2] (默认: 1): " config_choice
config_choice=${config_choice:-1}

if [ "$config_choice" = "1" ]; then
    compose_file="$(pwd)/software/docker-compose-software.yml"
    info "已选择使用原始配置文件"
else
    compose_file="$(pwd)/software/docker-compose-software-aliyun.yml"
    info "已选择使用阿里云镜像配置文件"
fi

# 列出可安装的软件
echo "-----------------------------------------------------------"
header "可安装的软件列表："
echo "-----------------------------------------------------------"

# 创建软件选择数组
software_list=("nacos" "mysql" "phpmyadmin" "redis" "redis-admin" "rabbitmq" "elasticsearch" "logstash" "kibana")

# 如果选择了原始配置文件，添加只在原始配置中存在的软件
if [ "$config_choice" = "1" ]; then
    software_list+=("xxl-job-admin" "prometheus" "grafana" "ollama" "pgvector" "pgvector-admin")
else
    # 阿里云镜像配置文件中也包含这些软件
    software_list+=("ollama" "pgvector" "pgvector-admin")
fi
declare -A software_selected

# 显示软件列表及其状态
for ((i=0; i<${#software_list[@]}; i++)); do
    software=${software_list[$i]}
    size=${software_sizes[$software]}
    
    if check_installed "$software"; then
        echo "$((i+1)). $software [已安装] (预计占用空间: ${size}MB)"
    else
        echo "$((i+1)). $software (预计占用空间: ${size}MB)"
    fi
done

echo "-----------------------------------------------------------"
echo "请选择要安装的软件（多选，用空格分隔，如：1 3 5）："
read -a selections

# 处理用户选择
total_size=0
for selection in "${selections[@]}"; do
    # 检查输入是否为数字
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
        warning "无效的选择: $selection，已跳过"
        continue
    fi
    
    # 检查选择是否在范围内
    if [ "$selection" -lt 1 ] || [ "$selection" -gt "${#software_list[@]}" ]; then
        warning "选择超出范围: $selection，已跳过"
        continue
    fi
    
    index=$((selection-1))
    software=${software_list[$index]}
    software_selected[$software]=1
    size=${software_sizes[$software]}
    total_size=$((total_size + size))
done

if [ ${#software_selected[@]} -eq 0 ]; then
    error "未选择任何软件，安装已取消"
fi

# 显示选择的软件及总空间
echo "-----------------------------------------------------------"
header "您选择了以下软件："
for software in "${!software_selected[@]}"; do
    echo "- $software (预计占用空间: ${software_sizes[$software]}MB)"
done
echo "总计预计占用空间: ${total_size}MB"
echo "-----------------------------------------------------------"

# MySQL初始化提示
if [[ -n "${software_selected[mysql]}" ]]; then
    echo "-----------------------------------------------------------"
    header "MySQL初始化提示："
    echo "-----------------------------------------------------------"
    info "您选择了安装MySQL，安装完成后可以使用phpmyadmin进行管理"
    info "如果您希望在初始化时创建数据库和表，可以将SQL脚本放在以下目录："
    echo "  $(pwd)/software/mysql/sql/"
    info "目前该目录已包含以下SQL文件："
    ls -1 "$(pwd)/software/mysql/sql/" | grep ".sql" | while read -r sql_file; do
        echo "  - $sql_file"
    done
    info "您可以添加自己的SQL文件到该目录，它们将在MySQL初始化时自动执行"
    echo "-----------------------------------------------------------"
fi

# Prometheus配置提示
if [[ -n "${software_selected[prometheus]}" ]]; then
    echo "-----------------------------------------------------------"
    header "Prometheus配置提示："
    echo "-----------------------------------------------------------"
    info "您选择了安装Prometheus，请确保："
    info "1. 在安装前配置您的应用监控设置："
    echo "  $(pwd)/software/prometheus/prometheus.yml"
    info "2. 确保被监控的应用端口已在防火墙中开放"
    info "3. 当前配置文件中的目标应用为：'system-app:8091'"
    info "4. 如需监控其他应用，请修改配置文件中的targets部分"
    echo "-----------------------------------------------------------"
fi

# Vector DB初始化提示
if [[ -n "${software_selected[pgvector]}" ]]; then
    echo "-----------------------------------------------------------"
    header "Vector DB初始化提示："
    echo "-----------------------------------------------------------"
    info "您选择了安装Vector DB (pgvector)，请注意："
    info "1. 默认已配置初始化SQL脚本："
    echo "  $(pwd)/software/pgvector/sql/init.sql"
    info "2. 该脚本会创建vector扩展和示例表，您可以查看或修改此文件添加自己的初始化语句"
    info "3. 您也可以在安装后通过pgvector-admin连接数据库自行创建所需的表和扩展"
    info "4. 默认连接信息："
    info "   - 主机：pgvector"
    info "   - 端口：5432"
    info "   - 用户名：postgres"
    info "   - 密码：postgres"
    info "   - 数据库：postgres"
    echo "-----------------------------------------------------------"
fi

# pgvector-admin配置提示
if [[ -n "${software_selected[pgvector-admin]}" ]]; then
    echo "-----------------------------------------------------------"
    header "配置提示："
    echo "-----------------------------------------------------------"
    info "您选择了安装pgvector-admin，请注意："
    info "1. 默认访问地址：http://服务器IP:5050"
    info "2. 默认登录信息："
    info "   - 邮箱：admin@qq.com"
    info "   - 密码：admin"
    info "3. 首次登录后，需要添加服务器连接："
    info "   - 名称：自定义"
    info "   - 主机：pgvector"
    info "   - 端口：5432"
    info "   - 用户名：postgres"
    info "   - 密码：postgres"
    info "4. 如需修改默认登录信息，请编辑docker-compose-software.yml文件中的环境变量"
    echo "-----------------------------------------------------------"
fi

# Ollama配置提示
if [[ -n "${software_selected[ollama]}" ]]; then
    echo "-----------------------------------------------------------"
    header "Ollama配置提示："
    echo "-----------------------------------------------------------"
    info "您选择了安装Ollama，请注意："
    info "1. 安装完成后，您可以通过以下命令拉取模型："
    info "   docker exec -it ollama ollama pull deepseek-r1:1.5b"
    info "2. 运行模型："
    info "   docker exec -it ollama ollama run deepseek-r1:1.5b"
    info "3. 拉取向量模型："
    info "   docker exec -it ollama ollama pull nomic-embed-text"
    info "4. API访问地址：http://服务器IP:11434"
    echo "-----------------------------------------------------------"
fi

# 确认安装
read -p "确认安装以上软件？(y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "安装已取消"
    exit 0
fi

# 检查并自动添加依赖服务
info "正在检查服务依赖关系..."
original_file="$compose_file"
declare -A dependencies_added

# 测试依赖提取功能
test_dependency_extraction() {
    debug "测试pgvector-admin的依赖提取"
    local test_deps=$(awk -v service="phpmyadmin:" 'BEGIN {flag=0;}
    $0 ~ service {flag=1;}
    flag && /depends_on:/ {flag=2;}
    flag==2 && /^      - / {gsub(/^      - /, ""); print $0; next;}
    flag==2 && /^      [a-zA-Z][a-zA-Z0-9_-]*:/ {gsub(/^      /, ""); gsub(/:.*$/, ""); print $0; next;}
    flag==2 && /^  [a-zA-Z]/ {exit;}
    ' "$compose_file")
    debug "测试结果: '$test_deps'"
}

# 依赖提取逻辑已修复，支持多种depends_on格式

# 递归检查依赖函数
check_and_add_dependencies() {
    local service=$1
    debug "正在检查 $service 的依赖关系"
    local deps=$(awk -v service="$service:" 'BEGIN {flag=0;}
    $0 ~ "^  "service {flag=1;}
    flag && /depends_on:/ {flag=2;}
    flag==2 && /^      - / {gsub(/^      - /, ""); print $0; next;}
    flag==2 && /^      [a-zA-Z][a-zA-Z0-9_-]*:/ {gsub(/^      /, ""); gsub(/:.*$/, ""); print $0; next;}
    flag==2 && /^  [a-zA-Z]/ {exit;}' "$compose_file")
    
    if [ -n "$deps" ]; then
        debug "发现 $service 的依赖: $deps"
    else
        debug "$service 无依赖或依赖提取失败"
    fi
    
    for dep in $deps; do
        # 排除网络配置项
        if [[ "$dep" == "my-network" ]] || [[ "$dep" =~ -network$ ]]; then
            continue
        fi
        
        if [ -z "${software_selected[$dep]}" ] && [ -z "${dependencies_added[$dep]}" ]; then
            if check_installed "$dep"; then
                info "$service 依赖的 $dep 已安装，将自动包含在配置中"
                software_selected[$dep]=1
                dependencies_added[$dep]=1
                # 递归检查这个依赖的依赖
                check_and_add_dependencies "$dep"
            else
                warning "$service 依赖于 $dep，但 $dep 未被选中安装"
                read -p "是否同时安装 $dep？(y/n): " install_dep
                if [[ "$install_dep" =~ ^[Yy]$ ]]; then
                    info "将同时安装 $dep"
                    software_selected[$dep]=1
                    dependencies_added[$dep]=1
                    # 递归检查这个依赖的依赖
                    check_and_add_dependencies "$dep"
                else
                    warning "$service 可能无法正常工作，因为缺少依赖 $dep"
                fi
            fi
        fi
    done
}

# 为每个选中的服务检查依赖
for software in "${!software_selected[@]}"; do
    check_and_add_dependencies "$software"
done

# 创建临时的docker-compose文件
temp_compose_file="$(pwd)/software/docker-compose-temp.yml"
cp "$compose_file" "$temp_compose_file"

# 创建需要实际安装的服务数组
declare -A services_to_install
for software in "${!software_selected[@]}"; do
    services_to_install[$software]=1
done

# 处理已安装的软件
for software in "${!software_selected[@]}"; do
    if check_installed "$software"; then
        read -p "$software 已安装，是否重新安装？(y/n): " reinstall
        if [[ "$reinstall" =~ ^[Yy]$ ]]; then
            info "将重新安装 $software"
            docker rm -f "$software" &> /dev/null
        else
            info "跳过安装 $software，但保留在配置中以满足依赖关系"
            unset services_to_install[$software]
        fi
    fi
done

# 如果没有软件需要安装，则退出
if [ ${#services_to_install[@]} -eq 0 ]; then
    info "所有选中的软件都已安装，无需重新安装"
    rm -f "$temp_compose_file"
    exit 0
fi

# 修改临时docker-compose文件，只保留选中的服务
sed -i '/^services:/,$d' "$temp_compose_file"
echo "services:" >> "$temp_compose_file"

# 从原始文件中提取选中的服务配置
original_file="$compose_file"
for software in "${!software_selected[@]}"; do
    # 提取服务配置块
    awk -v service="$software:" '
    BEGIN {flag=0; found=0; indent_level=0;}
    $0 ~ "^  "service {flag=1; found=1; indent_level=2;}
    flag && flag==1 {
        current_indent = match($0, /[^ ]/) - 1;
        if (current_indent <= indent_level && $0 !~ "^  "service && /^  [a-zA-Z][a-zA-Z0-9_-]*:/) {
            flag=0;
        } else if (current_indent > indent_level || $0 ~ "^  "service) {
            print;
        }
    }
    END {exit !found;}' "$original_file" >> "$temp_compose_file"
    
    # 依赖关系已在前面处理，这里只需要提取配置
done

# 添加网络配置（只有当临时文件中还没有networks配置时才添加）
if ! grep -q "^networks:" "$temp_compose_file"; then
    echo "" >> "$temp_compose_file"
    awk '/^networks:/,0' "$original_file" >> "$temp_compose_file"
fi

# 执行docker-compose，只启动需要安装的服务
info "开始安装选中的软件..."
cd "$(pwd)/software"

# 构建需要启动的服务列表
services_to_start=()
for service in "${!services_to_install[@]}"; do
    services_to_start+=("$service")
done

if [ ${#services_to_start[@]} -gt 0 ]; then
    docker-compose -f docker-compose-temp.yml up -d "${services_to_start[@]}"
else
    info "没有需要启动的新服务"
fi

# 检查安装结果
if [ $? -eq 0 ]; then
    info "软件安装完成！"
    echo "-----------------------------------------------------------"
    header "已安装的软件及访问信息："
    for software in "${!software_selected[@]}"; do
        if check_installed "$software"; then
            echo "- $software: ${software_credentials[$software]}"
            
            # MySQL安装后的提示
            if [ "$software" = "mysql" ]; then
                info "MySQL已安装成功，您可以使用phpmyadmin进行管理"
                info "初始化SQL脚本已自动执行，包括："
                ls -1 "$(pwd)/mysql/sql/" | grep ".sql" | while read -r sql_file; do
                    echo "  - $sql_file"
                done
            fi
            
            # Prometheus安装后的提示
            if [ "$software" = "prometheus" ]; then
                info "Prometheus已安装成功，请确保："
                info "1. 被监控的应用已正确配置并开放端口"
                info "2. 如需修改监控配置，请编辑：$(pwd)/prometheus/prometheus.yml"
                info "3. 修改配置后需要重启Prometheus：docker restart prometheus"
            fi
            
            # Vector DB安装后的提示
            if [ "$software" = "pgvector" ]; then
                info "Vector DB已安装成功，初始化SQL脚本已自动执行"
                info "您可以通过pgvector-admin连接并管理数据库"
            fi
            
            # Ollama安装后的提示
            if [ "$software" = "ollama" ]; then
                info "Ollama已安装成功，您可以通过以下命令拉取和运行模型："
                info "拉取模型：docker exec -it ollama ollama pull deepseek-r1:1.5b"
                info "运行模型：docker exec -it ollama ollama run deepseek-r1:1.5b"
            fi
        else
            warning "$software 安装失败"
            if [ "$config_choice" = "1" ]; then
                warning "可能是因为网络问题无法拉取镜像，建议尝试使用阿里云镜像配置文件重新安装"
                warning "重新运行脚本并选择选项2使用阿里云镜像配置文件"
            fi
        fi
    done
    echo "-----------------------------------------------------------"
    info "如需修改账号密码，请编辑 $compose_file 文件"
    info "修改后，重新运行此脚本即可更新配置"
    
    # 清理临时文件
    rm -f "$temp_compose_file"
else
    error "软件安装失败，请查看上面的错误信息"
    if [ "$config_choice" = "1" ]; then
        warning "可能是因为网络问题无法拉取镜像，建议尝试使用阿里云镜像配置文件重新安装"
        warning "重新运行脚本并选择选项2使用阿里云镜像配置文件"
    fi
fi
