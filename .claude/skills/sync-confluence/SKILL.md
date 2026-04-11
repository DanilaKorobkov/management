---
name: sync-confluence
description: Sync process documents from processes/*.md to Confluence pages in the MIS space. Only runs when explicitly invoked via /sync-confluence.
user_invocable: true
auto_activate: false
---

# Sync Confluence

Синхронизация процессов из `processes/*.md` в Confluence (пространство MIS).

## When to Activate

**ONLY** when the user explicitly invokes `/sync-confluence` or `/sync-confluence <filename>`.

Do NOT activate this skill automatically, proactively, or as part of other workflows. Never suggest running this skill unless the user asks about Confluence sync.

## Algorithm

### Step 1: Collect files

1. Find all `processes/**/*.md` files using Glob pattern `processes/**/*.md`
2. **Exclude** any file where the word `private` appears anywhere in the path (file name or folder name). Examples of excluded paths:
   - `processes/private-notes.md`
   - `processes/feature-requests.private.md`
   - `processes/private/draft.md`
   - `processes/my-private-process.md`
3. If the user passed an argument (e.g. `/sync-confluence tech-debt.md`), filter to only files matching that argument
4. Read the config file `.claude/confluence-sync.json`

### Step 2: Build action plan and get confirmation

For each collected file, determine the action:

- **File path contains `private`**: action = "skip (private)"
- **File exists in config** (has `confluence_page_id`):
  1. Compute SHA-256 hash of the file content: `shasum -a 256 <file>`
  2. Compare with `last_synced_hash` from config
  3. If hashes match — action = "skip (unchanged)"
  4. If hashes differ or `last_synced_hash` is absent — action = "update"
- **File NOT in config**: action = "create"

**MANDATORY: Before making ANY changes to Confluence, show the user a summary table and ask for explicit confirmation using AskUserQuestion:**

Example table to show:

| File | Action | CF Page |
|------|--------|---------|
| processes/tech-debt.md | Update | 842230766 |
| processes/new-process.md | Create new page | - |
| processes/unchanged.md | Skip (unchanged) | 842230770 |
| processes/private-draft.md | Skip (private) | - |

Ask: "Proceed with sync?" with options "Yes, sync" / "Cancel".

If the user cancels — stop immediately, make no changes.

### Step 3: Process each confirmed file

For each file (in order):

#### 3a. Read the markdown file

Read the full content of the file.

#### 3b. Convert markdown to Confluence storage XHTML

Convert the markdown content to valid Confluence storage XHTML. The Confluence instance does NOT have a markdown macro — all content must be native XHTML.

**Local link resolution (cross-page links):**

Markdown files may contain links to other process files with optional heading anchors, e.g.:
- `[Бюджет на техдолг](processes/tech-debt.md#2-бюджет-на-техдолг-в-спринте)`
- `[Техдолг](processes/tech-debt.md)`

During XHTML conversion, resolve these links to Confluence URLs:

1. Find all markdown links where the URL starts with `processes/` and ends with `.md` (with optional `#anchor`)
2. For each such link:
   - Extract the file path (e.g. `processes/tech-debt.md`) and optional anchor (e.g. `#2-бюджет-на-техдолг-в-спринте`)
   - Look up `confluence_page_id` in `.claude/confluence-sync.json` by the file path
   - **If page_id found and no anchor:** replace URL with `https://cf.avito.ru/pages/viewpage.action?pageId={page_id}`
   - **If page_id found and anchor present:** build the anchor URL locally using the Confluence anchor format (no API call needed):
     1. Get the **page title** — the first `# H1` heading from the target markdown file
     2. Get the **heading text** — convert the markdown anchor back to human-readable text: replace `-` with nothing (join words), but first derive the original heading text from the target file by finding the heading that matches the anchor
     3. Build the anchor fragment: `#id-{PageTitle}-{HeadingText}` where:
        - `{PageTitle}` = page title with **all spaces removed** (no replacement character, just concatenated)
        - `{HeadingText}` = heading text with **all spaces removed**
        - The entire fragment (after `#`) is then **URL-encoded** (percent-encode all non-ASCII characters including Cyrillic, and special characters like `:`, `'`, `(`, `)`, `→`)
     4. Final URL: `https://cf.avito.ru/pages/viewpage.action?pageId={page_id}{encoded_anchor}`

     **Example:** Page "Системная работа с техдолгом" (ID 842230760), heading "1. Правила заведения тикетов":
     - Raw fragment: `#id-Системнаяработастехдолгом-1.Правилазаведениятикетов`
     - URL-encoded: `#id-%D0%A1%D0%B8%D1%81%D1%82%D0%B5%D0%BC%D0%BD%D0%B0%D1%8F%D1%80%D0%B0%D0%B1%D0%BE%D1%82%D0%B0%D1%81%D1%82%D0%B5%D1%85%D0%B4%D0%BE%D0%BB%D0%B3%D0%BE%D0%BC-1.%D0%9F%D1%80%D0%B0%D0%B2%D0%B8%D0%BB%D0%B0%D0%B7%D0%B0%D0%B2%D0%B5%D0%B4%D0%B5%D0%BD%D0%B8%D1%8F%D1%82%D0%B8%D0%BA%D0%B5%D1%82%D0%BE%D0%B2`

     **Important:** Do NOT use `paas_confluence_get_heading_links` for this — build the anchor locally to avoid extra API calls.

   - **If page_id NOT found** (file is private or not yet synced): remove the link markup, keep only the link text as plain text
3. Then proceed with the standard markdown → XHTML conversion below

**Conversion rules:**

| Markdown | Confluence XHTML |
|----------|-----------------|
| `# H1` through `#### H4` | `<h1>` through `<h4>` (but see note below about first H1) |
| `> blockquote` | `<blockquote><p>...</p></blockquote>` |
| `**bold**` | `<strong>bold</strong>` |
| `*italic*` | `<em>italic</em>` |
| `- item` | `<ul><li>item</li></ul>` |
| `1. item` | `<ol><li>item</li></ol>` |
| Nested lists | Nested `<ul>`/`<ol>` inside parent `<li>` |
| Markdown tables | `<table><colgroup><col/></colgroup><tbody><tr><th>header</th></tr><tr><td>cell</td></tr></tbody></table>` |
| `` `code` `` inline | `<code>code</code>` |
| Code blocks (triple backticks) | `<ac:structured-macro ac:name="code"><ac:plain-text-body><![CDATA[...]]></ac:plain-text-body></ac:structured-macro>` |
| `---` horizontal rule | `<hr/>` |
| `[text](url)` | `<a href="url">text</a>` |
| `\[text\]` escaped brackets | Plain text `[text]` |
| `- [ ] item` checkboxes | `<ul><li>item</li></ul>` (checkbox marker removed) |
| Paragraphs | `<p>text</p>` |

**Escaping rules for text content (NOT for HTML tags):**
- `&` → `&amp;`
- `<` → `&lt;`
- `>` → `&gt;`
- `"` → `&quot;` (inside attribute values)

**First H1 exclusion:**
- The first `# H1` heading is used as the page **title** (passed via the `title` parameter) and must be **excluded from the XHTML body** to avoid duplication. Confluence already displays the page title prominently — including it again as `<h1>` in the body results in the title appearing twice.
- All subsequent headings (`## H2` through `#### H4`, and any additional `# H1` if present) are converted normally.

**Important:**
- All tags must be properly closed (valid XML)
- Write the XHTML to a temp file `/tmp/confluence-sync-<filename>.xml`
- For pages > 10KB of XHTML, use the download/upload workflow: `paas_confluence_download_page` → replace file content → `paas_confluence_upload_page`
- For smaller pages, `paas_confluence_update_page(body=...)` is acceptable

#### 3c. Update existing page

If the file has a `confluence_page_id` in the config:

1. Call `paas_confluence_get_page_history(page_id, limit=1)` to get the current version number
2. Compare current version with `last_synced_version` from config:
   - If **current > last_synced_version** — this is a **conflict** (someone edited the page manually):
     - Show the user: page title, last synced version, current version, who edited last, when
     - Ask the user via AskUserQuestion: "Overwrite?" / "Skip this file"
     - If skip — move to next file
3. Extract the page title from the first `# H1` heading of the markdown file. Always pass this as the `title` parameter when updating — the markdown file is the source of truth for the page title
4. Upload the XHTML:
   - For large pages (XHTML > 10KB): use `paas_confluence_download_page(url, format=storage)` to get the storage file path, overwrite that file with the new XHTML using Write tool, then `paas_confluence_upload_page(file, page_id)` (and `title=...` if changed)
   - For small pages: use `paas_confluence_update_page(page_id, body=<xhtml>)` (and `title=...` if changed)
5. Call `paas_confluence_get_page_history(page_id, limit=1)` to get the new version number
6. Compute SHA-256 hash of the markdown file: `shasum -a 256 <file>`
7. Update config: set `last_synced_version` to the new version number and `last_synced_hash` to the computed hash

#### 3d. Create new page

If the file has NO entry in the config (or no `confluence_page_id`):

1. Extract the title from the first `# H1` heading in the markdown file
2. Call `paas_confluence_create_page(title=<title>, body=<xhtml>, parent_page_id=<parent_page_id from config>)`
3. From the response, capture the new page ID
4. Call `paas_confluence_get_page_history(page_id, limit=1)` to get the version number
5. Compute SHA-256 hash of the markdown file: `shasum -a 256 <file>`
6. Add entry to config:
   ```json
   {
     "confluence_page_id": "<new_id>",
     "last_synced_version": <version>,
     "last_synced_hash": "<sha256>"
   }
   ```

### Step 4: Save updated config

Write the updated `.claude/confluence-sync.json` with any new page IDs and version numbers.

### Step 5: Report

Print a summary:

```
Sync complete:
- Updated: processes/tech-debt.md → page 842230766 (v12 → v13)
- Created: processes/new-process.md → page 999999 (v1)
- Skipped (private): processes/feature-requests.private.md
- Skipped (unchanged): processes/unchanged.md
- Skipped (conflict, user chose skip): processes/other.md
```

## Config file schema

File: `.claude/confluence-sync.json`

```json
{
  "space_key": "MIS",
  "parent_page_id": "842230758",
  "pages": {
    "processes/tech-debt.md": {
      "confluence_page_id": "842230760",
      "last_synced_version": 4,
      "last_synced_hash": "a1b2c3d4e5f6..."
    }
  }
}
```

- `space_key`: Confluence space key
- `parent_page_id`: parent page for new pages (the "Процессы" page)
- `pages`: map of file path (relative to repo root) to page info
- `confluence_page_id`: CF page ID (absent for files not yet synced)
- `last_synced_version`: CF page version after last sync (for conflict detection)
- `last_synced_hash`: SHA-256 hash of the markdown file content at the time of last sync (for skipping unchanged files)

**Note:** Page title is NOT stored in the config. It is always derived from the `# H1` heading of the markdown file. The markdown file is the single source of truth for the page title.
