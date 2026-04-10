---
name: notify-team
description: Notify engineering teams about process changes via Mattermost. Analyzes git diff, composes a message with CF links, validates with user before sending.
user_invocable: true
auto_activate: false
---

# Notify Team

Оповещение команд об изменениях процессов в канале Mattermost.

## When to Activate

**ONLY** when the user explicitly invokes `/notify-team`.

Do NOT activate this skill automatically, proactively, or as part of other workflows. Never suggest running this skill unless the user asks about notifying teams.

## Algorithm

### Step 1: Определить диапазон изменений

1. Read the config file `.claude/notify-team.json`
2. **If config exists and has `last_notified_commit`:**
   - Run `git diff <last_notified_commit>..HEAD --name-only -- processes/` to get changed files
   - If no changes found — report "Нет изменений с последнего оповещения" and stop
3. **If config does not exist (first run):**
   - All non-private files in `processes/` are treated as "new"
   - This is the baseline notification

### Step 2: Анализ изменений

For each changed file in `processes/`:

1. **Exclude** any file where `private` appears in the path — do not mention these files at all
2. **Exclude** `_index.md` files — they are overview pages, not standalone processes
3. Get the diff for each file:
   - If config exists: `git diff <last_notified_commit>..HEAD -- <file>`
   - If first run: read the full file content (everything is "new")
4. Analyze the diff and compose a **short summary of changes** in Russian, engineering style:
   - Each change = 1 bullet point, understandable without extra context
   - Focus on **what changed for engineers**, not cosmetic edits
   - Examples: "Квота техдолга изменена с 15% на 20%", "Добавлен раздел: декомпозиция задач > 13 SP", "Ревью техдолга перенесено из отдельного ритуала в блок на груминге"
   - For new processes: "**Новый процесс.** <1-sentence description>"
5. Group changes by process (file)

### Step 3: Собрать ссылки на Confluence

For each changed process file:

1. Look up `confluence_page_id` in `.claude/confluence-sync.json`
2. If page exists — construct CF URL: `https://cf.avito.ru/pages/viewpage.action?pageId={page_id}`
3. If specific sections changed — call `paas_confluence_get_heading_links(url=<page_url>, query=<heading_text>)` to get anchor links to those sections
4. If page does NOT exist in config (not yet synced) — note "(не опубликован в CF)" next to the process name

### Step 4: Сформировать черновик сообщения

Compose the message in Mattermost markdown format:

```
#### 📋 Обновления процессов

**<Process Name>** ([подробнее](<cf-url>))
- Change 1
- Change 2: [раздел](<cf-url#anchor>)

**<Process Name 2>** ([подробнее](<cf-url>))
- Change 1

---
_Вопросы и предложения — в тред к этому сообщению._
```

Rules:
- Language: Russian, engineering style, no bureaucratic language
- Each change: 1 line, self-contained, understandable without context
- Include CF links: to the process page + to specific sections where relevant
- New processes are marked with "**Новый процесс.**"
- Never mention private files or their contents
- Keep the message concise — engineers won't read a wall of text

### Step 5: Валидация (ОБЯЗАТЕЛЬНО)

**MANDATORY: NEVER send without explicit user confirmation.**

Show the composed message to the user using AskUserQuestion:
- Display the full message text
- Options: "Отправить" / "Отменить"
- If user chooses "Отменить" — stop immediately, do not send
- If user provides corrections via "Other" — apply edits and show the updated message again for another round of validation

This step CANNOT be skipped under any circumstances.

### Step 6: Отправка

1. Call `paas_mattermost_post_message(channel="7b9sjc9uspb6xd54nrxh4zxfny", message=<validated_text>)`
2. Get the current HEAD commit hash: `git rev-parse HEAD`
3. Update (or create) `.claude/notify-team.json`:
   ```json
   {
     "channel_id": "7b9sjc9uspb6xd54nrxh4zxfny",
     "last_notified_commit": "<HEAD hash>"
   }
   ```
4. Report: "Отправлено в #it-platform-core"

## Config file

File: `.claude/notify-team.json`

```json
{
  "channel_id": "7b9sjc9uspb6xd54nrxh4zxfny",
  "last_notified_commit": "6f886f8abc123..."
}
```

- `channel_id`: Mattermost channel ID
- `last_notified_commit`: git commit hash at the time of last notification (used to diff for next notification)
