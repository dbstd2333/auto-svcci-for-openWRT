#!/bin/sh
# 校园网多播认证脚本（支持多接口多账号）
# 使用说明：./auto-hhu-multi.sh [接口名] [配置文件路径]
# 示例：./auto-hhu-multi.sh wan1 /etc/auto-hhu-wan1.conf

# 获取参数
INTERFACE="${1:-wan1}"
CONF_FILE="${2:-/etc/auto-hhu-${INTERFACE}.conf}"
LOG_FILE="/tmp/auto-hhu-${INTERFACE}.log"
PID_FILE="/var/run/auto-hhu-${INTERFACE}.pid"

# 网络检测目标
TEST_HOST="10.41.127.254"
AUTH_URL="http://192.168.16.201/eportal/InterFace.do?method=login"
RETRY_MAX=5
CHECK_INTERVAL=5

# 检查是否已在运行
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "INFO: auto-hhu for $INTERFACE is already running (PID: $PID)"
        exit 0
    fi
fi

# 写入PID文件
echo $$ > "$PID_FILE"

# 日志函数
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$INTERFACE] [$level] $message" | tee -a "$LOG_FILE"
}

# 清理函数
cleanup() {
    log_message "INFO" "Stopping auto-hhu for $INTERFACE"
    rm -f "$PID_FILE"
    exit 0
}

# 设置信号处理
trap cleanup INT TERM

# 配置文件校验
if [ ! -f "$CONF_FILE" ]; then
    log_message "ERROR" "Configuration file not found at $CONF_FILE"
    exit 1
fi

# 加载配置
source "$CONF_FILE"

# 配置参数校验
if [ -z "$userId" ] || [ -z "$password" ] || [ -z "$service" ] || [ -z "$queryString" ] || [ -z "$passwordEncrypt" ]; then
    log_message "ERROR" "Required parameters missing in $CONF_FILE"
    exit 1
fi

log_message "INFO" "Starting auto-hhu for interface $INTERFACE with user $userId"

# 网络检测函数（使用指定接口）
check_network() {
    ping -I "$INTERFACE" -w5 -c1 "$TEST_HOST" >/dev/null 2>&1
    return $?
}

# 认证函数
authenticate() {
    local attempt="$1"
    local extra_param="$2"
    
    log_message "INFO" "Authentication attempt $attempt for $INTERFACE"
    
    # 构建认证数据
    local auth_data="userId=$userId&password=$password&service=$service&queryString=$queryString"
    if [ -n "$operatorPwd" ]; then
        auth_data="$auth_data&operatorPwd=$operatorPwd"
    fi
    if [ -n "$operatorUserId" ]; then
        auth_data="$auth_data&operatorUserId=$operatorUserId"
    fi
    if [ -n "$validcode" ]; then
        auth_data="$auth_data&validcode=$validcode"
    fi
    auth_data="$auth_data&passwordEncrypt=$passwordEncrypt"
    
    # 执行认证（使用指定接口）
    local url="$AUTH_URL"
    if [ -n "$extra_param" ]; then
        url="$url&$extra_param"
    fi
    
    curl -m10 -s --interface "$INTERFACE" -d "$auth_data" "$url" >/dev/null 2>&1
    return $?
}

# 主循环
while true; do
    if check_network; then
        log_message "DEBUG" "Interface $INTERFACE is online"
    else
        log_message "WARNING" "Interface $INTERFACE is offline, attempting reconnection"
        
        # 获取动态认证参数
        DYNAMIC_PARAM=$(curl -m5 -s --interface "$INTERFACE" "$TEST_HOST" 2>/dev/null | grep -oP "(?<=\\?).*(?=\\')" 2>/dev/null || echo "")
        
        # 首次认证尝试
        if authenticate "1" "$DYNAMIC_PARAM"; then
            sleep 2
            if check_network; then
                log_message "INFO" "Reconnection successful for $INTERFACE"
                continue
            fi
        fi
        
        # 重试机制
        reconnect=1
        while [ $reconnect -le $RETRY_MAX ]; do
            log_message "WARNING" "Reconnection attempt $reconnect/$RETRY_MAX failed for $INTERFACE"
            
            sleep 3
            if authenticate "$((reconnect + 1))" "$DYNAMIC_PARAM"; then
                sleep 2
                if check_network; then
                    log_message "INFO" "Reconnection successful for $INTERFACE (attempt $reconnect)"
                    break
                fi
            fi
            
            reconnect=$((reconnect + 1))
            sleep 2
        done
        
        if [ $reconnect -gt $RETRY_MAX ]; then
            log_message "ERROR" "Reconnection failed after $RETRY_MAX retries for $INTERFACE"
        fi
    fi
    
    sleep "$CHECK_INTERVAL"
done