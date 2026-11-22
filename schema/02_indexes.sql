-- Covering and filtered indexes aligned with SARGable queries in /queries and /procedures.

CREATE NONCLUSTERED INDEX IX_sales_status_saleat
    ON dbo.sales (sale_status, sale_at, store_id, category_id)
    INCLUDE (net_amount);

CREATE NONCLUSTERED INDEX IX_asset_movements_asset_recent
    ON dbo.returnable_asset_movements (asset_code, moved_at DESC, movement_id DESC)
    INCLUDE (origin_store_id, destination_store_id, operator_badge, movement_type, return_status);

CREATE NONCLUSTERED INDEX IX_inventory_movements_movedat_item
    ON dbo.inventory_movements (moved_at, item_id)
    INCLUDE (store_id, movement_type, quantity);

CREATE NONCLUSTERED INDEX IX_wms_tasks_pending
    ON dbo.wms_picking_tasks (task_status, stage, destination_store_id)
    INCLUDE (origin_store_id, created_at)
    WHERE task_status IN ('PENDING', 'IN_PROGRESS');

CREATE NONCLUSTERED INDEX IX_fiscal_transmissions_date_status
    ON dbo.fiscal_transmissions (business_date, store_id, transmission_status);
