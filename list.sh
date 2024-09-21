#!/bin/bash

# 将 ACCOUNTS 转换为数组
IFS=';' read -r -a ACCOUNTS_array <<< "$ACCOUNTS"

# 创建一个临时文件来存储所有的 list.txt 内容
TEMP_FILE=$(mktemp)

# 初始化计数器
success_count=0
failure_count=0
failed_users=()

# 循环处理每组数据
for ACCOUNT in "${ACCOUNTS_array[@]}"; do
  IFS=' ' read -r -a credentials <<< "$ACCOUNT"
  SERVER=${credentials[0]}
  USERNAME=${credentials[1]}
  PASSWORD=${credentials[2]}

  echo "使用 $USERNAME 登录 $SERVER"

  # 创建 SSH 连接并运行命令
  sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no $USERNAME@$SERVER <<EOF
    echo "$USERNAME登录成功"
    #读取节点信息
    cat ./domains/$USERNAME.serv00.net/logs/list.txt
    exit
EOF
  if [ $? -eq 0 ]; then
    success_count=$((success_count + 1))
  else
    failure_count=$((failure_count + 1))
    failed_users+=("$USERNAME@$SERVER")
  fi
done >> $TEMP_FILE

#发送通知到 Telegram
echo "发送登录结果"
message="登录完成，登录成功$success_count，登录失败$failure_count。"
if [ $failure_count -gt 0 ]; then
  message="$message 失败账户${failed_users[*]}"
else
  message="$message 全部登录成功！"
fi


curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage -d chat_id=$TELEGRAM_USER_ID -d text="$message"

#发送节点信息
grep -E '(vmess|hysteria2|tuic)://' $TEMP_FILE > list.txt

# 上传 list.txt
curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument -F chat_id=$TELEGRAM_USER_ID -F document=@list.txt
# 删除临时文件
rm $TEMP_FILE
rm list.txt
