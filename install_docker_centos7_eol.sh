#!/bin/bash

# Docker and Docker Compose installation script for CentOS 7 (End-of-Life)
# Addresses the deprecation warning and provides working solutions
# Docker Compose: Place docker-compose-linux-x86_64 in current directory for local installation

# Set color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Colored output functions
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

notice() {
    echo -e "${BLUE}[NOTICE]${NC} $1"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    warning "This script requires root privileges, attempting to use sudo"
    exec sudo "$0" "$@"
    exit $?
fi

info "Docker Installation Script for CentOS 7 (End-of-Life)"
notice "This script addresses the CentOS 7 EOL deprecation warning"

# Display system information
info "Checking system information..."
echo "Kernel version: $(uname -r)"
echo "Operating system: $(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)"

# CentOS 7 EOL Warning and Options
warning "=== IMPORTANT NOTICE ==="
warning "CentOS 7 has reached End-of-Life (EOL) and is no longer supported."
warning "No security updates will be provided for this distribution."
echo
notice "Recommended actions:"
echo "1. Upgrade to a supported OS (Rocky Linux 8/9, AlmaLinux 8/9, CentOS Stream)"
echo "2. Continue with CentOS 7 (not recommended for production)"
echo "3. Use alternative Docker installation methods"
echo

read -p "Choose an option (1/2/3): " CHOICE

case $CHOICE in
    1)
        info "=== OS UPGRADE RECOMMENDATIONS ==="
        echo "Recommended migration paths:"
        echo "â€?Rocky Linux 9: https://rockylinux.org/"
        echo "â€?AlmaLinux 9: https://almalinux.org/"
        echo "â€?CentOS Stream 9: https://www.centos.org/centos-stream/"
        echo
        echo "Migration tools:"
        echo "â€?ELevate: https://almalinux.org/elevate/"
        echo "â€?Rocky Linux migration script"
        echo
        warning "Please backup your system before migration!"
        exit 0
        ;;
    2)
        warning "Continuing with CentOS 7 installation (NOT RECOMMENDED for production)"
        ;;
    3)
        info "=== ALTERNATIVE INSTALLATION METHODS ==="
        echo "1. Manual RPM installation"
        echo "2. Binary installation"
        echo "3. Container-based Docker (Docker-in-Docker)"
        read -p "Choose alternative method (1/2/3): " ALT_METHOD
        
        case $ALT_METHOD in
            1)
                info "Manual RPM installation method selected"
                INSTALL_METHOD="rpm"
                ;;
            2)
                info "Binary installation method selected"
                INSTALL_METHOD="binary"
                ;;
            3)
                info "Container-based installation method selected"
                INSTALL_METHOD="container"
                ;;
            *)
                error "Invalid choice. Exiting."
                ;;
        esac
        ;;
    *)
        error "Invalid choice. Exiting."
        ;;
esac

# Check and remove existing Docker installations
if command -v docker &> /dev/null; then
    INSTALLED_DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
    warning "Detected existing Docker installation: $INSTALLED_DOCKER_VERSION"
    
    read -p "Remove existing Docker installation? (y/n): " REMOVE_DOCKER
    
    if [[ "$REMOVE_DOCKER" =~ ^[Yy]$ ]]; then
        info "Removing existing Docker installation..."
        systemctl stop docker &> /dev/null
        yum remove -y docker-ce docker-ce-cli containerd.io docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine docker-compose-plugin &> /dev/null
        rm -rf /var/lib/docker
        rm -rf /etc/docker
        info "Docker removal completed"
    fi
fi

# Installation based on chosen method
if [ "$CHOICE" = "2" ] || [ -z "$INSTALL_METHOD" ]; then
    # Standard CentOS 7 installation with workarounds
    info "Installing Docker on CentOS 7 with EOL workarounds..."
    
    # Update system packages
    info "Updating system packages..."
    yum update -y
    
    # Install dependencies
    info "Installing Docker dependencies..."
    yum install -y yum-utils device-mapper-persistent-data lvm2 curl
    
    # Use archived CentOS 7 repositories
    info "Configuring CentOS 7 archived repositories..."
    
    # Backup original repo files
    mkdir -p /etc/yum.repos.d/backup
    cp /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null || true
    
    # Configure accelerated CentOS repositories with multiple mirrors
    cat > /etc/yum.repos.d/CentOS-Vault.repo << 'EOF'
