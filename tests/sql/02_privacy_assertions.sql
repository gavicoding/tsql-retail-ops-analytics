-- LGPD Art. 18 anonymization: proves the data subject is gone and nothing else broke.

SET NOCOUNT ON;

DECLARE @orders_before INT = (SELECT COUNT(*) FROM dbo.customer_orders);
DECLARE @total_before  DECIMAL(14,2) = (SELECT SUM(total_amount) FROM dbo.customer_orders);
DECLARE @joined_before INT = (
    SELECT COUNT(*) FROM dbo.customer_orders AS o JOIN dbo.customers AS c ON c.customer_id = o.customer_id
);

DECLARE @result TABLE (request_id INT, customer_id INT, request_state VARCHAR(20), completed_at DATETIME2(0), evidence_hash VARBINARY(32));
INSERT INTO @result EXEC dbo.usp_anonymize_customer @request_id = 1;

-- 1) personal data of customer 2 is gone, in every table that could hold it
IF EXISTS (
    SELECT 1 FROM dbo.customers
    WHERE tax_id = '987.654.321-00' OR email = 'joao.ficticio@exemplo.test'
       OR full_name LIKE N'%Ficticio%' OR phone = '+55 21 90000-0002'
)
    THROW 51201, 'Original personal data is still in dbo.customers.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.privacy_audit_log
    WHERE detail LIKE '%987.654.321-00%' OR detail LIKE '%joao.ficticio%' OR detail LIKE N'%Ficticio%'
)
    THROW 51202, 'The audit log must never contain personal data.', 1;

IF NOT EXISTS (
    SELECT 1 FROM dbo.customers
    WHERE customer_id = 2 AND is_anonymized = 1 AND tax_id LIKE 'ANON-%'
      AND email IS NULL AND phone IS NULL AND birth_date = '1992-01-01'
)
    THROW 51203, 'Customer row was not anonymized as designed.', 1;

-- 2) nothing else changed: orders, totals and foreign keys
IF (SELECT COUNT(*) FROM dbo.customer_orders) <> @orders_before
   OR (SELECT SUM(total_amount) FROM dbo.customer_orders) <> @total_before
   OR (SELECT COUNT(*) FROM dbo.customer_orders AS o JOIN dbo.customers AS c ON c.customer_id = o.customer_id) <> @joined_before
    THROW 51204, 'Orders, totals or referential integrity changed.', 1;

IF EXISTS (SELECT 1 FROM dbo.customers WHERE customer_id IN (1, 3) AND is_anonymized = 1)
    THROW 51205, 'Other customers must not be touched.', 1;

-- 3) accountability: request closed with evidence and one audit row
IF NOT EXISTS (SELECT 1 FROM @result WHERE request_state = 'DONE' AND evidence_hash IS NOT NULL)
    THROW 51206, 'Request must be DONE with an evidence hash.', 1;

IF (SELECT COUNT(*) FROM dbo.privacy_audit_log WHERE request_id = 1 AND action = 'ANONYMIZE') <> 1
    THROW 51207, 'Exactly one audit row is expected.', 1;

-- 4) the same request cannot run twice
DECLARE @failed BIT = 0;
BEGIN TRY
    EXEC dbo.usp_anonymize_customer @request_id = 1;
END TRY
BEGIN CATCH
    SET @failed = 1;
END CATCH
IF @failed = 0
    THROW 51208, 'Running the same erasure twice must be rejected.', 1;

PRINT 'All privacy assertions passed.';
