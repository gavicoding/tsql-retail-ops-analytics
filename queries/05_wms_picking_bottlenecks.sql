-- Warehouse picking, checkout, and inter-store transfer bottleneck analytics.
-- Tracks pending queue backlog vs. completed tasks and average cycle time per stage.

SELECT
    orig.store_code AS origin_store,
    dest.store_code AS destination_store,
    t.stage,
    COUNT(*) AS total_tasks,
    SUM(CASE WHEN t.task_status = 'PENDING' THEN 1 ELSE 0 END)     AS pending_tasks,
    SUM(CASE WHEN t.task_status = 'IN_PROGRESS' THEN 1 ELSE 0 END) AS in_progress_tasks,
    SUM(CASE WHEN t.task_status = 'COMPLETED' THEN 1 ELSE 0 END)   AS completed_tasks,
    AVG(
        CASE
            WHEN t.completed_at IS NOT NULL
            THEN CAST(DATEDIFF(MINUTE, t.created_at, t.completed_at) AS DECIMAL(10,2))
            ELSE NULL
        END
    ) AS avg_completion_minutes
FROM dbo.wms_picking_tasks AS t WITH (NOLOCK)
INNER JOIN dbo.stores AS orig WITH (NOLOCK)
    ON orig.store_id = t.origin_store_id
INNER JOIN dbo.stores AS dest WITH (NOLOCK)
    ON dest.store_id = t.destination_store_id
GROUP BY
    orig.store_code,
    dest.store_code,
    t.stage
ORDER BY
    pending_tasks DESC,
    in_progress_tasks DESC,
    t.stage;
