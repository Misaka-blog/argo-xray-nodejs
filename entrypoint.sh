#!/usr/bin/env bash

# 设置各变量
UUID='de04add9-5c68-8bab-950c-08cd5320df18'
VMESS_WSPATH='/vmess'
VLESS_WSPATH='/vless'
TROJAN_WSPATH='/trojan'
SS_WSPATH='/shadowsocks'
NEZHA_SERVER="probe.nezha.org"
NEZHA_PORT=5555
NEZHA_KEY="p2RYaBPrCEiFro7W0Y"

# 安装系统依赖
check_dependencies() {
  DEPS_CHECK=("wget" "unzip")
  DEPS_INSTALL=(" wget" " unzip")
  for ((i=0;i<${#DEPS_CHECK[@]};i++)); do [[ ! $(type -p ${DEPS_CHECK[i]}) ]] && DEPS+=${DEPS_INSTALL[i]}; done
  [ -n "$DEPS" ] && { apt-get update >/dev/null 2>&1; apt-get install -y $DEPS >/dev/null 2>&1; }
}

generate_config() {
  cat > config.json << EOF
{
    "log": {
        "access": "/dev/null",
        "error": "/dev/null",
        "loglevel": "none"
    },
    "inbounds": [
        {
            "port": 8080,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "flow": "xtls-rprx-direct"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 3001
                    },
                    {
                        "path": "${VLESS_WSPATH}",
                        "dest": 3002
                    },
                    {
                        "path": "${VMESS_WSPATH}",
                        "dest": 3003
                    },
                    {
                        "path": "${TROJAN_WSPATH}",
                        "dest": 3004
                    },
                    {
                        "path": "${SS_WSPATH}",
                        "dest": 3005
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp"
            }
        },
        {
            "port": 3001,
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none"
            }
        },
        {
            "port": 3002,
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "level": 0
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "${VLESS_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ],
                "metadataOnly": false
            }
        },
        {
            "port": 3003,
            "listen": "127.0.0.1",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "${VMESS_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ],
                "metadataOnly": false
            }
        },
        {
            "port": 3004,
            "listen": "127.0.0.1",
            "protocol": "trojan",
            "settings": {
                "clients": [
                    {
                        "password": "${UUID}"
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "${TROJAN_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ],
                "metadataOnly": false
            }
        },
        {
            "port": 3005,
            "listen": "127.0.0.1",
            "protocol": "shadowsocks",
            "settings": {
                "clients": [
                    {
                        "method": "chacha20-ietf-poly1305",
                        "password": "${UUID}"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "${SS_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ],
                "metadataOnly": false
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        },
        {
            "tag": "WARP",
            "protocol": "wireguard",
            "settings": {
                "secretKey": "GAl2z55U2UzNU5FG+LW3kowK+BA/WGMi1dWYwx20pWk=",
                "address": [
                    "172.16.0.2/32",
                    "2606:4700:110:8f0a:fcdb:db2f:3b3:4d49/128"
                ],
                "peers": [
                    {
                        "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                        "endpoint": "engage.cloudflareclient.com:2408"
                    }
                ]
            }
        }
    ],
    "routing": {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "type": "field",
                "domain": [
                    "domain:openai.com",
                    "domain:ai.com"
                ],
                "outboundTag": "WARP"
            }
        ]
    },
    "dns": {
        "server": [
            "8.8.8.8",
            "8.8.4.4"
        ]
    }
}
EOF
}

generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash
  
# 下载并运行 Argo
check_file() {
  [ ! -e cloudflared ] && wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared
}

run() {
  if [[ -e cloudflared && ! \$(ss -nltp) =~ cloudflared ]]; then
    chmod +x ./cloudflared && ./cloudflared tunnel --url http://localhost:8080 --no-autoupdate > argo.log 2>&1 &
    sleep 10
    ARGO=\$(cat argo.log | grep -oE "https://.*[a-z]+cloudflare.com" | sed "s#https://##")
    VMESS="{ \"v\": \"2\", \"ps\": \"Argo_xray_vmess\", \"add\": \"icook.hk\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARGO}\", \"path\": \"${VMESS_WSPATH}?ed=2048\", \"tls\": \"tls\", \"sni\": \"\${ARGO}\", \"alpn\": \"\" }"
    
    cat > list << EOF
<html>
<head>
<title>Argo-xray</title>
<style type="text/css">
body {
	  font-family: Geneva, Arial, Helvetica, san-serif;
    }
div {
	  margin: 0 auto;
	  text-align: left;
      white-space: pre-wrap;
      word-break: break-all;
      max-width: 80%;
	  margin-bottom: 10px;
}
</style>
</head>
<body bgcolor="#FFFFFF" text="#000000">
<div><font color="#009900"><b>VMESS协议链接：</b></font></div>
<div>vmess://\$(echo \$VMESS | base64 -w0)</div>
<div><font color="#009900"><b>VLESS协议链接：</b></font></div>
<div>vless://${UUID}@icook.hk:443?encryption=none&security=tls&sni=\${ARGO}&type=ws&host=\${ARGO}&path=${VLESS_WSPATH}?ed=2048#Argo_xray_vless</div>
<div><font color="#009900"><b>TROJAN协议链接：</b></font></div>
<div>trojan://${UUID}@icook.hk:443?security=tls&sni=\${ARGO}&type=ws&host=\${ARGO}&path=${TROJAN_WSPATH}?ed=2048#Argo_xray_trojan</div>
<div><font color="#009900"><b>SS协议明文：</b></font></div>
<div>服务器地址：icook.hk</div>
<div>端口：443</div>
<div>密码：${UUID}</div>
<div>加密方式：chacha20-ietf-poly1305</div>
<div>传输协议：ws</div>
<div>host：\${ARGO}</div>
<div>path路径：$SS_WSPATH?ed=2048</div>
<div>TLS：开启</div>
</body>
</html>
EOF
    cat list
  fi
}

check_file
run
wait
ABC
}

generate_nezha() {
  cat > nezha.sh << EOF
#!/usr/bin/env bash

# 哪吒的三个参数
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}

# 检测是否已运行
check_run() {
  [[ \$(pidof nezha-agent) ]] && echo "哪吒客户端正在运行中" && exit
}

# 三个变量不全则不安装哪吒客户端
check_variable() {
  [[ -z "\${NEZHA_SERVER}" || -z "\${NEZHA_PORT}" || -z "\${NEZHA_KEY}" ]] && exit
}

# 下载最新版本 Nezha Agent
download_agent() {
  if [ ! -e nezha-agent ]; then
    URL=\$(wget -qO- -4 "https://api.github.com/repos/naiba/nezha/releases/latest" | grep -o "https.*linux_amd64.zip")
    wget -t 2 -T 10 -N \${URL}
    unzip -qod ./ nezha-agent_linux_amd64.zip && rm -f nezha-agent_linux_amd64.zip
  fi
}

# 运行客户端
run() {
  [[ ! \$PROCESS =~ nezha-agent && -e nezha-agent ]] && chmod +x ./nezha-agent && ./nezha-agent -s \${NEZHA_SERVER}:\${NEZHA_PORT} -p \${NEZHA_KEY}
}

check_run
check_variable
download_agent
run
wait
EOF
}

check_dependencies
generate_config
generate_argo
generate_nezha
[ -e nezha.sh ] && bash nezha.sh 2>&1 &
[ -e argo.sh ] && bash argo.sh 2>&1 &
wait