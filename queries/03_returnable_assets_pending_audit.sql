-- Audit of returnable containers currently pending return by destination store.
-- Isolates the latest event (seq = 1) per asset and attaches operator badge accountability
-- plus aging in days, prioritized by longest overdue containers first.

WITH latest_asset_event AS (
    SELECT
        m.asset_code,
        m.destination_store_id,
        m.operator_badge,
        m.moved_at,
        m.return_status,
        ROW_NUMBER() OVER (
            PARTITION BY m.asset_code
            ORDER BY m.moved_at DESC, m.movement_id DESC
        ) AS seq
    FROM dbo.returnable_asset_movements AS m WITH (NOLOCK)
)
SELECT
    st.store_code AS pending_store_code,
    st.store_name AS pending_store_name,
    e.asset_code,
    e.operator_badge AS responsible_operator,
    e.moved_at AS dispatched_at,
    DATEDIFF(DAY, e.moved_at, SYSDATETIME()) AS days_open
FROM latest_asset_event AS e
INNER JOIN dbo.stores AS st WITH (NOLOCK)
    ON st.store_id = e.destination_store_id
WHERE e.seq = 1
  AND e.return_status = 'PENDING'
ORDER BY
    days_open DESC,
    e.asset_code;
