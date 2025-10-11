# Automatical HHU network authentication tool for OpenWrt

用于OpenWrt的河海校园网自动认证工具，无需Python等环境要素，理论上可以适用于其他使用锐捷ePortal方式认证的校园网络环境 仅支持OpenWrt
--
# 如何使用？
0、确保你的Openwrt网关设备具有至少300KiB左右的空闲空间，这将用来安装独立的全功能grep和opkg，及其对应的依赖libcurl等，auto-whu本身只占用约1KiB空间

1、安装依赖grep和curl，你的OpenWrt网关此时必须已经联网（由于校园网对路由设备弱检测，你可以使用连接在网关上的带有图形界面的设备参照直接连接到校园网时那样认证，完成后即可直接上网）

````
opkg update
opkg install grep curl
````

2、断开你的SSH连接并重新连接，这是因为OpenWrt默认的grep和curl是BusyBox中的，默认的Shell ASH也是BusyBox中的，会话必须重启以保证独立的全功能grep和curl能被识别到

3、下载Release内的autohhu.tar.gz文件，上传到/tmp目录，或直接在路由器上使用以下命令下载到/tmp目录下：
````
wget https://github.com/CodeFromInterest/auto-hhu-for-openWRT/releases/download/v1.0/auto-hhu.tar.gz -O /tmp/auto-hhu.tar.gz
````
4、运行以下命令解压：
````
cd /
##上一步为进入根目录，如果你已经在根目录了，则不需要
tar -xvzf /tmp/auto-hhu.tar.gz
````

5、修改/etc/auto-hhu.conf，将其中的userId和password修改为你的账号和密码。其他选项中，如果你的校园手机卡运营商为中国移动，请不要修改service的内容，queryString的内容需要你根据下面这个视频【【Mac/Windows/Linux通用】如何使用一个小工具自动连接锐捷认证校园网-哔哩哔哩】 https://b23.tv/ABU8zIY
````
vi /etc/auto-whu.conf
````
6、执行auto-hhu.sh来测试
````
chmod +x /overlay/upper/usr/sbin/auto-hhu.sh # 用于授权auto-hhu.sh
auto-hhu.sh 
````
7、尝试到 http://eportal.hhu.edu.cn/eportal/success.jsp? 断开当前路由器的连接，如果auto-hhu.sh输出以下结果，则功能正常
````
WARNING: Check failed, offline, trying to reconnect
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   514  100   514    0     0  32125      0 --:--:-- --:--:-- --:--:-- 36714
INFO: (Re)connection successful
INFO: Still online, next check in 5 seconds
````
8、使用Crtl+C退出auto-hhu.sh

9、启动auto-hhu后台进程并设置其自启动
````
/etc/init.d/auto-hhu start
/etc/init.d/auto-hhu enable
````

--

参考文献

https://github.com/7Ji/auto-whu-openwrt
