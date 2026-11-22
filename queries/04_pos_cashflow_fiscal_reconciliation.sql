-- Multi-store POS cashflow reconciliation combined with electronic fiscal transmission health.
-- Aggregates store tender variances (expected vs. settled) alongside contingency/rejected NF counts.

DECLARE @target_date DATE = '2026-11-20';

WITH pos_summary AS (
    SELECT
        p.store_id,
        p.business_date,
        SUM(p.expected_amount) AS total_expected,
        SUM(p.settled_amount)  AS total_settled,
        SUM(p.settled_amount - p.expected_amount) AS net_variance
    FROM dbo.pos_cash_reconciliation AS p WITH (NOLOCK)
    WHERE p.business_date = @target_date
    GROUP BY
        p.store_id,
        p.business_date
),
fiscal_summary AS (
    SELECT
        f.store_id,
        f.business_date,
        COUNT(*) AS total_documents,
        SUM(CASE WHEN f.transmission_status = 'AUTHORIZED' THEN 1 ELSE 0 END) AS authorized_docs,
        SUM(CASE WHEN f.transmission_status = 'CONTINGENCY' THEN 1 ELSE 0 END) AS contingency_docs,
        SUM(CASE WHEN f.transmission_status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected_docs
    FROM dbo.fiscal_transmissions AS f WITH (NOLOCK)
    WHERE f.business_date = @target_date
    GROUP BY
        f.store_id,
        f.business_date
)
SELECT
    st.store_code,
    st.store_name,
    ps.business_date,
    ps.total_expected,
    ps.total_settled,
    ps.net_variance,
    COALESCE(fs.total_documents, 0)  AS total_fiscal_docs,
    COALESCE(fs.contingency_docs, 0) AS contingency_docs,
    COALESCE(fs.rejected_docs, 0)    AS rejected_docs,
    CASE
        WHEN ps.net_variance <> 0 OR COALESCE(fs.rejected_docs, 0) > 0 THEN 'ACTION_REQUIRED'
        WHEN COALESCE(fs.contingency_docs, 0) > 0 THEN 'MONITOR_CONTINGENCY'
        ELSE 'RECONCILED'
    END AS audit_status
FROM pos_summary AS ps
INNER JOIN dbo.stores AS st WITH (NOLOCK)
    ON st.store_id = ps.store_id
LEFT JOIN fiscal_summary AS fs
    ON fs.store_id = ps.store_id
   AND fs.business_date = ps.business_date
ORDER BY
    ABS(ps.net_variance) DESC,
    COALESCE(fs.rejected_docs, 0) DESC,
    st.store_code;
