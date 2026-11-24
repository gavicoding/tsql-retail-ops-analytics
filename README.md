**🇺🇸 English** | [🇧🇷 Português](README.pt-BR.md)

# 🗄️ tsql-retail-ops-analytics

[![CI](https://github.com/gavicoding/tsql-retail-ops-analytics/actions/workflows/ci.yml/badge.svg)](https://github.com/gavicoding/tsql-retail-ops-analytics/actions/workflows/ci.yml)
[![Dialect: T-SQL](https://img.shields.io/badge/Dialect-T--SQL%20(SQL%20Server)-CC2927.svg)](https://learn.microsoft.com/sql/t-sql/)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-green.svg)](LICENSE)

A **100% synthetic, production-inspired T-SQL / SQL Server analytics and DBA toolkit** demonstrating real-world multi-store retail operations, warehouse logistics (WMS), POS/fiscal reconciliation, lock contention observability, and least-privilege RBAC.

> **Privacy Note:** All table structures, columns, stored procedures, and seed records in this repository are **100% synthetic** and built strictly to showcase T-SQL engineering patterns without exposing any proprietary ERP schema or company data.

---

## Core Patterns Demonstrated

- **Single-Pass Conditional Aggregation:** Computes store/daily net sales alongside strategic category subtotals and share percentages in one scan without row multiplication (`SUM(CASE WHEN ...)` + `NULLIF`).
- **Window-Function Deduplication (`ROW_NUMBER()`):** Eliminates duplicate rows when returnable containers/assets complete multiple trips between distribution centers and retail stores (`PARTITION BY asset_code ORDER BY moved_at DESC`).
- **SARGable Date-Range Filtering:** Uses half-open `DATETIME2` intervals (`>= @start_date AND < DATEADD(DAY, 1, @end_date)`) aligned with covering/filtered nonclustered indexes (`schema/02_indexes.sql`).
- **Multi-Mode Parameterized Stored Procedures:** Consolidated (`'C'`), Detailed (`'D'`), and Full-Item Audit (`'A'` via `LEFT JOIN`) reporting + transactional key-value updates (`BEGIN TRY` / `UPDLOCK, HOLDLOCK` / `THROW`).
- **DBA Observability & Least-Privilege Security:** Out-of-band `sys.dm_tran_locks` wait capture, `msdb` SQL Agent job health ranking, and `db_readonly_analytics` role grants (`GRANT SELECT` + schema-level `DENY` writes).

---

## Synthetic Schema ER Diagram

```mermaid
erDiagram
    STORES ||--o{ SALES : records
    PRODUCT_CATEGORIES ||--o{ SALES : classifies
    STORES ||--o{ RETURNABLE_ASSET_MOVEMENTS : ships_and_receives
    INVENTORY_ITEMS ||--o{ INVENTORY_MOVEMENTS : tracks
    STORES ||--o{ INVENTORY_MOVEMENTS : holds
    STORES ||--o{ POS_CASH_RECONCILIATION : settles
    STORES ||--o{ FISCAL_TRANSMISSIONS : emits
    STORES ||--o{ WMS_PICKING_TASKS : dispatches
```

---

## Script Catalog

| Category | File | Business Problem & T-SQL Techniques |
| :--- | :--- | :--- |
| **Schema** | [`schema/01_schema.sql`](schema/01_schema.sql) | Multi-store retail, returnables, inventory, POS/fiscal, WMS & lock-log DDL |
| **Indexes** | [`schema/02_indexes.sql`](schema/02_indexes.sql) | Covering indexes (`INCLUDE`) & filtered index for active WMS backlog |
| **Seed** | [`schema/03_seed_data.sql`](schema/03_seed_data.sql) | Synthetic multi-store & multi-trip container test dataset |
| **Query** | [`queries/01_net_sales_strategic_categories.sql`](queries/01_net_sales_strategic_categories.sql) | Single-pass net sales & strategic category share (`CASE WHEN`, `NULLIF`) |
| **Query** | [`queries/02_returnable_asset_latest_movement.sql`](queries/02_returnable_asset_latest_movement.sql) | Deduplicated latest movement per asset via `CTE` + `ROW_NUMBER()` |
| **Query** | [`queries/03_returnable_assets_pending_audit.sql`](queries/03_returnable_assets_pending_audit.sql) | Pending return aging (`DATEDIFF`) & operator accountability (`seq = 1`) |
| **Query** | [`queries/04_pos_cashflow_fiscal_reconciliation.sql`](queries/04_pos_cashflow_fiscal_reconciliation.sql) | Dual-CTE store tender variance & fiscal transmission health audit |
| **Query** | [`queries/05_wms_picking_bottlenecks.sql`](queries/05_wms_picking_bottlenecks.sql) | Stage backlog (`PICKING`, `CHECKOUT`, `TRANSFER`) & avg cycle duration |
| **Proc** | [`procedures/usp_inventory_movements_report.sql`](procedures/usp_inventory_movements_report.sql) | Multi-mode `'C'`/`'D'`/`'A'` procedure with SARGable range bounds |
| **Proc** | [`procedures/usp_safe_config_update.sql`](procedures/usp_safe_config_update.sql) | Transactional key-value config update (`UPDLOCK`, `TRY...CATCH`, audit row) |
| **DBA** | [`observability/01_lock_contention_snapshot.sql`](observability/01_lock_contention_snapshot.sql) | Out-of-band `sys.dm_tran_locks` + `sys.dm_exec_requests` `WAIT` logger |
| **DBA** | [`observability/02_sql_agent_jobs_health.sql`](observability/02_sql_agent_jobs_health.sql) | Latest outcome per scheduled job via `msdb.dbo.sysjobhistory` + `ROW_NUMBER()` |
| **RBAC** | [`security/01_readonly_analytics_grants.sql`](security/01_readonly_analytics_grants.sql) | Least-privilege `db_readonly_analytics` role (`GRANT SELECT` + `DENY` writes) |

---

## Before vs. After Optimization Highlights

| Scenario | Before (Bottleneck / Risk) | After (T-SQL Engineering Fix) |
| :--- | :--- | :--- |
| **Multi-trip returnable boxes** | Flat `SELECT` returned duplicate rows per asset after multiple cycles, inflating counts and hiding current custody | `ROW_NUMBER() OVER (PARTITION BY asset_code ORDER BY moved_at DESC, movement_id DESC)` isolates strictly the latest movement (`rn = 1`) with operator badge |
| **Strategic category reporting** | Multiple separate queries and manual spreadsheet reconciliation risked mismatched date filters or double counting | Unified single-pass `SUM(CASE WHEN is_strategic = 1 ...)` calculates total and strategic subtotals simultaneously |
| **Date-range filtering on movements** | Wrapping indexed `DATETIME2` columns in `CAST(col AS DATE) BETWEEN ...` prevented index seeks | Half-open bounds (`>= @range_start AND < DATEADD(DAY, 1, @end_date)`) enable index seeks on `IX_inventory_movements_movedat_item` |
| **Peak-hour slowdown investigation** | Heavy live probing or transient observation missed root causes behind brief transaction blocks | Out-of-band `sys.dm_tran_locks` (`WAIT`) snapshots persisted into `db_latency_lock_logs` for offline trend analysis |
| **Report with an optional product filter** | Blank field broke the numeric conversion; `ISNUMERIC` still let `'$'`, `'1e5'` and `'12,5'` through; one cached plan served both single-product and full-period runs (parameter sniffing) | `TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@p)), N''))` (note: `TRY_CONVERT(INT, '')` is `0`, not `NULL`), `(col = @id OR @id IS NULL)` + `OPTION (RECOMPILE)` ([`usp_purchase_items_report`](procedures/usp_purchase_items_report.sql)) |
| **Batch ingest from an external API** | One insert per round trip and the whole run failed on the first duplicate | One set-based statement: in-batch `ROW_NUMBER()` dedupe, `NOT EXISTS` on both keys with `UPDLOCK, HOLDLOCK`, `OUTPUT ... INTO @table` ([`usp_ingest_invoice_index_batch`](procedures/usp_ingest_invoice_index_batch.sql)) |
| **Dashboard over a huge log** | Summarising 12 months in one query took more than 2 minutes and timed out | Incremental pre-aggregation: a few days per run, latest state per document, idempotent `MERGE` ([`usp_refresh_daily_emission_summary`](procedures/usp_refresh_daily_emission_summary.sql)) |
| **Backlog with a per-row EXISTS** | Correlated `EXISTS` on every row ran past the 15s timeout, and `EXISTS` inside `SUM` is not allowed (error 130) | Two stages: materialise a flagged, indexed `#temp`, then aggregate ([`06_contingency_backlog_two_stage`](queries/06_contingency_backlog_two_stage.sql)) |
| **Automating a vendor application** | Writing straight into ERP tables skips stock, finance and audit side effects | Short filtered Extended Events session to see which procedures the app calls, then call those ([`03_trace_app_calls_with_xevents`](observability/03_trace_app_calls_with_xevents.sql)) |
| **Bot that extends temporary access** | A bot with table rights could create windows or move start times | Role with `EXECUTE` on one procedure that only extends the end time, direct DML denied ([`02_time_boxed_access_extension`](security/02_time_boxed_access_extension.sql)) |
| **LGPD Art. 18 erasure request** | Deleting the customer breaks orders and fiscal reports; hashing the CPF only pseudonymises it (brute-forceable) | Irreversible anonymization: random surrogate for the tax id, personal fields removed, birth date generalised to the year, orders kept for legal retention, evidence hash and PII-free audit ([`usp_anonymize_customer`](procedures/usp_anonymize_customer.sql), proved by [`02_privacy_assertions`](tests/sql/02_privacy_assertions.sql)) |

---

## Automated Verification & Execution

### Run Automated Structural + Analytical Tests (No SQL Server Required)

```bash
python -m unittest discover -s tests -v
```

Validates balanced `BEGIN`/`CASE`/`END` blocks, SARGable date predicates, guarded `UPDATE`/`DELETE` statements, and executes the analytical query logic against an in-memory SQLite dataset matching `schema/03_seed_data.sql`.

### Integration Tests on a Real SQL Server 2022 (CI)

Every push starts a throwaway **SQL Server 2022** container in GitHub Actions, runs **every script** in this repository in order (`schema`, `procedures`, `queries`, `observability`, `security`) and then [`tests/sql/01_integration_assertions.sql`](tests/sql/01_integration_assertions.sql), which fails the build on any wrong result:

- the optional filter with `NULL`, blank, `'$'`, `'1e5'`, `'12,5'`, a valid id and an unknown id;
- the cost fallback;
- batch ingest idempotency (in-batch duplicate, existing key, existing registry, same batch twice);
- pre-aggregation reruns;
- rejection of an invalid access extension;
- LGPD erasure: personal data gone from every table, totals and foreign keys unchanged, reruns rejected.

### Run Against SQL Server (2019 / 2022+)

Execute scripts in order via SSMS, Azure Data Studio, or `sqlcmd`:
1. `schema/01_schema.sql`
2. `schema/02_indexes.sql`
3. `schema/03_seed_data.sql` through `schema/07_customer_privacy_seed_data.sql`
4. `procedures/*.sql`, `queries/*.sql`, `observability/*.sql`, `security/*.sql`
5. `tests/sql/*.sql` (assertions)

---

## License

Apache License 2.0 - see [LICENSE](LICENSE).
