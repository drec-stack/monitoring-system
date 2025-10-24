#!/bin/bash

# Конфигурация
CONFIG_FILE="/etc/monitoring/monitoring.conf"
LOG_FILE="/var/log/monitoring.log"
PID_FILE="/var/run/monitoring.pid"
PROCESS_NAME="test"
MONITORING_URL="https://test.com/monitoring/test/api"
STATE_FILE="/var/lib/monitoring/process_state"

# Загрузка конфигурации
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Создаем необходимые директории
mkdir -p /var/lib/monitoring
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$PID_FILE")"

# Функция логирования
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Функция проверки доступности сервера мониторинга
check_monitoring_server() {
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --retry 2 "$MONITORING_URL" | grep -q "200"; then
        return 0
    else
        return 1
    fi
}

# Функция проверки процесса
check_process() {
    if pgrep -x "$PROCESS_NAME" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Функция отправки heartbeat
send_heartbeat() {
    local timestamp=$(date -Iseconds)
    local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "User-Agent: ProcessMonitor/1.0" \
        -d "{\"process\": \"$PROCESS_NAME\", \"timestamp\": \"$timestamp\", \"status\": \"running\"}" \
        --connect-timeout 10 \
        --max-time 30 \
        --retry 2 \
        --retry-delay 1 \
        "$MONITORING_URL" 2>/dev/null)
    
    if [ "$response" = "200" ] || [ "$response" = "201" ] || [ "$response" = "202" ]; then
        return 0
    else
        log_message "ERROR: Monitoring server returned HTTP $response for URL: $MONITORING_URL"
        return 1
    fi
}

# Функция сохранения состояния процесса
save_process_state() {
    local state=$1
    echo "$state" > "$STATE_FILE"
}

# Функция загрузки предыдущего состояния
load_process_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "unknown"
    fi
}

# Основная логика
main() {
    # Защита от множественного запуска
    if [ -f "$PID_FILE" ]; then
        if ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
            log_message "WARNING: Monitoring script is already running (PID: $(cat "$PID_FILE"))"
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    echo $$ > "$PID_FILE"
    trap 'rm -f "$PID_FILE"; exit 0' TERM INT EXIT
    
    local previous_state=$(load_process_state)
    local current_state="unknown"
    
    # Проверяем текущее состояние процесса
    if check_process; then
        current_state="running"
        log_message "DEBUG: Process $PROCESS_NAME is running"
        
        # Если процесс был запущен и сервер мониторинга доступен
        if check_monitoring_server; then
            if send_heartbeat; then
                log_message "INFO: Heartbeat sent successfully for process $PROCESS_NAME"
            else
                log_message "ERROR: Failed to send heartbeat for process $PROCESS_NAME"
            fi
        else
            log_message "ERROR: Monitoring server is not accessible"
        fi
        
        # Логируем перезапуск если предыдущее состояние было "not running"
        if [ "$previous_state" = "not_running" ]; then
            log_message "INFO: Process $PROCESS_NAME was restarted"
        fi
        
    else
        current_state="not_running"
        log_message "DEBUG: Process $PROCESS_NAME is not running"
        
        # Логируем остановку если процесс был запущен
        if [ "$previous_state" = "running" ]; then
            log_message "INFO: Process $PROCESS_NAME has stopped"
        fi
    fi
    
    # Сохраняем текущее состояние для следующей итерации
    save_process_state "$current_state"
}

# Проверяем зависимости
check_dependencies() {
    local deps=("curl" "pgrep" "tee")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" > /dev/null 2>&1; then
            log_message "ERROR: Required dependency '$dep' is not installed"
            exit 1
        fi
    done
}

# Главная точка входа
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

check_dependencies
main