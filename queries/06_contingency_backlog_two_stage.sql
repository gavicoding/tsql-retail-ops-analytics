-- Contingency backlog per store in two stages with a #temp table.
--
-- Production lesson behind it:
--   * The first version computed "is this document still pending?" with a correlated
--     EXISTS for every row and aggregated everything in one statement. Over the large
--     log it ran past the 15s application timeout.
--   * SQL Server does not allow a subquery such as EXISTS inside an aggregate
--     (SUM(CASE WHEN EXISTS (...)) fails with error 130).
--   * Fix: stage 1 materialises one row per contingency document with a pending flag
--     into #pending (indexed); stage 2 aggregates that small set.

DECLARE @window_start DATE = '2026-11-18';
DECLARE @window_end   DATE = '2026-11-20';

IF OBJECT_ID('tempdb..#pending') IS NOT NULL
    DROP TABLE #pending;

-- Stage 1: one row per document that went to contingency, flagged if it was never authorised later
SELECT
    c.store_id,
    c.business_date,
    c.document_number,
    MIN(c.attempted_at) AS first_contingency_at,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM dbo.fiscal_transmissions AS a
            WHERE a.store_id            = c.store_id
              AND a.document_number     = c.document_number
              AND a.transmission_status = 'AUTHORIZED'
        ) THEN 0
        ELSE 1
    END AS still_pending
INTO #pending
FROM dbo.fiscal_transmissions AS c
WHERE c.transmission_status = 'CONTINGENCY'
  AND c.business_date >= @window_start
  AND c.business_date <= @window_end
GROUP BY c.store_id, c.business_date, c.document_number;

CREATE CLUSTERED INDEX CX_pending ON #pending (store_id, business_date);

-- Stage 2: aggregate the small materialised set
SELECT
    s.store_code,
    s.store_name,
    COUNT(*)                                   AS contingency_docs,
    SUM(p.still_pending)                       AS still_pending_docs,
    MIN(CASE WHEN p.still_pending = 1 THEN p.first_contingency_at END) AS oldest_pending_at
FROM #pending AS p
JOIN dbo.stores AS s ON s.store_id = p.store_id
GROUP BY s.store_code, s.store_name
ORDER BY still_pending_docs DESC, oldest_pending_at;

DROP TABLE #pending;
