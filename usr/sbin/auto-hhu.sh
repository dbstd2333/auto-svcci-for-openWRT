#!/bin/sh
chmod +x /overlay/upper/usr/sbin/auto-hhu.sh
# 校园网自动重连脚本（优化版）
# 配置文件默认路径，可通过脚本参数指定（如 ./auto-hhu.sh /path/to/conf.conf）
CONF_FILE="${1:-/etc/auto-hhu.conf}"
# 日志文件路径
LOG_FILE="/tmp/auto-hhu.log"
# 网络检测目标（可替换为校园网网关，如 172.19.1.1）
TEST_HOST="baidu.com"
# 认证接口（统一为校园网实际接口，需根据自身情况调整）
AUTH_URL="http://eportal.hhu.edu.cn/eportal/InterFace.do?method=login"
# 重试次数上限
RETRY_MAX=5


# 1. 配置文件校验
if [[ ! -f "$CONF_FILE" ]]; then
    echo "ERROR: Configuration file not found at $CONF_FILE!"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ERROR: Configuration file not found at $CONF_FILE" >> "$LOG_FILE"
    exit 1  # 错误退出（状态码1）
else
    # 加载配置（避免环境变量污染，用局部变量）
    source "$CONF_FILE"
fi

# 2. 配置参数校验
if [ -z "$userId" -o -z "$password" -o -z "$service" -o -z "$queryString" -o -z "$passwordEncrypt" ]; then
    echo "ERROR: Required parameters (userId/password/service/queryString/passwordEncrypt) not set in $CONF_FILE"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ERROR: Required parameters missing in $CONF_FILE" >> "$LOG_FILE"
    exit 1
fi

# 3. 主循环：持续检测网络并重连
while true; do
    # 检测网络连通性（1个包，5秒超时，避免卡住）
    ping -w5 -c1 "$TEST_HOST" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        # 在线：记录信息，5秒后再次检测
        echo "INFO: Still online, next check in 5 seconds"
    else
        # 离线：进入重连流程
        echo "WARNING: Offline, trying to reconnect (1st attempt)..."
        echo "[$(date +"%Y-%m-%d %H:%M:%S")] WARNING: Offline, 1st reconnect attempt" >> "$LOG_FILE"

        # 提取动态认证参数（curl超时5秒，失败则用空参数重试）
        DYNAMIC_PARAM=$(curl -m5 -s "$TEST_HOST" | grep -oP "(?<=\?).*(?=\')" 2>/dev/null)
        # 首次重连（带完整参数：userId/password/service/等）
        curl -m5 -s -d "userId=$userId&password=$password&service=$service&queryString=$queryString&operatorPwd=$operatorPwd&operatorUserId=$operatorUserId&validcode=$validcode&passwordEncrypt=$passwordEncrypt" \
            "$AUTH_URL" >/dev/null 2>&1
        # 重连后检测是否成功
        sleep 2  # 等待认证生效
        ping -w5 -c1 "$TEST_HOST" >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "INFO: Reconnection successful (1st attempt)"
            echo "[$(date +"%Y-%m-%d %H:%M:%S")] INFO: Reconnection successful (1st attempt)" >> "$LOG_FILE"
        else
            # 首次失败：进入多次重试
            reconnect=1
            while [[ $reconnect -le $RETRY_MAX ]]; do
                echo "WARNING: Reconnection failed ($reconnect/$RETRY_MAX), retrying in 5 seconds..."
                echo "[$(date +"%Y-%m-%d %H:%M:%S")] WARNING: Reconnect failed ($reconnect/$RETRY_MAX), retry after 5s" >> "$LOG_FILE"
                
                # 重试（与首次重连参数一致，避免接口不匹配）
                curl -m5 -s -d "userId=$userId&password=$password&service=$service&queryString=$queryString&operatorPwd=$operatorPwd&operatorUserId=$operatorUserId&validcode=$validcode&passwordEncrypt=$passwordEncrypt" \
                    "$AUTH_URL&$DYNAMIC_PARAM" >/dev/null 2>&1

                # 检测重试结果
                sleep 3
                ping -w5 -c1 "$TEST_HOST" >/dev/null 2>&1
                if [[ $? -eq 0 ]]; then
                    echo "INFO: Reconnection successful ($reconnect/$RETRY_MAX)"
                    echo "[$(date +"%Y-%m-%d %H:%M:%S")] INFO: Reconnection successful ($reconnect/$RETRY_MAX)" >> "$LOG_FILE"
                    break  # 成功则跳出重试循环
                fi

                let reconnect++
                sleep 2  # 避免频繁重试，总间隔5秒（3秒等待+2秒休眠）
            done

            # 重试耗尽：报错退出
            if [[ $reconnect -gt $RETRY_MAX ]]; then
                echo "ERROR: Reconnection failed after $RETRY_MAX retries. Check credentials/network!"
                echo "[$(date +"%Y-%m-%d %H:%M:%S")] ERROR: Reconnect failed after $RETRY_MAX retries (check userId/password/network)" >> "$LOG_FILE"
                exit 1
            fi
        fi
    fi

    sleep 5  # 每次检测间隔5秒
done

# 正常退出（理论上不会执行到这里，因while true是无限循环）
exit 0