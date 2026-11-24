-- Synthetic customer data and privacy (LGPD / GDPR) request tracking.

CREATE TABLE dbo.customers (
    customer_id   INT           NOT NULL PRIMARY KEY,
    full_name     NVARCHAR(120) NOT NULL,
    tax_id        VARCHAR(40)   NOT NULL UNIQUE,      -- CPF in real life
    email         VARCHAR(160)  NULL,
    phone         VARCHAR(30)   NULL,
    birth_date    DATE          NULL,
    city          NVARCHAR(80)  NULL,
    created_at    DATETIME2(0)  NOT NULL,
    is_anonymized BIT           NOT NULL DEFAULT 0,
    anonymized_at DATETIME2(0)  NULL
);

CREATE TABLE dbo.customer_orders (
    order_id     BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_id  INT           NOT NULL REFERENCES dbo.customers(customer_id),
    store_id     INT           NOT NULL REFERENCES dbo.stores(store_id),
    ordered_at   DATETIME2(0)  NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL
);

CREATE TABLE dbo.privacy_requests (
    request_id    INT            IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_id   INT            NOT NULL REFERENCES dbo.customers(customer_id),
    request_type  VARCHAR(20)    NOT NULL CHECK (request_type IN ('ACCESS', 'CORRECTION', 'ERASURE')),
    requested_at  DATETIME2(0)   NOT NULL,
    request_state VARCHAR(20)    NOT NULL DEFAULT 'OPEN' CHECK (request_state IN ('OPEN', 'DONE', 'REJECTED')),
    completed_at  DATETIME2(0)   NULL,
    evidence_hash VARBINARY(32)  NULL
);

-- Audit trail of privacy actions. Never stores personal data, only ids and facts.
CREATE TABLE dbo.privacy_audit_log (
    audit_id    BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,
    request_id  INT           NOT NULL REFERENCES dbo.privacy_requests(request_id),
    customer_id INT           NOT NULL,
    action      VARCHAR(40)   NOT NULL,
    detail      NVARCHAR(200) NOT NULL,
    performed_by SYSNAME      NOT NULL DEFAULT ORIGINAL_LOGIN(),
    performed_at DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
