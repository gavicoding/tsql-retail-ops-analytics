-- Synthetic T-SQL schema modeling multi-store retail sales, returnable logistics,
-- inventory, POS/fiscal reconciliation, WMS picking, and DBA diagnostics.

CREATE TABLE dbo.stores (
    store_id   INT           NOT NULL PRIMARY KEY,
    store_code VARCHAR(16)   NOT NULL UNIQUE,
    store_name NVARCHAR(100) NOT NULL,
    region     NVARCHAR(60)  NOT NULL,
    is_active  BIT           NOT NULL DEFAULT 1
);

CREATE TABLE dbo.product_categories (
    category_id   INT          NOT NULL PRIMARY KEY,
    category_name NVARCHAR(80) NOT NULL,
    is_strategic  BIT          NOT NULL DEFAULT 0
);

CREATE TABLE dbo.sales (
    sale_id     BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,
    store_id    INT           NOT NULL REFERENCES dbo.stores(store_id),
    category_id INT           NOT NULL REFERENCES dbo.product_categories(category_id),
    sale_at     DATETIME2(0)  NOT NULL,
    net_amount  DECIMAL(12,2) NOT NULL,
    sale_status VARCHAR(20)   NOT NULL CHECK (sale_status IN ('COMPLETED', 'CANCELLED'))
);

CREATE TABLE dbo.returnable_asset_movements (
    movement_id          BIGINT       IDENTITY(1,1) NOT NULL PRIMARY KEY,
    asset_code           VARCHAR(32)  NOT NULL,
    origin_store_id      INT          NOT NULL REFERENCES dbo.stores(store_id),
    destination_store_id INT          NOT NULL REFERENCES dbo.stores(store_id),
    operator_badge       VARCHAR(20)  NOT NULL,
    movement_type        VARCHAR(20)  NOT NULL CHECK (movement_type IN ('DISPATCH', 'CHECKIN', 'RETURN')),
    return_status        VARCHAR(20)  NOT NULL CHECK (return_status IN ('PENDING', 'RETURNED')),
    moved_at             DATETIME2(0) NOT NULL
);

CREATE TABLE dbo.inventory_items (
    item_id          INT           NOT NULL PRIMARY KEY,
    product_code     VARCHAR(32)   NOT NULL UNIQUE,
    item_description NVARCHAR(120) NOT NULL,
    unit_of_measure  VARCHAR(10)   NOT NULL,
    is_active        BIT           NOT NULL DEFAULT 1
);

CREATE TABLE dbo.inventory_movements (
    movement_id   BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,
    item_id       INT           NOT NULL REFERENCES dbo.inventory_items(item_id),
    store_id      INT           NOT NULL REFERENCES dbo.stores(store_id),
    movement_type VARCHAR(20)   NOT NULL CHECK (movement_type IN ('INBOUND', 'OUTBOUND', 'ADJUSTMENT')),
    quantity      DECIMAL(12,2) NOT NULL,
    moved_at      DATETIME2(0)  NOT NULL
);

CREATE TABLE dbo.pos_cash_reconciliation (
    reconciliation_id BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,
    store_id          INT           NOT NULL REFERENCES dbo.stores(store_id),
    business_date     DATE          NOT NULL,
    payment_method    VARCHAR(30)   NOT NULL,
    expected_amount   DECIMAL(12,2) NOT NULL,
    settled_amount    DECIMAL(12,2) NOT NULL
);

CREATE TABLE dbo.fiscal_transmissions (
    transmission_id     BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,
    store_id            INT           NOT NULL REFERENCES dbo.stores(store_id),
    document_number     VARCHAR(30)   NOT NULL,
    business_date       DATE          NOT NULL,
    transmission_status VARCHAR(20)   NOT NULL CHECK (transmission_status IN ('AUTHORIZED', 'CONTINGENCY', 'REJECTED')),
    error_message       NVARCHAR(200) NULL,
    attempted_at        DATETIME2(0)  NOT NULL
);

CREATE TABLE dbo.wms_picking_tasks (
    task_id              BIGINT       IDENTITY(1,1) NOT NULL PRIMARY KEY,
    origin_store_id      INT          NOT NULL REFERENCES dbo.stores(store_id),
    destination_store_id INT          NOT NULL REFERENCES dbo.stores(store_id),
    stage                VARCHAR(20)  NOT NULL CHECK (stage IN ('PICKING', 'CHECKOUT', 'TRANSFER')),
    task_status          VARCHAR(20)  NOT NULL CHECK (task_status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED')),
    operator_badge       VARCHAR(20)  NULL,
    created_at           DATETIME2(0) NOT NULL,
    completed_at         DATETIME2(0) NULL
);

CREATE TABLE dbo.integration_config (
    config_id    INT           IDENTITY(1,1) NOT NULL PRIMARY KEY,
    config_key   VARCHAR(80)   NOT NULL UNIQUE,
    config_value NVARCHAR(400) NOT NULL,
    updated_at   DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.db_latency_lock_logs (
    log_id           BIGINT       IDENTITY(1,1) NOT NULL PRIMARY KEY,
    captured_at      DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    session_id       INT          NOT NULL,
    database_id      INT          NOT NULL,
    resource_type    VARCHAR(60)  NOT NULL,
    request_mode     VARCHAR(30)  NOT NULL,
    request_status   VARCHAR(30)  NOT NULL,
    wait_duration_ms BIGINT       NULL
);
