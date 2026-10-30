---
name: bandastation-workflow
description: Work on BandaStation DM, tgui, maps and ports with task state and the build pipeline.
---

# Работа с BandaStation

Начни с [AGENTS.md](../../../AGENTS.md), [контекста](../../PROJECT_CONTEXT.md) и [правил работы](../../WORKFLOW_RULES.md). Для нескольких этапов выбери явный TaskId по [TASK_STATE](../../TASK_STATE.md).

Меняй только запрошенное поведение и необходимые для него места. Попутные рефакторы, переименования, форматирование и исправления соседних проблем не входят в задачу; рефактор допустим по прямому запросу либо при конкретной необходимости для её решения. Выбирай минимально достаточные проверки. Не добавляй и не расширяй тесты, если существующих проверок или точного ручного сценария достаточно; обязательные проверки проекта сохраняются.

Проследи entrypoint → include → вызовы → состояние → потребитель. Выбирай место правки по текущей реализации и задаче; сохраняй контракты вызовов, результата и побочных эффектов. Legacy-комментарии `SS220 EDIT` / `BANDASTATION EDIT` в новых правках не добавляй. Не добавляй комментарии об авторстве ИИ и границах агентских правок; используй Git diff.

Код-стайл: [STYLE](../../../.github/guides/STYLE.md), [STANDARDS](../../../.github/guides/STANDARDS.md), [AUTODOC](../../../.github/guides/AUTODOC.md). Проверяй реальные includes и потребителя, а не только наличие файла.

Сборка идёт через `tools/build/build.bat`. Для переводов редактируй TOML fragments, не generated `ru_names.toml`. Различай compile, targeted tests, DM runtime и веб-кадр. Весь diff к базе проверяй по контракту задачи.

Общие инструкции и утилиты версионируются; task state и машинный MCP config локальны. Установка и реальные MCP-проверки — [TOOLS](../../TOOLS.md). Перед коммитом: `tools/agents/repo/local-only.ps1 -Action check`, выбранные пути и `git diff --check`.
