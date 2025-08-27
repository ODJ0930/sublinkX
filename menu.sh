#!/bin/bash
function Up {
    echo "正在检查更新方式..."
    # 获取最新的发行版标签
    latest_release=$(curl --silent "https://api.github.com/repos/ODJ0930/sublinkX/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    # 检查是否有Release版本
    if [ -z "$latest_release" ] || [ "$latest_release" = "null" ]; then
        echo "未找到Release版本，使用源码编译方式更新..."
        update_from_source
    else
        echo "最新版本: $latest_release"
        update_from_release
    fi
}

function update_from_release {
    # 检测机器类型
    machine_type=$(uname -m)

    if [ "$machine_type" = "x86_64" ]; then
        file_name="sublink_amd64"
    elif [ "$machine_type" = "aarch64" ]; then
        file_name="sublink_arm64"
    else
        echo "不支持的机器类型: $machine_type"
        exit 1
    fi

    # 下载文件
    echo "正在从Release下载更新..."
    curl -LO "https://github.com/ODJ0930/sublinkX/releases/download/$latest_release/$file_name"

    # 检查下载是否成功
    if [ ! -f "$file_name" ]; then
        echo "Release下载失败，尝试源码编译更新..."
        update_from_source
        return
    fi

    # 设置文件为可执行
    chmod +x $file_name

    # 移动文件到指定目录
    mv $file_name "/usr/local/bin/sublink/sublink"
    echo "更新完成"
}

function update_from_source {
    echo "使用源码编译方式更新..."
    
    # 检查Git是否安装
    if ! command -v git &> /dev/null; then
        echo "Git 未安装，无法更新"
        return
    fi
    
    # 检查Go是否安装
    if ! command -v go &> /dev/null; then
        echo "Go 未安装，无法编译更新"
        return
    fi
    
    # 临时目录
    TEMP_DIR="/tmp/sublinkX_update"
    
    # 克隆最新代码
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    git clone https://github.com/ODJ0930/sublinkX.git "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # 编译
    export PATH=$PATH:/usr/local/go/bin
    go mod download
    
    machine_type=$(uname -m)
    if [ "$machine_type" = "x86_64" ]; then
        GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o sublink main.go
    elif [ "$machine_type" = "aarch64" ]; then
        GOOS=linux GOARCH=arm64 go build -ldflags="-w -s" -o sublink main.go
    else
        echo "不支持的机器类型: $machine_type"
        cd /
        rm -rf "$TEMP_DIR"
        return
    fi
    
    # 检查编译是否成功
    if [ ! -f "sublink" ]; then
        echo "编译失败"
        cd /
        rm -rf "$TEMP_DIR"
        return
    fi
    
    # 替换程序文件
    chmod +x sublink
    mv sublink "/usr/local/bin/sublink/sublink"
    
    # 清理临时文件
    cd /
    rm -rf "$TEMP_DIR"
    
    echo "源码编译更新完成"
}
function Select {
    # 获取最新的发行版标签
    latest_release=$(curl --silent "https://api.github.com/repos/ODJ0930/sublinkX/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    # 获取服务状态
    cd /usr/local/bin/sublink # 进入sublink目录
    status=$(systemctl is-active sublink)
    version=$(./sublink --version)
    echo "最新版本:$latest_release"
    echo "当前版本:$version"
    # 判断服务状态并打印
    if [ "$status" = "active" ]; then
        echo "当前运行状态: 已运行"
    else
        echo "当前运行状态: 未运行"
    fi
    echo "1. 启动服务"
    echo "2. 停止服务"
    echo "3. 卸载安装"
    echo "4. 查看服务状态"
    echo "5. 查看运行目录"
    echo "6. 修改端口"
    echo "7. 更新"
    echo "8. 重置账号密码"
    echo "9. 查看初始密码"
    echo "0. 退出"
    echo -n "请选择一个选项: "
    read option

    case $option in
        1)
            systemctl start sublink
            systemctl daemon-reload
            ;;
        2)
            systemctl stop sublink
            systemctl daemon-reload
            ;;
        3)
            # 停止服务之前检查服务是否存在
            if systemctl is-active --quiet sublink; then
                systemctl stop sublink
            fi
            if systemctl is-enabled --quiet sublink; then
                systemctl disable sublink
            fi
            # 删除服务文件
            if [ -f /etc/systemd/system/sublink.service ]; then
                sudo rm /etc/systemd/system/sublink.service
            fi
            # 删除相关文件和目录
            sudo rm -r /usr/local/bin/sublink/sublink
            sudo rm -r /usr/bin/sublink
            read -p "是否删除模板文件和数据库(y/n): " isDelete
            if [ "$isDelete" = "y" ]; then
                sudo rm -r /usr/local/bin/sublink/db
                sudo rm -r /usr/local/bin/sublink/template
                sudo rm -r /usr/local/bin/sublink/logs
            fi
            echo "卸载完成"
            ;;
        4)
            systemctl status sublink
            ;;
        5)
            echo "运行目录: /usr/local/bin/sublink"
            echo "需要备份的目录为db,template目录为模版文件可备份可不备份"
            cd /usr/local/bin/sublink
            ;;
        6)
            SERVICE_FILE="/etc/systemd/system/sublink.service"
            read -p "请输入新的端口号: " Port
            echo "新的端口号: $Port"
            PARAMETER="run --port $Port"
            # 检查服务文件是否存在
            if [ ! -f "$SERVICE_FILE" ]; then
                echo "服务文件不存在: $SERVICE_FILE"
                exit 1
            fi

            # 检查 ExecStart 是否已经包含该参数
            if grep -q "run --port" "$SERVICE_FILE"; then
                echo "参数已存在，正在替换..."
                # 使用 sed 替换 ExecStart 行中的 -port 参数
                sudo sed -i "s/-port [0-9]\+/-port $Port/" "$SERVICE_FILE"
            else
                # 如果没有 -port 参数，添加新参数
                # 使用 sed 替换 ExecStart 行，添加启动参数
                sudo sed -i "/^ExecStart=/ s|$| $PARAMETER|" "$SERVICE_FILE"
                echo "参数已添加到 ExecStart 行: $PARAMETER"
            fi

            # 重新加载 systemd 守护进程
            sudo systemctl daemon-reload
            # 重启 sublink 服务
            sudo systemctl restart sublink

            echo "服务已重启。"

            ;;
        7)
            # 停止服务之前检查服务是否存在
            if systemctl is-active --quiet sublink; then
                systemctl stop sublink
            fi
            # 检查是否为最新版本
            if [[ $version = $latest_release ]]; then
                echo "当前已经是最新版本"
            else
                Up
            fi
            ;;
        8)
            read -p "请输入新的账号: " User
            read -p "请输入新的密码: " Password
            # 运行二进制文件并传递启动参数，放在后台运行
            cd /usr/local/bin/sublink
            ./sublink setting --username "$User" --password "$Password" &
            # 获取该程序的PID
            pid=$!
            # 等待程序完成
            wait $pid
            # 如果需要可以在此处进行清理
            systemctl restart sublink
            ;;
        9)
            echo "正在查找初始管理员密码..."
            echo "==========================================="
            cd /usr/local/bin/sublink
            
            # 首先检查密码文件是否存在
            if [ -f "admin_password.txt" ]; then
                echo "📄 从保存的文件中读取密码信息："
                cat admin_password.txt
            else
                echo "📋 未找到密码文件，尝试从系统日志查找..."
                # 查找系统日志中的随机密码信息
                password_info=$(journalctl -u sublink --no-pager | grep "随机密码" | tail -1)
                if [ -n "$password_info" ]; then
                    echo "$password_info"
                else
                    echo "❌ 未找到初始密码信息"
                    echo "💡 可能原因："
                    echo "   1. 数据库已存在，未生成新密码"
                    echo "   2. 日志已被清理"
                    echo "   3. 程序未正常初始化"
                    echo ""
                    echo "🔧 解决方法："
                    echo "   1. 重置账号密码（选项8）"
                    echo "   2. 删除db目录重新初始化"
                fi
            fi
            echo "==========================================="
            read -p "按回车键继续..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "无效的选项,请重新选择"
            Select
            ;;
    esac
}
Select
