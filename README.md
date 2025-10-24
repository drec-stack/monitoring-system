[README.md](https://github.com/user-attachments/files/23130818/README.md)
# Process Monitoring System

Система мониторинга процесса `test` для Linux с автоматическим запуском и отправкой heartbeat на сервер мониторинга.

## Функциональность

- Запуск при загрузке системы
- Выполнение каждую минуту
- Проверка состояния процесса `test`
- Отправка heartbeat на HTTPS endpoint
- Логирование перезапусков процесса
- Логирование недоступности сервера мониторинга

## Установка

1. Клонируйте репозиторий:
```bash
git clone <your-repo-url>
cd monitoring-system