[C7.9.2009-base]
name=CentOS-7.9.2009 - Base
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/os/x86_64/
        https://mirrors.tuna.tsinghua.edu.cn/centos-vault/7.9.2009/os/x86_64/
        http://vault.centos.org/7.9.2009/os/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=1
timeout=30
retries=3

[C7.9.2009-updates]
name=CentOS-7.9.2009 - Updates
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/updates/x86_64/
        https://mirrors.tuna.tsinghua.edu.cn/centos-vault/7.9.2009/updates/x86_64/
        http://vault.centos.org/7.9.2009/updates/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=1
timeout=30
retries=3

[C7.9.2009-extras]
name=CentOS-7.9.2009 - Extras
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/extras/x86_64/
        https://mirrors.tuna.tsinghua.edu.cn/centos-vault/7.9.2009/extras/x86_64/
        http://vault.centos.org/7.9.2009/extras/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=1
timeout=30
retries=3
EOF
    
    # Add Docker repository with multiple mirrors
    info "Adding Docker repository with fallback mirrors..."
    
    # Create Docker repository file with multiple baseurl entries
cat > /etc/yum.repos.d/docker-ce.repo << 'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/$basearch/stable
        https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/7/$basearch/stable
        https://download.docker.com/linux/centos/7/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg
       https://download.docker.com/linux/centos/gpg
EOF

    # Clean yum cache and rebuild
    yum clean all
    yum makecache fast
    
    # Install specific Docker version that works with CentOS 7
    info "Installing Docker CE (compatible version for CentOS 7)..."
    # Try with skip-broken to handle package conflicts
    if ! yum install -y docker-ce-20.10.24 docker-ce-cli-20.10.24 containerd.io --skip-broken; then
        warning "Standard installation failed, trying without version pinning..."
        yum install -y docker-ce docker-ce-cli containerd.io --skip-broken
    fi
    
