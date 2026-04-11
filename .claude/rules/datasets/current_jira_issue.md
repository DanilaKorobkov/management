# Витрина: Текущее состояние тикетов Jira

**Таблица:** `DMA.current_jira_issue`
**Engine:** Vertica
**Обновление:** FULL_REFRESH (scheduled, priority: critical)
**Владелец:** Technical Project Office
**Исходник:** [dma_current_jira_issue.sql](https://stash.msk.avito.ru/projects/BI/repos/avito-dwh-sqlpublic/browse/datamarts/dma_current_jira_issue.sql)

Витрина содержит срез информации по тикетам Jira на текущий момент — одна строка на задачу.

## Схема

### Ключевая колонка

| Имя            | Тип данных | Описание    |
|----------------|------------|-------------|
| jiraissue_id   | int        | ID задачи   |

### Идентификация и метаданные задачи

| Имя              | Тип данных     | Описание                                                                        |
|------------------|----------------|---------------------------------------------------------------------------------|
| issue_key        | varchar(32)    | Номер задачи в Jira (например, DWH-1)                                          |
| issue_url        | varchar(59)    | Ссылка на задачу                                                                |
| summary          | varchar(1024)  | Заголовок задачи, краткое описание                                              |
| issue_type       | varchar(256)   | Тип задачи                                                                      |
| issue_project    | varchar(256)   | Проект                                                                          |
| issue_department | varchar(32)    | Сокращённое название issue_project. Для связи с юнитом join с `tv_jira_unit_cluster` через `project` |

### Статус и приоритет

| Имя                    | Тип данных   | Описание                                                                              |
|------------------------|--------------|---------------------------------------------------------------------------------------|
| issue_status           | varchar(256) | Статус задачи на текущий момент (день)                                                |
| issue_priority         | varchar(256) | Приоритет задачи                                                                      |
| issue_priority_for_bug | varchar(256) | Приоритет багов                                                                       |
| scoring                | int          | Детализация приоритета задачи                                                         |
| resolution             | varchar(256) | Причина завершения задачи. NULL для статусов, отличных от resolved (например, Done в проекте BX) |
| JiraClassification     | varchar(256) | Аспект/атрибут качества для Bug, Refactoring                                          |

### Даты

| Имя                 | Тип данных | Описание                                                                      |
|----------------------|------------|-------------------------------------------------------------------------------|
| create_time          | timestamp  | Время создания задачи                                                         |
| update_time          | timestamp  | Время последних изменений по задаче                                           |
| due_date             | timestamp  | Срок исполнения, поставленный заказчиком                                      |
| resolution_time      | timestamp  | Время перевода в статус resolved                                              |
| first_pr_created     | timestamp  | Дата первого pull-request                                                     |
| work_start           | timestamp  | Текущее состояние поля "Work Start" (customfield_11810)                       |
| incident_start       | timestamp  | Дата начала инцидента                                                         |
| incident_end         | timestamp  | Дата окончания инцидента                                                      |
| incident_detection   | timestamp  | Текущее состояние поля "Incident detection" (customfield_14132)               |

### Люди и оргструктура

| Имя              | Тип данных     | Описание                                                                                                                          |
|------------------|----------------|-----------------------------------------------------------------------------------------------------------------------------------|
| reporter_key     | varchar(256)   | Заказчик задачи (user name) на текущий момент                                                                                     |
| reporter         | varchar(256)   | Заказчик задачи (full name) на текущий момент                                                                                     |
| creator_key      | varchar(256)   | Создатель (user name) задачи                                                                                                      |
| creator          | varchar(256)   | Создатель (full name) задачи                                                                                                      |
| reporter_unit    | varchar(1024)  | Юнит, к которому относится задача (DWH-8456, данные устарели)                                                                     |
| reporter_cluster | varchar(1024)  | Кластер, к которому относится reporter_unit                                                                                       |
| issue_unit       | varchar(1024)  | Текущее значение поля Unit (customfield_12113) через запятую                                                                      |
| feature_teams    | varchar(256)   | Текущее состояние полей "Feature Team" (customfield_12514) и "Feature Teams" (customfield_12823) через запятую (выбирается свежее) |

### Оценки и метрики

| Имя            | Тип данных | Описание                                                         |
|----------------|------------|------------------------------------------------------------------|
| storypoints    | float      | Оценка времени выполнения задачи                                 |
| time_estimate  | int        | Оценка выполнения задачи                                         |
| comments_cnt   | int        | Количество комментариев к задаче                                 |
| epic_child_cnt | int        | Количество связанных задач, если есть                            |
| hd_count       | int        | Количество обращений пользователей из HelpDesk (для проекта SPT) |
| bonus_amount   | int        | Текущее состояние поля "Bonus amount" (customfield_13016)        |

### Компоненты, лейблы, версии

| Имя                | Тип данных     | Описание                                                           |
|--------------------|----------------|--------------------------------------------------------------------|
| component_1        | varchar(256)   | Component 1                                                        |
| component_2        | varchar(256)   | Component 2                                                        |
| component_3        | varchar(256)   | Component 3                                                        |
| all_components     | varchar(4126)  | Все компоненты                                                     |
| labels             | varchar(1024)  | Все label через пробел                                             |
| epic_issue_key     | varchar(256)   | Номер эпика                                                        |
| epic_issue_labels  | varchar(1024)  | Все label эпика через пробел                                       |
| tech_reports_label | boolean        | Факт наличия label=TechReports                                    |
| service_epic_label | boolean        | Есть ли среди лейблов тикета "service.epic"                        |
| affects_versions   | varchar(256)   | Версии приложений, затронутые багом                                |
| fix_versions       | varchar(256)   | Версия приложения, в которой реализовано изменение                 |
| issue_platforms    | varchar(256)   | Все platform через запятую                                         |
| sprint_list_id     | int            | ID списка спринтов                                                 |

### Toggle keys

| Имя              | Тип данных     | Описание              |
|------------------|----------------|-----------------------|
| ai_toggle_key    | varchar(1024)  | Toggle key для iOS    |
| atbt_toggle_key  | varchar(1024)  | Toggle key для Android |

### Дополнительные колонки (не в исходной спецификации, но есть в SQL)

| Имя                                  | Тип данных     | Описание                                                        |
|---------------------------------------|----------------|-----------------------------------------------------------------|
| assignee                              | varchar(256)   | Текущий исполнитель (login)                                     |
| department_removed                    | boolean        | Департамент удалён (из `saed.jira_project`)                     |
| reporter_login                        | varchar(256)   | Логин заказчика (фильтруются hex-only логины удалённых юзеров)  |
| creator_login                         | varchar(256)   | Логин создателя (фильтруются hex-only логины удалённых юзеров)  |
| is_archived                           | boolean        | Задача заархивирована (из `dict.archived_jira_issues`)          |
| real_estate_developer                 | varchar(512)   | Застройщик (для недвижимости)                                   |
| perf_anomaly_cancellation_reason      | varchar(512)   | Причина отмены перф-аномалии                                    |
| perf_agreed_not_to_fix_reason         | varchar(512)   | Причина "согласовано не чинить"                                 |
| perf_agreed_to_fix_later_reason       | varchar(512)   | Причина "согласовано починить позже"                             |
| perf_trigger_type                     | varchar(512)   | Тип перф-триггера                                               |
| perf_trigger_suggest_score            | varchar(512)   | Скор предложения перф-триггера                                  |
| perf_fixed_on_the_spot_explanation    | varchar(128)   | Объяснение "починено на месте"                                  |
| issue_link                            | varchar(512)   | Ссылка на связанную задачу                                      |
| fixed_explanation                     | varchar(256)   | Объяснение исправления                                          |
| not_fixed_explanation                 | varchar(256)   | Объяснение, почему не исправлено                                |
| root_cause                            | varchar(128)   | Корневая причина                                                |
| test_status                           | varchar(50)    | Статус тестирования                                             |
| provider                              | varchar(50)    | Провайдер                                                       |
| standard_setting                      | varchar(50)    | Настройка стандарта                                              |

## Логика построения

- Источник — DDS-слой (Data Vault): сателлиты и линки Jira
- `issue_department` = префикс `issue_key` до дефиса (`split_partb(key, '-', 1)`)
- `issue_url` = `'https://jr.avito.ru/browse/' || issue_key`
- `tech_reports_label` = labels содержит 'techreport' (case-insensitive)
- `service_epic_label` = labels тикета ИЛИ labels эпика содержат 'service.epic'
- `creator` — если в Jira нет creator, берётся первый пользователь из истории задачи
- `epic_issue_key` — из epiclink; fallback на epiclink родительской задачи (parent issue)
- `first_pr_created` — только MERGED pull-requests
- `reporter_login` / `creator_login` — фильтруются hex-only логины (`^[0-9a-fA-F]{20}$`), т.к. это удалённые пользователи
- `is_archived` = true если задача есть в `dict.archived_jira_issues` и `update_time < archived_date`
- Удалённые тикеты исключены через захардкоженный список из 26 issue_key (ранее — `saed.jira_task` из Google Sheets, отказались т.к. удаление задач в Jira запрещено с ~2022)

## Проверки качества (checkers)

- `issue_key` не должен быть NULL
- `create_time` не должен быть NULL
- `create_time` не должен быть позже `resolution_time` (допуск 1 час)
- Если есть `resolution`, должен быть `resolution_time`

## Связи с другими витринами

- **`DMA.jira_issue_changelog`** — история изменений тикетов, join по `jiraissue_id`
- **`tv_jira_unit_cluster`** — справочник юнитов/кластеров, join по `issue_department = project`
- **`saed.jira_project`** — справочник проектов, поле `department_removed`
- **`dict.archived_jira_issues`** — список заархивированных задач

## Применение

- Фильтрация задач по проекту, типу, статусу, приоритету
- Расчёт метрик техдолга: количество открытых задач, суммарный вес в SP (см. `processes/tech-debt.md`)
- Анализ SLA по `due_date` vs `resolution_time`
- Связка с историей изменений (`jira_issue_changelog`) для полного lifecycle-анализа
