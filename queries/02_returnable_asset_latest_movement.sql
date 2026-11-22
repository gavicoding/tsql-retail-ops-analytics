-- Latest valid movement per returnable container/asset.
-- Eliminates multi-trip row duplication when a single asset completes several cycles
-- between the distribution center and retail stores.

WITH ranked_movements AS (
    SELECT
        m.movement_id,
        m.asset_code,
        m.origin_store_id,
        m.destination_store_id,
        m.operator_badge,
        m.movement_type,
        m.return_status,
        m.moved_at,
        ROW_NUMBER() OVER (
            PARTITION BY m.asset_code
            ORDER BY m.moved_at DESC, m.movement_id DESC
        ) AS rn
    FROM dbo.returnable_asset_movements AS m WITH (NOLOCK)
    WHERE m.asset_code IS NOT NULL
)
SELECT
    rm.asset_code,
    orig.store_code AS origin_store,
    dest.store_code AS current_or_target_store,
    rm.movement_type,
    rm.return_status,
    rm.operator_badge,
    rm.moved_at AS last_moved_at
FROM ranked_movements AS rm
INNER JOIN dbo.stores AS orig WITH (NOLOCK)
    ON orig.store_id = rm.origin_store_id
INNER JOIN dbo.stores AS dest WITH (NOLOCK)
    ON dest.store_id = rm.destination_store_id
WHERE rm.rn = 1
ORDER BY
    rm.moved_at DESC,
    rm.asset_code;