else
    # Alternative installation methods
    case $INSTALL_METHOD in
        "rpm")
            info "Installing Docker via manual RPM download..."
            
            # Download Docker RPM packages manually
            mkdir -p /tmp/docker-rpms
            cd /tmp/docker-rpms
            
            info "Downloading Docker RPM packages..."
            # Try multiple mirrors for better connectivity
            info "Downloading Docker RPM packages from mirrors..."
            
            # Function to download with fallback mirrors
            download_with_fallback() {
                local filename=$1
                local mirrors=(
                    "https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages"
                    "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/7/x86_64/stable/Packages"
                    "https://download.docker.com/linux/centos/7/x86_64/stable/Packages"
                )
                
                for mirror in "${mirrors[@]}"; do
                    info "Trying to download $filename from $mirror"
                    if curl -fsSL --connect-timeout 30 --retry 3 -O "$mirror/$filename"; then
                        info "âœ?Successfully downloaded $filename"
                        return 0
                    else
                        warning "âœ?Failed to download from $mirror"
                    fi
                done
                
                error "Failed to download $filename from all mirrors"
                return 1
            }
            
            # Download packages with fallback
            download_with_fallback "docker-ce-20.10.24-3.el7.x86_64.rpm" || exit 1
            download_with_fallback "docker-ce-cli-20.10.24-3.el7.x86_64.rpm" || exit 1
            download_with_fallback "containerd.io-1.6.18-3.1.el7.x86_64.rpm" || exit 1
            
            info "Installing Docker from RPM packages..."
            yum localinstall -y *.rpm
            
            cd /
            rm -rf /tmp/docker-rpms
            ;;
            
        "binary")
            info "Installing Docker via binary download..."
            
            # Download Docker binary
            DOCKER_VERSION="20.10.24"
            curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz -o docker.tgz
            
            # Extract and install
            tar -xzf docker.tgz
            cp docker/* /usr/local/bin/
            rm -rf docker docker.tgz
            
            # Create systemd service
            cat > /etc/systemd/system/docker.service << 'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF
            
            systemctl daemon-reload
            ;;
            
        "container")
            info "Installing Docker-in-Docker (DinD)..."
            
            # This method runs Docker inside a container
            # First install podman as container runtime
            yum install -y podman
            
            info "Docker will run as a container using Podman"
            info "Use: podman run --privileged -d --name docker-dind docker:dind"
            info "Then: podman exec -it docker-dind docker --version"
            
            warning "This is a specialized setup for development/testing only"
            exit 0
            ;;
    esac
fi

# Start Docker service
info "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Configure Docker daemon
info "Configuring Docker daemon..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.1panel.live",
    "https://docker.ketches.cn"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

# Restart Docker to apply configuration
info "Restarting Docker service..."
systemctl restart docker

# Install Docker Compose from local file
info "Installing Docker Compose..."
local_compose_file="./docker-compose-linux-x86_64"
target_compose_path="/usr/local/bin/docker-compose"

if [[ -f "$local_compose_file" ]]; then
    info "Found local Docker Compose file: $local_compose_file"
    
    # Check if Docker Compose is already installed
    if command -v docker-compose &> /dev/null; then
        current_compose_version=$(docker-compose --version 2>/dev/null || echo "unknown")
        warning "Docker Compose is already installed: $current_compose_version"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Docker Compose installation skipped"
        else
            rm -f "$target_compose_path"
            # Copy and install Docker Compose
            if cp "$local_compose_file" "$target_compose_path"; then
                chmod +x "$target_compose_path"
                if "$target_compose_path" --version &> /dev/null; then
                    COMPOSE_VERSION=$("$target_compose_path" --version)
                    info "Docker Compose installed successfully: $COMPOSE_VERSION"
                else
                    warning "Docker Compose file appears to be corrupted"
                    rm -f "$target_compose_path"
                fi
            else
                warning "Failed to install Docker Compose"
            fi
        fi
    else
        # Install Docker Compose
        if cp "$local_compose_file" "$target_compose_path"; then
            chmod +x "$target_compose_path"
            if "$target_compose_path" --version &> /dev/null; then
                COMPOSE_VERSION=$("$target_compose_path" --version)
                info "Docker Compose installed successfully: $COMPOSE_VERSION"
            else
                warning "Docker Compose file appears to be corrupted"
                rm -f "$target_compose_path"
            fi
        else
            warning "Failed to install Docker Compose"
        fi
    fi
else
    warning "Docker Compose local file not found: $local_compose_file"
    info "To install Docker Compose, download docker-compose-linux-x86_64 to current directory"
    info "Download URL: https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-linux-x86_64"
fi

# Verify installation
info "Verifying Docker installation..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    info "Docker installed successfully: $DOCKER_VERSION"
else
    error "Docker installation failed"
    exit 1
fi

# Verify Docker Compose installation
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    info "Docker Compose installed successfully: $COMPOSE_VERSION"
else
    warning "Docker Compose not installed"
fi

# Test Docker
info "Testing Docker..."
if docker run --rm hello-world &> /dev/null; then
    info "Docker test successful!"
else
    warning "Docker test failed, but installation completed"
fi

info "=== INSTALLATION COMPLETED ==="
warning "SECURITY REMINDER: CentOS 7 is EOL - consider upgrading your OS"
info "Docker is now installed and running"
echo "-----------------------------------------------------------"
echo "Installation Summary:"
echo "- Docker version: $DOCKER_VERSION"
if [ -n "$COMPOSE_VERSION" ]; then
    echo "- Docker Compose version: $COMPOSE_VERSION"
fi
echo "- Registry mirrors: Configured for China"
echo "- Service status: Started and enabled"
echo "-----------------------------------------------------------"

info "Next steps:"
echo "1. Consider upgrading to a supported OS (Rocky Linux, AlmaLinux)"
echo "2. Test Docker: docker run hello-world"
echo "3. Read Docker documentation: https://docs.docker.com/"
echo "4. Monitor security updates manually (CentOS 7 EOL)"