-- Single-pass net sales consolidation with strategic category isolation.
-- Avoids double counting across categories and eliminates post-processing in spreadsheets.
-- Uses SARGable half-open date interval (>= @start_date AND < DATEADD(DAY, 1, @end_date))
-- so IX_sales_status_saleat can perform an efficient index seek.
-- Trade-off note: WITH (NOLOCK) reduces blocking on heavy OLTP tables for read-only KPI views,
-- trading strict serializability (risk of dirty reads on uncommitted/rolled-back rows).

DECLARE @start_date DATE = '2026-11-01';
DECLARE @end_date   DATE = '2026-11-30';

SELECT
    st.store_id,
    st.store_code,
    st.store_name,
    CAST(s.sale_at AS DATE) AS business_date,
    SUM(s.net_amount) AS total_net_sales,
    SUM(
        CASE
            WHEN pc.is_strategic = 1 THEN s.net_amount
            ELSE 0
        END
    ) AS strategic_categories_net_sales,
    CAST(
        100.0 * SUM(CASE WHEN pc.is_strategic = 1 THEN s.net_amount ELSE 0 END)
        / NULLIF(SUM(s.net_amount), 0)
        AS DECIMAL(5,2)
    ) AS strategic_share_pct
FROM dbo.sales AS s WITH (NOLOCK)
INNER JOIN dbo.stores AS st WITH (NOLOCK)
    ON st.store_id = s.store_id
INNER JOIN dbo.product_categories AS pc WITH (NOLOCK)
    ON pc.category_id = s.category_id
WHERE s.sale_status = 'COMPLETED'
  AND s.sale_at >= @start_date
  AND s.sale_at < DATEADD(DAY, 1, @end_date)
GROUP BY
    st.store_id,
    st.store_code,
    st.store_name,
    CAST(s.sale_at AS DATE)
ORDER BY
    business_date DESC,
    st.store_code;
