/*
  График количества открытых Tech-task на каждую дату с разбивкой по приоритетам.

  Логика: для каждой даты из интервала считаем задачи, которые
  - созданы не позже этой даты (create_time <= event_date)
  - ещё не закрыты на эту дату:
      - есть resolution_time и он позже event_date, ИЛИ
      - нет resolution_time и текущий статус не терминальный (Done, Closed, Canceled)
  - не заархивированы

  Результат: общее количество (open_count) + отдельные колонки по приоритетам
  (Critical, Major, Normal, Minor). Подходит для stacked bar/area chart в Redash.

  Параметры:
      {{ team }}             — проект (issue_project), Query Based Dropdown
      {{ event_date.start }} — начало интервала
      {{ event_date.end }}   — конец интервала
      {{ period }}           — гранулярность: day / week / month
*/
WITH date_series AS (
    SELECT DISTINCT
        toDate(dateTrunc('{{ period }}', d)) AS event_date
    FROM (
        SELECT toDate('{{ event_date.start }}') + number AS d
        FROM numbers(toUInt32(least(toDate('{{ event_date.end }}'), today()) - toDate('{{ event_date.start }}') + 1))
    )
),
tech_tasks AS (
    SELECT
        jiraissue_id,
        toDate(create_time)     AS created,
        toDate(resolution_time) AS resolved,
        issue_status,
        issue_priority
    FROM datasets.dma_current_jira_issue
    WHERE issue_type = 'Tech-task'
      AND issue_project = '{{ team }}'
      AND (is_archived IS NULL OR is_archived = false)
),
is_open AS (
    SELECT
        d.event_date,
        t.issue_priority,
        t.created <= d.event_date
            AND (t.resolved > d.event_date
                 OR (t.resolved IS NULL
                     AND t.issue_status NOT IN ('Done', 'Closed', 'Canceled'))) AS open
    FROM date_series d
    CROSS JOIN tech_tasks t
)
SELECT
    event_date,
    countIf(open)                                       AS open_count,
    countIf(open AND issue_priority = 'Critical')       AS critical,
    countIf(open AND issue_priority = 'Major')          AS major,
    countIf(open AND issue_priority = 'Normal')         AS normal,
    countIf(open AND issue_priority = 'Minor')          AS minor
FROM is_open
GROUP BY event_date
ORDER BY event_date