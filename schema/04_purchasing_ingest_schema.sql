-- Synthetic purchasing, invoice-ingest and time-boxed access tables used by the
-- production patterns in /procedures, /queries, /observability and /security.

CREATE TABLE dbo.suppliers (
    supplier_id   INT           NOT NULL PRIMARY KEY,
    supplier_name NVARCHAR(100) NOT NULL,
    tax_id        VARCHAR(18)   NOT NULL UNIQUE
);

CREATE TABLE dbo.purchase_invoices (
    invoice_id     BIGINT       IDENTITY(1,1) NOT NULL PRIMARY KEY,
    store_id       INT          NOT NULL REFERENCES dbo.stores(store_id),
    supplier_id    INT          NOT NULL REFERENCES dbo.suppliers(supplier_id),
    invoice_number VARCHAR(20)  NOT NULL,
    access_key     CHAR(44)     NOT NULL UNIQUE,
    issued_at      DATETIME2(0) NOT NULL,
    posted_at      DATETIME2(0) NOT NULL
);

CREATE TABLE dbo.purchase_invoice_items (
    line_id    BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,
    invoice_id BIGINT        NOT NULL REFERENCES dbo.purchase_invoices(invoice_id),
    item_id    INT           NOT NULL REFERENCES dbo.inventory_items(item_id),
    quantity   DECIMAL(12,3) NOT NULL,
    pack_size  DECIMAL(12,3) NOT NULL DEFAULT 1,
    unit_price DECIMAL(12,4) NOT NULL,
    line_total DECIMAL(14,2) NOT NULL
);

-- Cost is calculated later by another process, so it can still be NULL.
CREATE TABLE dbo.item_cost_snapshots (
    line_id         BIGINT        NOT NULL PRIMARY KEY REFERENCES dbo.purchase_invoice_items(line_id),
    net_unit_cost   DECIMAL(12,4) NULL,
    gross_unit_cost DECIMAL(12,4) NULL
);

-- Local copy of invoices already processed by an external fiscal platform.
-- access_key is NOT unique on purpose (it mirrors a real-world table that never
-- enforced it); registry_id is unique. The ingest procedure must respect both.
CREATE TABLE dbo.invoice_platform_index (
    index_id     BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,
    access_key   CHAR(44)      NOT NULL,
    registry_id  BIGINT        NOT NULL,
    issued_at    DATETIME2(0)  NULL,
    imported_at  DATETIME2(0)  NULL,
    total_amount DECIMAL(14,2) NULL,
    recorded_at  DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT UK_invoice_platform_index_registry UNIQUE (registry_id)
);

CREATE TABLE dbo.invoice_ingest_staging (
    batch_id     UNIQUEIDENTIFIER NOT NULL,
    access_key   CHAR(44)         NOT NULL,
    registry_id  BIGINT           NOT NULL,
    issued_at    DATETIME2(0)     NULL,
    imported_at  DATETIME2(0)     NULL,
    total_amount DECIMAL(14,2)    NULL
);

CREATE TABLE dbo.daily_emission_summary (
    business_date    DATE         NOT NULL,
    store_id         INT          NOT NULL REFERENCES dbo.stores(store_id),
    authorized_docs  INT          NOT NULL,
    contingency_docs INT          NOT NULL,
    rejected_docs    INT          NOT NULL,
    refreshed_at     DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_daily_emission_summary PRIMARY KEY (business_date, store_id)
);

CREATE TABLE dbo.access_windows (
    window_id INT           IDENTITY(1,1) NOT NULL PRIMARY KEY,
    grantee   VARCHAR(60)   NOT NULL,
    starts_at DATETIME2(0)  NOT NULL,
    ends_at   DATETIME2(0)  NOT NULL,
    reason    NVARCHAR(200) NOT NULL,
    CONSTRAINT CK_access_windows_range CHECK (ends_at > starts_at)
);

CREATE NONCLUSTERED INDEX IX_purchase_invoices_issued
    ON dbo.purchase_invoices (issued_at)
    INCLUDE (store_id, supplier_id, invoice_number, access_key, posted_at);

CREATE NONCLUSTERED INDEX IX_purchase_items_item
    ON dbo.purchase_invoice_items (item_id, invoice_id)
    INCLUDE (quantity, pack_size, unit_price, line_total);

CREATE NONCLUSTERED INDEX IX_invoice_platform_index_key
    ON dbo.invoice_platform_index (access_key);
