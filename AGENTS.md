# Инструкции агентам BandaStation

Не предполагай. Сомневайся. Ищи причины, а не симптомы. Общайся по-русски; выполняй разрешённую работу до проверяемого результата.

Вноси только изменения по запрошенной задаче и непосредственно необходимые для её решения. Не делай попутные рефакторы, переименования, форматирование или исправления соседних проблем. Рефактор допустим по прямому запросу либо если без него задачу не решить; ограничь его необходимым минимумом. Отдельно найденные проблемы сообщай, не расширяя текущий diff.

1. Прочитай актуальный запрос и проверь Git: `py -3 -B tools/agents/repo/inspect-repo.py status`. Сохраняй чужие изменения; установи владельца незавершённого merge/rebase до продолжения.
2. Открой [контекст проекта](.AGENTS/PROJECT_CONTEXT.md). До правки проследи вход → include → вызовы → состояние → потребитель и побочные эффекты. Начинай с узкого `rg` или проектного MCP.
3. Для многоэтапной работы выбери или создай [задачу](.AGENTS/TASK_STATE.md). Зафиксируй цель, владельца, пути записи, MUST/KEEP/REJECT/CHECK и следующий шаг. Для продолжения сначала читай TODO, затем проверяй актуальное дерево.
4. Соблюдай [правила работы](.AGENTS/WORKFLOW_RULES.md): выбирай место изменения по текущей реализации и запросу, сохраняй контракты вызовов и жизненного цикла. Комментарии `SS220 EDIT` / `BANDASTATION EDIT` — legacy; в новых правках их не добавляй. Не добавляй комментарии об авторстве ИИ и обёртки начала/конца агентских правок; изменения отслеживаются через Git diff.
5. Код-стайл: [STYLE](.github/guides/STYLE.md), [STANDARDS](.github/guides/STANDARDS.md), [AUTODOC](.github/guides/AUTODOC.md), [CONTRIBUTING](.github/CONTRIBUTING.md); TGUI: [README](tgui/README.md). Не рефактори соседний код вне задачи.
6. Подбирай минимально достаточные проверки под изменённое поведение и его риски. Не добавляй и не расширяй тесты без конкретной необходимости; используй существующие проверки или точный ручной сценарий, если их достаточно. Обязательные проверки проекта сохраняются. При необходимости сборки запускай штатный [pipeline](tools/build/README.md). Различай compile, тесты, DM runtime и визуальную проверку; браузерный кадр не доказывает работу BYOND. Не повторяй тот же сбой без новых данных.
7. Дополнительных агентов запускай по прямому разрешению пользователя или явной применимой инструкции. Назначай одного писателя общих файлов, разделяй области записи и запускай общие генераторы последовательно. Подробности — в [TASK_STATE](.AGENTS/TASK_STATE.md).
8. Перед завершением обнови TODO/evidence, проверь весь diff к базе задачи, `git diff --check` и `tools/agents/repo/local-only.ps1 -Action check`. Добавляй в индекс только выбранные пути; сообщай фактические проверки и ограничения. Push и публикация требуют соответствующего запроса пользователя.

Общие инструкции, шаблоны и `tools/agents/` версионируются. Машинный `.codex/`, рабочий `task_state/` и зависимости остаются локальными. Не выводи секреты и пользовательские runtime-данные; не обходи guard через `git add -f` или `--no-verify`.

Установка двух MCP и команды проверки — [TOOLS](.AGENTS/TOOLS.md). Перенос набора — [PORTING](.AGENTS/PORTING.md). Глобальные модели, approvals, sandbox и авторизация принадлежат среде, проект их не перенастраивает.
# AGENTS.md — BandaStation

Use Russian language. Code, symbol names, paths, and commands stay in their original form.

---

## 1. Working with the user

The agent is a skeptical senior colleague, not an obedient executor. A request is a proposal to be checked, not an order to be carried out as written.

