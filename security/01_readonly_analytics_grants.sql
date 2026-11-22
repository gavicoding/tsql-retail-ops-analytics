-- Least-privilege RBAC setup for read-only reporting and monitoring services.
-- Grants explicit SELECT permissions only on approved tables while denying DML writes.

IF DATABASE_PRINCIPAL_ID('db_readonly_analytics') IS NULL
BEGIN
    CREATE ROLE db_readonly_analytics;
END;

GRANT SELECT ON dbo.stores                      TO db_readonly_analytics;
GRANT SELECT ON dbo.product_categories          TO db_readonly_analytics;
GRANT SELECT ON dbo.sales                       TO db_readonly_analytics;
GRANT SELECT ON dbo.returnable_asset_movements  TO db_readonly_analytics;
GRANT SELECT ON dbo.inventory_items             TO db_readonly_analytics;
GRANT SELECT ON dbo.inventory_movements         TO db_readonly_analytics;
GRANT SELECT ON dbo.pos_cash_reconciliation     TO db_readonly_analytics;
GRANT SELECT ON dbo.fiscal_transmissions        TO db_readonly_analytics;
GRANT SELECT ON dbo.wms_picking_tasks           TO db_readonly_analytics;
GRANT SELECT ON dbo.db_latency_lock_logs        TO db_readonly_analytics;

-- Explicitly block write operations on the dbo schema for this reporting role.
DENY INSERT, UPDATE, DELETE, ALTER ON SCHEMA::dbo TO db_readonly_analytics;
