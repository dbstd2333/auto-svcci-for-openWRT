# 校园网多播认证使用说明

## 功能介绍

本方案支持在OpenWRT路由器上同时运行多个校园网认证实例，实现多账号负载均衡和故障转移。

## 文件结构

```
/etc/auto-hhu-template.conf      # 配置文件模板
/etc/auto-hhu-wan1.conf          # 接口1认证配置
/etc/auto-hhu-wan2.conf          # 接口2认证配置
/etc/init.d/auto-hhu-multi       # 服务管理脚本
/usr/sbin/auto-hhu-multi.sh      # 多播认证主脚本
/usr/sbin/auto-hhu-test.sh       # 测试脚本
```

## 快速开始

### 1. 配置认证信息

编辑配置文件，填入正确的学号和密码：

```bash
cp /etc/auto-hhu-template.conf /etc/auto-hhu-wan1.conf
vim /etc/auto-hhu-wan1.conf
```

### 2. 测试配置

运行测试脚本验证配置是否正确：

```bash
/usr/sbin/auto-hhu-test.sh wan1
```

### 3. 启动服务

使用服务管理脚本启动多播认证：

```bash
/etc/init.d/auto-hhu-multi start
```

### 4. 查看状态

```bash
/etc/init.d/auto-hhu-multi status
```

## 高级配置

### 多接口配置

如果要使用多个接口，需要：

1. 创建对应的配置文件：
   ```bash
   cp /etc/auto-hhu-template.conf /etc/auto-hhu-wan2.conf
   vim /etc/auto-hhu-wan2.conf
   ```

2. 编辑服务管理脚本，添加接口到 INTERFACES 变量：
   ```bash
   vim /etc/init.d/auto-hhu-multi
   # 修改这一行：
   INTERFACES="wan1 wan2 wan3"
   ```

### 与mwan3集成

1. 安装mwan3：
   ```bash
   opkg update
   opkg install mwan3
   ```

2. 配置mwan3负载均衡：
   ```bash
   vim /etc/config/mwan3
   ```

3. 添加接口配置：
   ```
   config interface 'wan1'
       option enabled '1'
       option initial_state 'online'
       
   config interface 'wan2'
       option enabled '1'
       option initial_state 'online'
   ```

## 命令参考

### 服务管理

```bash
# 启动所有实例
/etc/init.d/auto-hhu-multi start

# 停止所有实例
/etc/init.d/auto-hhu-multi stop

# 重启所有实例
/etc/init.d/auto-hhu-multi restart

# 查看状态
/etc/init.d/auto-hhu-multi status
```

### 手动运行

```bash
# 运行单个实例（调试用）
/usr/sbin/auto-hhu-multi.sh wan1 /etc/auto-hhu-wan1.conf

# 测试配置
/usr/sbin/auto-hhu-test.sh wan1
```

### 日志查看

```bash
# 查看特定接口日志
tail -f /tmp/auto-hhu-wan1.log

# 查看所有接口日志
tail -f /tmp/auto-hhu-*.log
```

## 故障排除

### 常见问题

1. **认证失败**
   - 检查学号和密码是否正确
   - 确认网络接口名称正确
   - 查看日志文件获取详细信息

2. **接口不存在**
   - 使用 `ip link show` 查看可用接口
   - 确认OpenWRT网络配置正确

3. **服务无法启动**
   - 检查脚本是否有执行权限
   - 确认配置文件存在且格式正确

### 调试方法

1. **手动运行调试**：
   ```bash
   sh -x /usr/sbin/auto-hhu-multi.sh wan1
   ```

2. **检查网络连通性**：
   ```bash
   ping -I wan1 baidu.com
   ```

3. **检查认证服务器**：
   ```bash
   curl -I --interface wan1 http://eportal.hhu.edu.cn
   ```

## 性能优化

### 调整检查间隔

编辑主脚本，修改 CHECK_INTERVAL 参数：
```bash
CHECK_INTERVAL=5  # 默认5秒，可根据需要调整
```

### 优化重试次数

```bash
RETRY_MAX=5  # 认证失败重试次数
```

### 负载均衡策略

配合mwan3使用，可以实现：
- 带宽叠加
- 故障转移
- 流量分担

## 安全提醒

- 妥善保管账号密码
- 定期更换密码
- 不要在公共网络暴露配置
- 合理分配带宽，避免影响他人使用

## 更新日志

- v1.0: 基础多播认证功能
- 支持多接口同时认证
- 集成mwan3负载均衡
- 健康检查和自动重启