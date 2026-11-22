-- Synthetic sample data (100% fictional stores, assets, and metrics).

INSERT INTO dbo.stores (store_id, store_code, store_name, region, is_active) VALUES
    (100, 'DC-00', N'Central Distribution Center', N'Hub',   1),
    (101, 'ST-01', N'Downtown Flagship Store',     N'North', 1),
    (102, 'ST-02', N'Westside Express Store',      N'West',  1),
    (103, 'ST-03', N'South Plaza Store',           N'South', 1);

INSERT INTO dbo.product_categories (category_id, category_name, is_strategic) VALUES
    (10, N'Private Label Essentials', 1),
    (20, N'Exclusive Care Line',      1),
    (30, N'General Merchandise',      0),
    (40, N'Beverages & Snacks',       0);

INSERT INTO dbo.sales (store_id, category_id, sale_at, net_amount, sale_status) VALUES
    (101, 10, '2026-11-20T09:15:00', 450.00, 'COMPLETED'),
    (101, 20, '2026-11-20T11:30:00', 300.00, 'COMPLETED'),
    (101, 30, '2026-11-20T14:10:00', 250.00, 'COMPLETED'),
    (101, 10, '2026-11-20T16:00:00', 120.00, 'CANCELLED'),
    (102, 10, '2026-11-20T10:05:00', 200.00, 'COMPLETED'),
    (102, 40, '2026-11-20T18:45:00', 600.00, 'COMPLETED');

INSERT INTO dbo.returnable_asset_movements
    (asset_code, origin_store_id, destination_store_id, operator_badge, movement_type, return_status, moved_at)
VALUES
    ('BOX-1001', 100, 101, 'OP-412', 'DISPATCH', 'PENDING',  '2026-11-01T08:00:00'),
    ('BOX-1001', 101, 100, 'OP-412', 'RETURN',   'RETURNED', '2026-11-05T14:20:00'),
    ('BOX-1001', 100, 102, 'OP-518', 'DISPATCH', 'PENDING',  '2026-11-12T09:10:00'),
    ('BOX-1002', 100, 103, 'OP-609', 'DISPATCH', 'PENDING',  '2026-11-08T07:45:00'),
    ('BOX-1003', 100, 101, 'OP-412', 'DISPATCH', 'PENDING',  '2026-11-18T10:00:00'),
    ('BOX-1003', 101, 100, 'OP-412', 'RETURN',   'RETURNED', '2026-11-19T16:30:00');

INSERT INTO dbo.inventory_items (item_id, product_code, item_description, unit_of_measure, is_active) VALUES
    (1, 'IT-THERM-01', N'Thermal Receipt Printer', 'UN', 1),
    (2, 'IT-SCAN-02',  N'USB Barcode Scanner',     'UN', 1),
    (3, 'IT-UPS-03',   N'POS Backup UPS 1200VA',   'UN', 1);

INSERT INTO dbo.inventory_movements (item_id, store_id, movement_type, quantity, moved_at) VALUES
    (1, 101, 'OUTBOUND',   4.00, '2026-11-19T09:00:00'),
    (2, 102, 'OUTBOUND',   6.00, '2026-11-20T10:30:00'),
    (1, 100, 'ADJUSTMENT', 0.00, '2026-11-20T15:00:00');

INSERT INTO dbo.pos_cash_reconciliation (store_id, business_date, payment_method, expected_amount, settled_amount) VALUES
    (101, '2026-11-20', 'CARD_CREDIT', 5200.00, 5200.00),
    (101, '2026-11-20', 'INSTANT_PIX', 3100.00, 3100.00),
    (102, '2026-11-20', 'CARD_DEBIT',  2400.00, 2280.00),
    (103, '2026-11-20', 'CASH',        1500.00, 1500.00);

INSERT INTO dbo.fiscal_transmissions (store_id, document_number, business_date, transmission_status, error_message, attempted_at) VALUES
    (101, 'NF-000101', '2026-11-20', 'AUTHORIZED',  NULL,                           '2026-11-20T21:00:00'),
    (102, 'NF-000205', '2026-11-20', 'CONTINGENCY', N'SEFAZ timeout - retry queued', '2026-11-20T21:05:00'),
    (103, 'NF-000311', '2026-11-20', 'REJECTED',    N'Tax rule mismatch on SKU',     '2026-11-20T21:10:00');

INSERT INTO dbo.wms_picking_tasks (origin_store_id, destination_store_id, stage, task_status, operator_badge, created_at, completed_at) VALUES
    (100, 101, 'PICKING',  'COMPLETED',   'WH-101', '2026-11-20T06:00:00', '2026-11-20T06:22:00'),
    (100, 102, 'PICKING',  'PENDING',     NULL,     '2026-11-20T06:15:00', NULL),
    (100, 102, 'CHECKOUT', 'IN_PROGRESS', 'WH-105', '2026-11-20T07:00:00', NULL),
    (100, 103, 'TRANSFER', 'PENDING',     NULL,     '2026-11-20T07:30:00', NULL);

INSERT INTO dbo.integration_config (config_key, config_value) VALUES
    ('sync_webhook_url', N'https://hooks.example.invalid/retail-ops'),
    ('sync_timeout_ms',  N'5000');
