/*
  График среднего возраста открытых Tech-task на каждую дату.

  Возраст задачи = (event_date - create_time) / 14 дней, выражен в спринтах
  (1 спринт = 2 недели).

  Логика определения «открыта на дату» — та же, что в count.sql:
  - создана не позже event_date
  - ещё не закрыта на event_date (resolution_time > event_date,
    либо resolution_time IS NULL и статус не терминальный)
  - не заархивирована

  Результат: средний возраст всех открытых задач на дату.

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
        issue_status
    FROM datasets.dma_current_jira_issue
    WHERE issue_type = 'Tech-task'
      AND issue_project = '{{ team }}'
      AND (is_archived IS NULL OR is_archived = false)
),
is_open AS (
    SELECT
        d.event_date,
        t.created <= d.event_date
            AND (t.resolved > d.event_date
                 OR (t.resolved IS NULL
                     AND t.issue_status NOT IN ('Done', 'Closed', 'Canceled'))) AS open,
        (d.event_date - t.created) / 14 AS age_sprints
    FROM date_series d
    CROSS JOIN tech_tasks t
)
SELECT
    event_date,
    round(avgIf(age_sprints, open), 1) AS avg_age
FROM is_open
GROUP BY event_date
ORDER BY event_date
