## SQL-соглашения для запросов к DWH

### Именование таблиц

В SQL-запросах (Redash, ClickHouse) таблицы из слоя DMA адресуются как:

```
datasets.dma_<table_name>
```

**Не** `DMA.<table_name>` (это внутреннее имя витрины в DWH, не имя таблицы в Redash).

Примеры:
| Витрина (DWH)              | Таблица в запросе                        |
|----------------------------|------------------------------------------|
| `DMA.current_jira_issue`   | `datasets.dma_current_jira_issue`        |
| `DMA.jira_issue_changelog` | `datasets.dma_jira_issue_changelog`      |
