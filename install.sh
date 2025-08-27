#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}SublinkX 自动安装脚本${NC}"

# 检查用户是否为root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}该脚本必须以root身份运行。${NC}"
    exit 1
fi

# 创建一个程序目录
INSTALL_DIR="/usr/local/bin/sublink"

if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
fi

# 安装Go
install_go() {
    echo "正在安装 Go..."
    cd /tmp
    
    # 检测机器类型
    machine_type=$(uname -m)
    if [ "$machine_type" = "x86_64" ]; then
        arch="amd64"
    elif [ "$machine_type" = "aarch64" ]; then
        arch="arm64"
    else
        echo -e "${RED}不支持的机器类型: $machine_type${NC}"
        exit 1
    fi
    
    # 下载Go
    go_version="1.22.2"
    wget "https://go.dev/dl/go${go_version}.linux-${arch}.tar.gz"
    
    # 安装Go
    rm -rf /usr/local/go
    tar -C /usr/local -xzf "go${go_version}.linux-${arch}.tar.gz"
    
    # 设置环境变量
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    
    echo -e "${GREEN}Go 安装完成${NC}"
}

# 检查依赖
check_dependencies() {
    echo "检查依赖..."
    
    # 检查git
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git 未安装，正在安装...${NC}"
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y git
        elif command -v yum &> /dev/null; then
            yum install -y git
        elif command -v dnf &> /dev/null; then
            dnf install -y git
        else
            echo -e "${RED}无法自动安装Git，请手动安装后重试${NC}"
            exit 1
        fi
    fi
    
    # 检查go
    if ! command -v go &> /dev/null; then
        echo -e "${YELLOW}Go 未安装，正在安装...${NC}"
        install_go
    else
        go_version=$(go version | awk '{print $3}' | sed 's/go//')
        echo -e "${GREEN}Go 已安装，版本: $go_version${NC}"
    fi
}

# 创建服务并完成安装
create_service_and_finish() {
    # 创建systemctl服务
    echo "[Unit]
Description=Sublink Service
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/sublink
WorkingDirectory=$INSTALL_DIR
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target" | tee /etc/systemd/system/sublink.service

    # 重新加载systemd守护进程
    systemctl daemon-reload

    # 启动并启用服务
    systemctl start sublink
    systemctl enable sublink
    
    echo -e "${GREEN}服务已启动并已设置为开机启动${NC}"
    echo -e "${YELLOW}默认账号: admin${NC}"
    echo -e "${YELLOW}默认端口: 8000${NC}"
    echo -e "${RED}⚠️  首次运行时会显示随机生成的管理员密码，请注意查看日志！${NC}"
    echo -e "${GREEN}📋 查看密码命令: journalctl -u sublink | grep '随机密码'${NC}"
    
    # 下载menu.sh并设置权限
    curl -o /usr/bin/sublink -H "Cache-Control: no-cache" -H "Pragma: no-cache" https://raw.githubusercontent.com/ODJ0930/sublinkX/main/menu.sh
    chmod 755 "/usr/bin/sublink"
    
    echo -e "${GREEN}安装完成！输入 'sublink' 可以呼出菜单${NC}"
}

# 从源码编译安装
install_from_source() {
    echo -e "${GREEN}使用源码编译方式安装...${NC}"
    
    # 检查依赖
    check_dependencies
    
    # 临时目录
    TEMP_DIR="/tmp/sublinkX"
    
    # 克隆仓库
    echo "正在克隆仓库..."
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    git clone https://github.com/ODJ0930/sublinkX.git "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # 编译程序
    echo "正在编译程序..."
    export PATH=$PATH:/usr/local/go/bin
    go mod download
    
    # 检测机器类型并编译
    machine_type=$(uname -m)
    if [ "$machine_type" = "x86_64" ]; then
        GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o sublink main.go
    elif [ "$machine_type" = "aarch64" ]; then
        GOOS=linux GOARCH=arm64 go build -ldflags="-w -s" -o sublink main.go
    else
        echo -e "${RED}不支持的机器类型: $machine_type${NC}"
        exit 1
    fi
    
    # 检查编译是否成功
    if [ ! -f "sublink" ]; then
        echo -e "${RED}编译失败，请检查错误信息${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}编译成功${NC}"
    
    # 设置文件为可执行
    chmod +x sublink
    
    # 移动文件到指定目录
    mv sublink "$INSTALL_DIR/sublink"
    
    # 复制模板文件
    if [ -d "template" ]; then
        cp -r template "$INSTALL_DIR/"
    fi
    
    # 清理临时文件
    cd /
    rm -rf "$TEMP_DIR"
    
    create_service_and_finish
}

# 从Release安装
install_from_release() {
    echo -e "${GREEN}使用Release版本安装...${NC}"
    
    # 检测机器类型
    machine_type=$(uname -m)
    
    if [ "$machine_type" = "x86_64" ]; then
        file_name="sublink_amd64"
    elif [ "$machine_type" = "aarch64" ]; then
        file_name="sublink_arm64"
    else
        echo -e "${RED}不支持的机器类型: $machine_type${NC}"
        exit 1
    fi
    
    # 下载文件
    cd ~
    echo "正在下载 $file_name..."
    curl -LO "https://github.com/ODJ0930/sublinkX/releases/download/$latest_release/$file_name"
    
    # 检查文件是否下载成功
    if [ ! -f "$file_name" ]; then
        echo -e "${RED}下载失败，尝试使用源码编译方式${NC}"
        install_from_source
        return
    fi
    
    # 设置文件为可执行
    chmod +x $file_name
    
    # 移动文件到指定目录
    mv $file_name "$INSTALL_DIR/sublink"
    
    create_service_and_finish
}

# 获取最新的发行版标签
echo "正在检查Release版本..."
latest_release=$(curl --silent "https://api.github.com/repos/ODJ0930/sublinkX/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# 检查是否成功获取到版本信息
if [ -z "$latest_release" ] || [ "$latest_release" = "null" ]; then
    echo -e "${YELLOW}未找到Release版本，将使用源码编译方式安装${NC}"
    install_from_source
    exit 0
else
    echo -e "${GREEN}找到Release版本: $latest_release${NC}"
    install_from_release
fi
