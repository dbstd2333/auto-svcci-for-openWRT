#!/bin/sh
# 校园网多播认证测试脚本
# 用于验证配置和脚本功能

SCRIPT_PATH="/usr/sbin/auto-hhu-multi.sh"
TEST_INTERFACE="${1:-wan1}"
TEST_CONF="/etc/auto-hhu-${TEST_INTERFACE}.conf"

echo "校园网多播认证测试工具"
echo "======================"
echo ""

# 检查脚本是否存在
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "ERROR: 主脚本 $SCRIPT_PATH 不存在"
    exit 1
fi

# 检查配置文件
if [ ! -f "$TEST_CONF" ]; then
    echo "ERROR: 配置文件 $TEST_CONF 不存在"
    echo "请创建配置文件：cp /etc/auto-hhu-template.conf $TEST_CONF"
    echo "然后编辑 $TEST_CONF 填入正确的学号和密码"
    exit 1
fi

# 检查接口是否存在
if ! ip link show "$TEST_INTERFACE" >/dev/null 2>&1; then
    echo "WARNING: 网络接口 $TEST_INTERFACE 不存在"
    echo "可用的网络接口："
    ip link show | grep -E "^[0-9]+:" | awk '{print $2}' | sed 's/://g' | grep -v lo
    exit 1
fi

echo "测试信息："
echo "- 接口: $TEST_INTERFACE"
echo "- 配置: $TEST_CONF"
echo "- 脚本: $SCRIPT_PATH"
echo ""

# 加载配置
source "$TEST_CONF"
echo "配置检查："
echo "- 学号: ${userId:-未设置}"
echo "- 密码: $([ -n "$password" ] && echo "已设置" || echo "未设置")"
echo "- 服务: ${service:-未设置}"
echo ""

if [ -z "$userId" ] || [ -z "$password" ]; then
    echo "ERROR: 学号或密码未设置，请编辑 $TEST_CONF"
    exit 1
fi

# 测试网络连通性
echo "网络测试："
echo -n "测试接口 $TEST_INTERFACE 连通性..."
if ping -I "$TEST_INTERFACE" -w3 -c1 baidu.com >/dev/null 2>&1; then
    echo " OK (已联网)"
else
    echo " FAIL (未联网)"
fi

# 测试认证URL
echo -n "测试认证服务器..."
if curl -m5 -s --interface "$TEST_INTERFACE" "http://eportal.hhu.edu.cn" >/dev/null 2>&1; then
    echo " OK"
else
    echo " FAIL (可能无法访问认证服务器)"
fi

echo ""
echo "开始认证测试（10秒超时）..."
echo "========================================="

# 运行测试
"$SCRIPT_PATH" "$TEST_INTERFACE" "$TEST_CONF" &
TEST_PID=$!

# 等待并检查状态
sleep 5
if kill -0 "$TEST_PID" 2>/dev/null; then
    echo "认证进程已启动 (PID: $TEST_PID)"
    echo ""
    echo "查看日志："
    tail -n 5 "/tmp/auto-hhu-${TEST_INTERFACE}.log" 2>/dev/null || echo "暂无日志"
    echo ""
    echo "测试完成！认证进程正在后台运行。"
    echo "使用以下命令管理："
    echo "  查看状态: /etc/init.d/auto-hhu-multi status"
    echo "  停止服务: /etc/init.d/auto-hhu-multi stop"
    echo "  查看日志: tail -f /tmp/auto-hhu-${TEST_INTERFACE}.log"
else
    echo "ERROR: 认证进程启动失败"
    echo "请检查日志：/tmp/auto-hhu-${TEST_INTERFACE}.log"
fi

exit 0