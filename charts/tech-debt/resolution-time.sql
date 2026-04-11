/*
  График персентилей (p50, p90) времени решения Tech-task.

  Время решения = resolution_time - create_time, в днях.
  Задачи группируются по дате решения (resolution_time).

  Включаются только задачи с resolution_time (закрытые / отменённые).

  Параметры:
      {{ team }}             — проект (issue_project), Query Based Dropdown
      {{ event_date.start }} — начало интервала (по дате решения)
      {{ event_date.end }}   — конец интервала (по дате решения)
      {{ period }}           — гранулярность: day / week / month
*/
SELECT
    toDate(dateTrunc('{{ period }}', resolution_time)) AS event_date,
    round(quantile(0.5)(dateDiff('day', create_time, resolution_time)), 0)  AS p50,
    round(quantile(0.9)(dateDiff('day', create_time, resolution_time)), 0)  AS p90
FROM datasets.dma_current_jira_issue
WHERE issue_type = 'Tech-task'
  AND issue_project = '{{ team }}'
  AND (is_archived IS NULL OR is_archived = false)
  AND resolution_time IS NOT NULL
  AND toDate(resolution_time) BETWEEN toDate('{{ event_date.start }}') AND least(toDate('{{ event_date.end }}'), today())
GROUP BY event_date
ORDER BY event_date
