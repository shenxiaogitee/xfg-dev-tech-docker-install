#!/bin/bash

# Wrapper script for CentOS 7 Docker installation
# Addresses the End-of-Life deprecation warning

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

# Define the CentOS 7 EOL installation script
CENTOS7_SCRIPT_NAME="install_docker_centos7_eol.sh"

info "=== CentOS 7 Docker Installation Solution ==="
warning "This script addresses the CentOS 7 End-of-Life deprecation warning"
echo

# Display the deprecation warning context
notice "About the deprecation warning you encountered:"
echo "â€?CentOS 7 reached End-of-Life (EOL) on June 30, 2024"
echo "â€?Docker's official installation script no longer supports CentOS 7"
echo "â€?This is a security and maintenance concern"
echo

# Check if the CentOS 7 EOL script exists
if [ ! -f "$CENTOS7_SCRIPT_NAME" ]; then
    error "CentOS 7 EOL installation script $CENTOS7_SCRIPT_NAME not found"
fi

# Set executable permissions
info "Setting executable permissions..."
chmod +x "$CENTOS7_SCRIPT_NAME"

# Display available options
info "This script provides the following solutions:"
echo "1. OS Upgrade Recommendations (Recommended)"
echo "   â€?Migration to Rocky Linux 9 or AlmaLinux 9"
echo "   â€?Provides migration tools and guides"
echo
echo "2. Continue with CentOS 7 (Not Recommended)"
echo "   â€?Uses archived repositories and compatible Docker versions"
echo "   â€?Includes security warnings and limitations"
echo
echo "3. Alternative Installation Methods"
echo "   â€?Manual RPM installation"
echo "   â€?Binary installation"
echo "   â€?Container-based Docker (Docker-in-Docker)"
echo

warning "IMPORTANT SECURITY NOTICE:"
echo "CentOS 7 no longer receives security updates. For production environments,"
echo "it is strongly recommended to upgrade to a supported operating system."
echo

read -p "Do you want to proceed with the CentOS 7 installation options? (y/n): " PROCEED

if [[ "$PROCEED" =~ ^[Yy]$ ]]; then
    info "Starting CentOS 7 Docker installation script..."
    echo "-----------------------------------------------------------"
    ./"$CENTOS7_SCRIPT_NAME"
    
    # Check the exit status
    if [ $? -eq 0 ]; then
        info "CentOS 7 Docker installation completed"
        
        # Ask about Portainer installation
        echo
        read -p "Would you like to install Portainer container management interface? (y/n): " INSTALL_PORTAINER
        
        if [[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]]; then
            info "Installing Portainer..."
            if docker run -d --restart=always --name portainer -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer-ce:latest; then
                info "Portainer installed successfully!"
                warning "Important: Make sure port 9000 is open on your server!"
                echo "-----------------------------------------------------------"
                echo "Portainer Access Information:"
                echo "1. Access via: http://YOUR_SERVER_IP:9000"
                echo "2. First visit requires setting up admin account"
                echo "3. Use web interface to manage Docker containers"
                echo "-----------------------------------------------------------"
                info "You can use Portainer to easily manage Docker containers, images, networks, and volumes"
            else
                warning "Portainer installation failed, please install manually or check Docker status"
            fi
        else
            info "User chose not to install Portainer"
        fi
        
        echo
        info "=== POST-INSTALLATION RECOMMENDATIONS ==="
        warning "Since you're using CentOS 7 (EOL), please consider:"
        echo "1. Plan migration to Rocky Linux 9 or AlmaLinux 9"
        echo "2. Implement additional security monitoring"
        echo "3. Regularly backup your Docker data"
        echo "4. Monitor Docker and container security updates manually"
        echo "5. Consider using this setup only for development/testing"
        
    else
        error "CentOS 7 Docker installation failed, please check the error messages above"
    fi
else
    info "Installation cancelled by user"
    info "Consider upgrading to a supported operating system:"
    echo "â€?Rocky Linux: https://rockylinux.org/"
    echo "â€?AlmaLinux: https://almalinux.org/"
    echo "â€?CentOS Stream: https://www.centos.org/centos-stream/"
    exit 0
fi