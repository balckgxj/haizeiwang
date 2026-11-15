#!/bin/bash
# 实时监控：客户端进程 / 新崩溃dump / 数据库新号数据
LOG="E:/PCGame/Haizeiwang/_tools/ab/monitor_ops.log"
MYSQL="E:/softwares/mysql-5.6.51-winx64/bin/mysql.exe"
DUMPS="C:/Users/24219/AppData/Local/CrashDumps"
echo "=== monitor start $(date '+%H:%M:%S') ===" >> "$LOG"
last_dump=""
last_db=""
for i in $(seq 1 720); do   # 最多 2 小时，每 10s 一轮
  ts=$(date '+%H:%M:%S')
  alive=$(tasklist 2>/dev/null | grep -ci haizeiwang)
  nd=$(ls -t "$DUMPS" 2>/dev/null | head -1)
  if [ "$nd" != "$last_dump" ] && [ -n "$nd" ]; then
    echo "[$ts] NEW CRASH DUMP: $nd" >> "$LOG"
    if [ -f "E:/PCGame/Haizeiwang/build/Debug/crash_stack.txt" ]; then
      echo "[$ts] crash_stack updated:" >> "$LOG"
      head -6 "E:/PCGame/Haizeiwang/build/Debug/crash_stack.txt" | sed 's/^/    /' >> "$LOG"
    fi
    last_dump="$nd"
  fi
  db=$("$MYSQL" -h127.0.0.1 -uroot -proot -D dzm -N -e "select concat(id,'|',puid,'|',name,'|lv',level) from player; " 2>/dev/null | tr '\n' ';')
  if [ "$db" != "$last_db" ] && [ -n "$db" ]; then
    echo "[$ts] DB change: $db" >> "$LOG"
    last_db="$db"
  fi
  echo "[$ts] client=$alive" >> "$LOG"
  sleep 10
done
echo "=== monitor end $(date '+%H:%M:%S') ===" >> "$LOG"
