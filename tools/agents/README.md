# Инструменты агентов

Команды выполняются из корня репозитория.

| Путь | Назначение |
| --- | --- |
| [setup-tools.ps1](setup-tools.ps1) | Установка MCP и генерация локального конфига; `-ConfigOnly` без установки зависимостей |
| [check.ps1](check.ps1) | Общая offline-проверка инструментария |
| [export-toolkit.ps1](export-toolkit.ps1) | Экспорт общего набора вне checkout |
| [setup/](setup/) | Реализация установщика |
| [tasks/](tasks/) | Создание, чтение и миграция локальных задач |
| [repo/](repo/) | Read-only инспектор репозитория и локальная Git-защита |
| [mcp/](mcp/) | MCP launchers, package locks и адаптер ripgrep |
| [lib/](lib/) | Общие PowerShell/Python функции и перенос набора |
| [tests/](tests/) | Проверка содержимого и сценарии инструментария/MCP |

Установка и MCP smoke — [TOOLS](../../.AGENTS/TOOLS.md), задачи — [TASK_STATE](../../.AGENTS/TASK_STATE.md), перенос — [PORTING](../../.AGENTS/PORTING.md). Зависимости и рабочие данные остаются вне версионируемых исходников.
