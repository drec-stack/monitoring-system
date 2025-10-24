#!/bin/bash

set -e

echo "Installing Process Monitoring System..."

# Проверяем права
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Проверяем зависимости
echo "Checking dependencies..."
for dep in curl pgrep systemctl; do
    if ! command -v "$dep" > /dev/null 2>&1; then
        echo "ERROR: Required dependency '$dep' is not installed"
        exit 1
    fi
done

# Создаем директории
echo "Creating directories..."
mkdir -p /usr/local/bin
mkdir -p /etc/monitoring
mkdir -p /var/lib/monitoring
mkdir -p /var/log

# Копируем скрипт
echo "Installing monitor script..."
cp scripts/process_monitor.sh /usr/local/bin/process_monitor
chmod 755 /usr/local/bin/process_monitor

# Копируем конфигурацию
echo "Installing configuration..."
if [ -f config/monitoring.conf ]; then
    cp config/monitoring.conf /etc/monitoring/
    chmod 600 /etc/monitoring/monitoring.conf
else
    # Создаем дефолтную конфигурацию
    cat > /etc/monitoring/monitoring.conf << 'EOF'
# Configuration for process monitoring
PROCESS_NAME="test"
MONITORING_URL="https://test.com/monitoring/test/api"
LOG_FILE="/var/log/monitoring.log"

# Curl settings
CURL_TIMEOUT=10
CURL_MAX_TIME=30
CURL_RETRY=2
EOF
    chmod 600 /etc/monitoring/monitoring.conf
fi

# Копируем systemd unit files
echo "Installing systemd services..."
cp systemd/process-monitor.service /etc/systemd/system/
cp systemd/process-monitor.timer /etc/systemd/system/

# Создаем log файл
touch /var/log/monitoring.log
chmod 644 /var/log/monitoring.log

# Перезагружаем systemd
echo "Reloading systemd..."
systemctl daemon-reload

# Включаем и запускаем timer
echo "Enabling and starting timer..."
systemctl enable process-monitor.timer
systemctl start process-monitor.timer

# Проверяем установку
echo "Verifying installation..."
if systemctl is-active process-monitor.timer > /dev/null; then
    echo "✅ Timer is active"
else
    echo "❌ Timer failed to start"
    exit 1
fi

echo ""
echo "🎉 Installation completed successfully!"
echo ""
echo "📊 Monitoring information:"
echo "   Service: process $PROCESS_NAME"
echo "   Monitoring URL: $MONITORING_URL"
echo "   Log file: /var/log/monitoring.log"
echo "   Config: /etc/monitoring/monitoring.conf"
echo ""
echo "🔧 Management commands:"
echo "   Check status: systemctl status process-monitor.timer"
echo "   View logs: journalctl -u process-monitor.service"
echo "   View monitoring log: tail -f /var/log/monitoring.log"
echo "   Manual run: systemctl start process-monitor.service"
echo ""
echo "⏰ The monitor will run every minute starting from next boot."