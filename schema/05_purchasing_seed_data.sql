-- Synthetic purchasing data (100% fictional suppliers, keys and values).

INSERT INTO dbo.suppliers (supplier_id, supplier_name, tax_id) VALUES
    (1, N'Example Distribution Ltd',  '11.222.333/0001-81'),
    (2, N'Fictional Supplies Inc',    '22.333.444/0001-05'),
    (3, N'Demo Wholesale Co',         '33.444.555/0001-40');

INSERT INTO dbo.purchase_invoices (store_id, supplier_id, invoice_number, access_key, issued_at, posted_at) VALUES
    (100, 1, '48211', '35261111222333000181550010000482111000000011', '2026-11-03T09:00:00', '2026-11-03T15:00:00'),
    (100, 2, '1907',  '35261122333444000105550010000019071000000022', '2026-11-05T10:30:00', '2026-11-06T08:00:00'),
    (101, 3, '77054', '35261133444555000140550010000770541000000033', '2026-11-10T14:00:00', '2026-11-10T17:30:00'),
    (100, 1, '48302', '35261111222333000181550010000483021000000044', '2026-11-18T08:45:00', '2026-11-18T11:00:00');

-- invoice_id follows the IDENTITY order above (1..4)
INSERT INTO dbo.purchase_invoice_items (invoice_id, item_id, quantity, pack_size, unit_price, line_total) VALUES
    (1, 1, 2, 1, 850.0000, 1700.00),
    (1, 2, 1, 6, 120.0000,  720.00),
    (2, 3, 3, 1, 990.0000, 2970.00),
    (3, 2, 2, 6, 118.5000, 1422.00),
    (4, 1, 1, 1, 870.0000,  870.00),
    (4, 3, 1, 1, 985.0000,  985.00);

-- line 5 (invoice 4, item 1) still waits for cost processing (NULL costs)
INSERT INTO dbo.item_cost_snapshots (line_id, net_unit_cost, gross_unit_cost) VALUES
    (1, 812.0000, 850.0000),
    (2, 110.0000, 120.0000),
    (3, NULL,     990.0000),
    (4, 109.2000, 118.5000),
    (5, NULL,     NULL),
    (6, 940.0000, 985.0000);

INSERT INTO dbo.invoice_platform_index (access_key, registry_id, issued_at, imported_at, total_amount) VALUES
    ('35261111222333000181550010000482111000000011', 90000001, '2026-11-03T09:00:00', '2026-11-03T09:05:00', 2420.00),
    ('35261122333444000105550010000019071000000022', 90000002, '2026-11-05T10:30:00', '2026-11-05T10:41:00', 2970.00);

INSERT INTO dbo.fiscal_transmissions (store_id, document_number, business_date, transmission_status, error_message, attempted_at) VALUES
    (101, 'NF-000102', '2026-11-19', 'AUTHORIZED',  NULL,                           '2026-11-19T20:00:00'),
    (101, 'NF-000103', '2026-11-19', 'CONTINGENCY', N'Offline mode - retry queued', '2026-11-19T20:10:00'),
    (101, 'NF-000103', '2026-11-19', 'AUTHORIZED',  NULL,                           '2026-11-19T22:40:00'),
    (102, 'NF-000206', '2026-11-19', 'CONTINGENCY', N'Offline mode - retry queued', '2026-11-19T19:30:00'),
    (102, 'NF-000207', '2026-11-18', 'CONTINGENCY', N'Offline mode - retry queued', '2026-11-18T18:00:00'),
    (103, 'NF-000312', '2026-11-18', 'AUTHORIZED',  NULL,                           '2026-11-18T12:00:00');

INSERT INTO dbo.access_windows (grantee, starts_at, ends_at, reason) VALUES
    ('vendor.analyst', '2026-11-20T09:00:00', '2026-11-20T12:00:00', N'Ticket 4821: monthly report check');