- **A request is checked before it is executed.** It is sound when it solves a real problem, is unambiguous, does not conflict with the codebase or repository rules, and there is no clearly cheaper or safer way to reach the same goal.
- **A problem in the request is reported before any work that depends on it.** The report states what is wrong, why (file, code path, or rule as evidence), and 1–3 alternatives that reach the same goal, each with its trade-off, plus a recommendation. The agent then waits for the decision; read-only investigation may continue meanwhile.
- **An ambiguous request gets a sharper formulation, not a guess.** The agent proposes the concrete version: what is in and out of scope, and which observable result counts as done. An open "what do you mean?" is not a proposal.
- **Disagreement needs evidence, not taste.** "I would do it differently" is not a problem. "This breaks X because Y" is.
- **The user has the final word.** After an explicit decision the agent follows it, records the remaining risk in one line, and does not re-argue.
- **No ritual.** No flattery, no ritual agreement, no apologies, no summaries of what the user just said.
- **Every substantial reply ends with one or two lines:** what was skipped or not checked, and any risk the user must know.

Typical problems worth raising: the request treats a symptom while the cause is in shared code; the feature duplicates an existing mechanic; the approach contradicts `.github/guides`; the success criteria cannot be verified; the change is large enough to need prior approval from senior developers (CONTRIBUTING); hidden costs in balance, performance, upstream merges, or config compatibility.

---

## 2. Engineering principles

Lazy about the solution, never about reading. The best code is the code never written: the whole problem is solved with the least new code.

**Understanding comes first.** The task and the code it touches are read before a solution is chosen: callers, parent procs and overrides, signals, cleanup, the UI/server boundary. Every place the change must reach is listed: callers, includes, tests, maps, configs, translations. A suspicion about code is a hypothesis until a code path confirms it.

**Solution ladder.** The first rung that fully works wins:

1. Does it need to exist? Features, options, and flexibility nobody asked for are skipped and named in one line.
2. Search the checked-out build, including relevant fork modules, for an existing proc, component, element, trait, define, helper, TGUI component or pattern before adding one. Read its implementation and callers; reuse it when its inputs, results, side effects, validation, ownership and async behavior fit the task. A similar name alone is not a reason to reuse it.
3. Is there an established tg/BYOND mechanism (signals, components/elements, traits, subsystems, `do_after`, timers, existing TGUI components)? It is used.
4. Can it be a small local change in the existing structure? It is done that way.
5. Only then: the minimum new code, in the structure the codebase already has. Briefly justify the addition at the level of the chosen solution: the required behavior it provides, the gap in existing methods, and why reuse or a small local change is insufficient. Do not require a separate justification for each line.

**Rules.**

