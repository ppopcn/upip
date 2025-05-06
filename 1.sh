#!/bin/sh

# =========== 配置信息 ==========
API_TOKEN="I-mzLdFD4BWQBR5w0nWB11ZjVp0B2jK8zH-ehVEY"
ZONE_ID="6a6a82a82c8dec9990eee04f512fa955"
RECORD_ID="a08ab7eecd19d26d7c775480be37fc42"

RECORD_NAME="$1"
PROXIED=false

# 获取当前公网 IPv4 地址
IP=$(curl -s ipv4.ip.sb)

# 确保IP是合法的IPv4
if ! echo "$IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
  echo "$(date): 获取到的IP无效: $IP"
  exit 1
fi

echo "$(date): 当前公网IP是 $IP"

# 获取DNS记录当前IP
DNS_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
-H "Authorization: Bearer $API_TOKEN" \
-H "Content-Type: application/json" | grep -oE '"content":"[0-9\.]+"' | cut -d':' -f2 | tr -d '"')

if [ -z "$DNS_IP" ]; then
  echo "$(date): 获取DNS记录IP失败"
  exit 1
fi

# 比较IP
if [ "$IP" = "$DNS_IP" ]; then
  echo "$(date): IP无变化，当前IP是 $IP"
  exit 0
fi

# 构造完整JSON数据
cat <<EOF > /tmp/ddns_update.json
{
  "type": "A",
  "name": "$RECORD_NAME",
  "content": "$IP",
  "ttl": 120,
  "proxied": $PROXIED
}
EOF

# 更新DNS记录
UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
-H "Authorization: Bearer $API_TOKEN" \
-H "Content-Type: application/json" \
--data @/tmp/ddns_update.json)

# 检查更新结果
if echo "$UPDATE_RESULT" | grep -q '"success":true'; then
  echo "$(date): 成功更新IP为 $IP"
else
  echo "$(date): 更新失败，返回信息：$UPDATE_RESULT"
fi
