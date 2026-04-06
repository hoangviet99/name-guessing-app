#!/bin/bash
# Lệnh 'trap' sẽ bắt tín hiệu khi script bị tắt
trap 'echo "Mock API đã bị tắt lúc $(date)" >> api_log.txt' EXIT
echo "API đang chạy giả lập lúc $(date)..." > api_log.txt
sleep 60