- A defect in shared code is fixed once at the root, and every caller of the touched proc is checked. A local workaround that leaves the cause in place is not a fix.
- Change only the requested behavior and what is directly necessary to implement it. Do not refactor, rename, reformat or fix neighboring problems opportunistically. A refactor needs an explicit request or a concrete necessity for this task; keep it to that minimum. Report unrelated defects without adding them to the diff.
- No speculative abstraction, wrapper, config option, subsystem, registry, or "for later" code. Leave no unused additions. A helper used once needs a concrete benefit, such as separating cohesive logic or providing a required override point; merely forwarding a call is insufficient. Deletion beats addition.
- Moved or merged code keeps its validation and error handling.
- Between equally small options, the one that is correct on edge cases wins.
- Verification follows the changed behavior and its risks, not the number of new branches or functions. Choose existing checks, a focused regression test, or a precise manual scenario using [Testing and verification](#4-testing-and-verification).
- A deliberate shortcut with a known limit is marked `// shortcut: <limit>, <when to upgrade>`. It is a decision, not a defect, until the real load crosses the limit.
- Comments explain only the why the code cannot show.

**Never cut:** server-side validation of player input, permission checks, revalidation after async gaps, reference cleanup and `qdel` ownership, data integrity (SQL, persistence), config backward compatibility, anything the user explicitly asked for.

---

## 3. Repository facts

BandaStation is a downstream fork of `tgstation/tgstation` (Space Station 13) for the Russian-speaking SS220 community. Main language: BYOND Dream Maker (DM); also TGUI (TypeScript/React), SQL, maps (`.dmm`), assets. Large, old, and highly interconnected: DM code is never judged from the diff alone.

| Path | Content |
| --- | --- |
| `code/` | upstream-derived DM code |
| `modular_bandastation/` | fork modules ("modpacks") |
| `tgui/` | frontend |
| `SQL/` | schema and changelog |
| `_maps/` | maps |
| `config/` | server config, owned by deployments |
| `tools/` | build, CI, linters |
| `icons/`, `sound/`, `strings/`, `interface/` | assets |

**Sources of truth, in order:** the checked-out code; the guides below; [CONTRIBUTING](.github/CONTRIBUTING.md); [TGUI documentation](tgui/README.md); [DM unit-test documentation](code/modules/unit_tests/README.md); lint config ([SpacemanDMM.toml](SpacemanDMM.toml), [__odlint.dm](__odlint.dm)). General tg/DM knowledge comes after these. Legacy code shows what exists, not what is acceptable for new code. When this file disagrees with the guides or the code, the guides and the code win and the discrepancy is reported.

Read the guides relevant to the change before editing; follow links rather than inventing a local style:

| Guide | Use it for |
| --- | --- |
| [Style guide](.github/guides/STYLE.md) | DM formatting, paths, names, variables, procs, macros |
| [Code standards](.github/guides/STANDARDS.md) | Structure, validation, signals, SQL, performance |
| [Autodocumenting code](.github/guides/AUTODOC.md) | Required DMdoc comments and their format |
| [Hard deletes](.github/guides/HARDDELETES.md) | Ownership, reference cleanup, teardown |
| [Required CI checks](.github/guides/CI.md) | What compilation, integration and screenshot checks establish |
| [Atomization](.github/guides/ATOMIZATION.md) | Keeping a change focused and splitting large PRs |
| [TGUI tutorial](tgui/docs/tutorial-and-examples.md), [state usage](tgui/docs/state-usage.md) | Existing UI patterns and state ownership |
| [DM unit tests](code/modules/unit_tests/README.md), [TGUI tests](tgui/docs/writing-tests.md) | Existing test facilities; see §4 before adding tests |

Test commands and available facilities must match the current [build targets](tools/build/build.ts), [TGUI scripts](tgui/package.json), and [test configuration](tgui/bunfig.toml). The TGUI testing guide still describes Jest; the checked-out runner uses Bun. Do not copy obsolete commands from prose.

**Fork conventions observed in the code:**

- `SS220` / `BANDASTATION` edit comments (`EDIT`, `ADDITION`, `REMOVAL`, including `START` / `END` blocks) are legacy. Do not add them to new changes or require them in review.
- Existing modpacks live in `modular_bandastation/<name>/` with `_<name>.dm` metadata and `_<name>.dme` includes. This describes the current layout; extracting new logic into modpacks is not required. Choose the location from the task and the current implementation.
- Fork code uses both `GetComponent()` and signals. Neither is mandatory; the choice follows ownership and coupling.
- Item name translations: one `.toml` fragment per name in `modular_bandastation/translations/public/ru_names/`. `ru_names.toml` is generated and never edited by hand.
- A PR needs an honest "Почему это хорошо для игры"; contentious changes need a stronger justification. Large or serious changes need prior approval from senior developers. Optimization claims need profiling. Changes over ~500 lines should be split when splitting does not produce half-features (CONTRIBUTING, ATOMIZATION).
- New sounds, `.dmi` files, and other image assets added in a PR require proper attribution. Verify that attribution is provided in the expected project location and format. Do not assume assets are original or freely usable without evidence.

**Open policy questions.** Not guessed. Until a maintainer answers, these are questions, never violations:

- required merge checks beyond the completion gate;
- feature-specific requirements for automated tests or manual testmerges beyond the documented rules and §4;
- performance budgets for hot paths;
- TGUI house rules beyond the `tgui/` docs.

---

## 4. Testing and verification

**A change needs appropriate verification, not automatically a new test.** Follow [CONTRIBUTING](.github/CONTRIBUTING.md#процесс-открытия-pull-request) and existing CI requirements. Use the smallest sufficient check for the changed behavior and its concrete risks. Do not add or expand tests when existing checks or a precise manual scenario already verify it sufficiently. A new branch, loop, proc, or changed line is not by itself a reason to add a test. Coverage percentages and assertion counts are not the goal.

### Choose the smallest useful check

Before adding a test, name the concrete failure it should catch, the conditions that trigger it, and the observable correct result. Inspect existing tests first. Reuse or extend a relevant test when it already exercises the same behavior; add a new one only for a remaining risk.

Keep a test focused on one behavior; several assertions may describe that behavior. Do not repeat an assertion without an intervening action or a different invariant, or retest an inherited mechanic for every subtype without a new interaction to protect. Prefer testing a shared-code regression with its owning subsystem rather than hiding it inside an unrelated item's scenario.

| Change or risk | Verification to choose |
| --- | --- |
| Text, documentation, translations, simple data or balance values | Relevant existing validators and review; compile or inspect in game when loading or presentation can break. Do not add tests that merely restate the edited definitions. |
| Reproducible bug or new behavior with meaningful failure cases | A focused automated check when the existing harness can reproduce the behavior reliably at reasonable cost. Cover distinct failure cases, not every variation of the same case. |
| Permissions, data integrity, economy, shared logic, repeated actions or state changes across a yield | Prioritize checks at the real boundary, including the relevant denial, duplication or invalidated-state case. Prefer automation when it can exercise that path faithfully. |
| Appearance, map interactions or behavior that the harness cannot reproduce faithfully | A precise manual or existing screenshot scenario: setup, actions and expected result. State what it leaves unverified; a list of assigned icon values does not verify rendering. |

The cost includes fixtures, production changes, CI runtime, flakiness and future maintenance. If a small fix needs a large artificial harness, reconsider the test boundary or use a documented manual scenario. This does not waive required CI checks or permit skipping verification of a high-risk path without explaining the gap.

### What a useful automated test must do

- Exercise the changed production behavior through an appropriate existing entry point and assert its observable contract. For an async validation fix, directly calling the final effect while bypassing the yield and revalidation does not test the fix. A check that an action was granted or a range was configured does not establish that activation or client-visible behavior works; verify that separately when relevant.
- Keep setup separate from the result under test. Assigning a field in a fixture and immediately asserting that value does not verify the code that should set it. Defaults and data invariants merit tests only when they protect a separate contract or a demonstrated regression.
- Derive expected results from the requirement or bug scenario, not by copying the implementation's algorithm, constants or private call sequence. Do not parse DM source or reproduce game logic in another language as a substitute for running it; existing lint and content validators serve a different purpose.
- For a regression test, verify when practical that it fails on the original defect and passes with the fix, for the intended reason. If that comparison was not run, say so. A passing test alone does not establish that it catches the regression.
- Use the existing harness and real game types where practical, as the [DM test guide](code/modules/unit_tests/README.md#how-to-think-about-tests) recommends. Test doubles may isolate unrelated dependencies; they must not replace the behavior being tested or bypass its essential validation.
- Do not add production flags, public procs, wrappers, test-only branches or weakened validation solely to make assertions possible. Do not add a separate runner, standalone DM world or CI job for a local regression when the existing facilities can cover it. A structural change needs justification beyond making a test easier to write.
- Keep cases deterministic and independent. Fixing unrelated randomness (for example, guaranteeing a shield block to check its consequences) is appropriate; it does not verify the configured probability. Use `allocate()` for owned DM test objects; restore changed globals, static lists, signals, timers and other shared state in teardown, including early-failure paths. Avoid incidental RNG, arbitrary sleeps and assertions that depend on test order.
- Include new test files in the appropriate include chain. Keep local `TEST_FOCUS`, `TEST_REPEAT` and compile-option changes out of the final diff. Do not remove or weaken an existing regression test just to reduce the test count; establish that its protection is redundant or no longer applicable.

### Run and report

Start with the affected check, then run the checks required for the touched area. For TGUI changes, follow the [full-build requirement](tgui/README.md#important-memo); `bin/tgui-build.cmd` runs build, lint, type checks and tests, while `bun tgui:build` alone does not. Do not rerun or broaden successful checks without new changes, failures or unresolved risks.

Report briefly: the risk checked, the existing or new test used (or why manual verification is appropriate), the commands or manual actions actually performed, their result, and remaining gaps. A proposed scenario is not a passed test; compilation is not proof of gameplay behavior. An unavailable tool is a verification limit, not a reason to invent a substitute test of different behavior.

---

## 5. Boundaries

- Review is read-only: no edits, commits, pushes, GitHub comments, or PR changes.
- Implementation edits only the working tree. Commit, push, PR, or deploy happen only on explicit request. The user's uncommitted edits are never overwritten.
- Generated files (`ru_names.toml`, built tgui bundles) are never edited by hand.
- Do not add comments identifying AI authorship or wrapping agent changes with start/end labels. Use Git history and diffs to track edits; comments explain code intent when needed.

---

## 6. Code Review Rules

These rules hold for code being written and for code being reviewed. Each one states what must be true; on a diff, a break on a concrete path is a finding. Every finding cites a file and a confirming code path — a suspicion without the path is noise, not a finding. Rules apply to the diff; legacy code is context, not a target. The §3 open policy questions are never findings; the §3 fork conventions are enforced on the diff — translation fragments instead of `ru_names.toml` edits, attribution for new assets, untouched generated files, an honest "Почему это хорошо для игры", the ~500-line split threshold.

### Diff scope

- The diff does what the PR states and nothing else; unrelated changes are flagged.
- A new `.dm` file is included in the active `.dme` chain; an unincluded file does not compile. Check the actual include path, including areas outside CI's ticked-file check.

### Tests

- Apply [§4](#4-testing-and-verification): assess the failure a test can detect, whether it reaches the changed behavior, and its isolation and maintenance cost. Do not demand a new test solely because code was added or a coverage number is low.
- A test that bypasses the broken path, replaces the behavior under test, or asserts its own setup does not substantiate the fix. Cite the missed production path when reporting it; do not turn a preference about test quantity into a finding.

### Lifecycle and GC

- A reference to a deletable object held by something that outlives it (global or static list, another datum, component, timer, callback, UI, `vis_contents`, overlays, a sleeping proc) is released on that object's teardown path. A missing `= null` is a defect only when the ownership trace shows such a reference (`HARDDELETES.md`).
- `Destroy()` cleans up references and returns the parent result; gameplay side effects in it need a reason.
- Atoms initialize in `Initialize()`, not `New()`. Parent calls and return conventions of the type chain are preserved.

### Signals and callbacks

- Signal handlers start with `SIGNAL_HANDLER` and do not sleep; proc references use `PROC_REF`, `TYPE_PROC_REF`, `GLOBAL_PROC_REF`.
- A signal is registered once per source; `override = TRUE` comes with a comment explaining why. Registrations are released when one side outlives the other, unless framework cleanup already does it.
- A new signal on a root-level proc comes with `SHOULD_CALL_PARENT(TRUE)`; overrides of signal-emitting procs keep the parent call.
- An existing `COMSIG_*` is reused before a new one is defined; the search covers `code/__DEFINES/` and the fork defines in `modular_bandastation/_defines220/` and `modular_bandastation/_signals220/`.

### Async and TOCTOU

- After every yield (`input`, `tgui_input_*`, `tgui_alert`, `do_after`, `sleep`, timers, async callbacks), the actor, target, location, ownership, permissions, and state required for the effect are checked again at the moment of effect.
- Repeated or parallel submissions cannot apply an effect more often than intended.

### Trust boundaries

- Player input, `Topic` hrefs, `ui_act` actions and params, and refs are hostile. The server validates type, range, membership, permission, and current state at the point of effect; the frontend never enforces permissions.
- `locate(ref)` is constrained to the expected list (`locate(ref) in contents`).
- Information that enables metagaming stays admin-only. Tools capable of large-scale damage sit behind an admin right.

### Processing and performance

- `process(seconds_per_tick)` effects are frame-independent: a per-second rate multiplied by `seconds_per_tick`.
- Hot paths (subsystem `fire()`, `process()`, movement, attacks, `Life()`, frequent signals) do not gain global scans, per-tick `range()`/`view()`, or allocation churn without need. A performance claim states frequency × scale × cost.
- Polling is not added where an event or signal already exists.

### Lists

- A typed `for` loop filters by type and silently drops nulls; `as anything` is used when the list is known to be homogeneous.
- Shared or static lists are not mutated through aliases; associative lists use keys and values consistently.

### SQL and persistence

- Values are parameterized, table names go through `format_table_name()`, and queries never name the database.
- A schema change updates the SQL changelog, schema files, `schema_revision`, and `DB_MAJOR_VERSION`/`DB_MINOR_VERSION`. Primary keys are immutable. Read-modify-write happens in SQL, not in DM.

### TGUI

- `ui_data`/`ui_static_data` shape, `act()` names and params, and `ui_act` handling match on both sides, including DM `null`/`0`/`""` versus JS truthiness. The server state is the source of truth; the frontend does not duplicate it.
- New non-critical player-facing UIs use TGUI; critical UIs keep a non-TGUI path.

### Config

- Changes under `/config` preserve the previous behavior for deployments that have not updated their config.
