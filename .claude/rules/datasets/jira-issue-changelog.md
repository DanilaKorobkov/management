# Витрина: Changelog тикетов Jira

**Таблица:** `DMA.jira_issue_changelog`
**Engine:** Vertica
**Обновление:** FULL_REFRESH (scheduled, priority: critical)
**Владелец:** QA CoE
**Исходник:** [dma_jira_issue_changelog.sql](https://stash.msk.avito.ru/projects/BI/repos/avito-dwh-sqlpublic/browse/datamarts/dma_jira_issue_changelog.sql)

Витрина с динамикой изменения тикетов: статусы, фичатимы, спринты, SP, исполнители.

## Схема

### Ключевые колонки

| Имя            | Тип данных | Описание                              |
|----------------|------------|---------------------------------------|
| JiraIssue_id   | int        | ID задачи                             |
| Actual_date    | timestamp  | Дата изменения информации в задаче    |

### Остальные колонки

| Имя                 | Тип данных | Описание                                             |
|---------------------|------------|------------------------------------------------------|
| JiraSprintList_id   | int        | ID списка спринтов, в которые входила задача         |
| JiraFeatureTeams_id | int        | ID фичатимов (поле "Feature Teams" в задаче)         |
| JiraFeatureTeam_id  | int        | ID фичатимы (поле "Feature Team" в задаче)           |
| JiraAssignee_id     | int        | ID исполнителя задачи                                |
| JiraStatus_id       | int        | ID статуса задачи                                    |
| StoryPoints         | float      | Количество story points, начисленных задаче          |
| OriginalEstimate    | int        | Оценка задачи в единицах времени                     |
| launch_id           | int        | Мета-поле DWH                                        |

## Логика построения

Витрина строится из 7 независимых потоков изменений, каждый по единой схеме:

1. **Спринты** (`JiraSprintList_id`)
2. **Feature Teams** (`JiraFeatureTeams_id`)
3. **Feature Team** (`JiraFeatureTeam_id`)
4. **Исполнитель** (`JiraAssignee_id`)
5. **Статус** (`JiraStatus_id`)
6. **Story Points** (`StoryPoints`)
7. **Original Estimate** (`OriginalEstimate`)

### Паттерн сбора изменений (одинаковый для всех 7 потоков)

Для каждого атрибута:
- Если **есть история изменений** (`DDS.*History*`) — берутся все записи из истории (дедуплицированные по `JiraIssueHistory_id + Actual_date`)
- Если **истории нет** — берётся текущее значение атрибута с `Actual_date = create_time` задачи (т.е. считается, что значение было с момента создания)

### Сборка в единую таблицу

1. **Календарь событий** (`tmp_calendar`) — `UNION` всех `(JiraIssue_id, Actual_date)` из 7 потоков. Каждая уникальная дата изменения любого атрибута = строка в итоговой витрине
2. **Interpolate join** — каждый поток присоединяется к календарю через `interpolate previous value`. Это означает: для каждой даты из календаря берётся последнее известное значение атрибута на эту дату (forward-fill)
3. Результат — на каждую дату изменения полное состояние задачи по всем 7 атрибутам

### Важно

- Колонки содержат **ID**, а не имена. Для получения читаемых значений нужны join'ы с DDS-справочниками:
  - `JiraStatus_id` → `DDS.S_JiraStatus_Name`
  - `JiraAssignee_id` → `DDS.H_JiraUser` + `DDS.S_JiraUser_Login`
  - `JiraSprintList_id` → справочник спринтов
  - `JiraFeatureTeams_id` / `JiraFeatureTeam_id` → справочники фичатимов
## Связи с другими витринами

- **`DMA.current_jira_issue`** — текущий срез, join по `JiraIssue_id`

## Применение

- Детальный анализ lifecycle задачи: когда менялся статус, исполнитель, SP, спринт
- Построение burndown/burnup charts по спринтам
- Анализ переоценок (изменения StoryPoints / OriginalEstimate во времени)
- Отслеживание перемещений задач между фичатимами
