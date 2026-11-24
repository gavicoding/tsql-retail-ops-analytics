-- LGPD Art. 18 / GDPR Art. 17: irreversible anonymization of one data subject,
-- keeping referential integrity and every aggregate (orders, totals) intact.
--
-- Design decisions (the "why" a DPO reviewer looks for):
--   * Irreversible: name, email and phone are removed. The CPF is replaced by a
--     RANDOM surrogate, never by a hash: a hash of a CPF can be reversed by brute force
--     (the whole CPF space fits in about 10^9 guesses), so it would only be pseudonymised.
--   * Useful afterwards: the customer row stays (orders keep their foreign key), the
--     birth date is generalised to the year so age-band reports still work, and the city
--     stays for regional totals.
--   * Fiscal records are not deleted: orders and invoices must be kept for the legal
--     retention period (LGPD Art. 16, I). They no longer point to an identifiable person.
--   * Accountable: the request is closed with an evidence hash and an audit row that
--     contain only ids and timestamps, never personal data.
--   * Safe: one transaction, refuses a request that is not an open ERASURE for this
--     customer, and refuses to anonymize twice.

CREATE OR ALTER PROCEDURE dbo.usp_anonymize_customer
    @request_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @customer_id INT;
    DECLARE @now DATETIME2(0) = SYSDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @customer_id = r.customer_id
        FROM dbo.privacy_requests AS r WITH (UPDLOCK, HOLDLOCK)
        WHERE r.request_id    = @request_id
          AND r.request_type  = 'ERASURE'
          AND r.request_state = 'OPEN';

        IF @customer_id IS NULL
        BEGIN
            THROW 51100, 'No open ERASURE request with this id.', 1;
        END;

        IF EXISTS (SELECT 1 FROM dbo.customers WHERE customer_id = @customer_id AND is_anonymized = 1)
        BEGIN
            THROW 51101, 'Customer is already anonymized.', 1;
        END;

        UPDATE dbo.customers
        SET full_name     = N'Anonymized customer',
            tax_id        = 'ANON-' + REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            email         = NULL,
            phone         = NULL,
            birth_date    = DATEFROMPARTS(YEAR(birth_date), 1, 1),
            is_anonymized = 1,
            anonymized_at = @now
        WHERE customer_id = @customer_id;

        UPDATE dbo.privacy_requests
        SET request_state = 'DONE',
            completed_at  = @now,
            evidence_hash = HASHBYTES('SHA2_256',
                CONCAT(@request_id, '|', @customer_id, '|', CONVERT(VARCHAR(19), @now, 126)))
        WHERE request_id = @request_id;

        INSERT INTO dbo.privacy_audit_log (request_id, customer_id, action, detail)
        VALUES (@request_id, @customer_id, 'ANONYMIZE',
                N'Personal fields removed or generalised; orders kept for legal retention.');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;
        THROW;
    END CATCH

    SELECT r.request_id, r.customer_id, r.request_state, r.completed_at, r.evidence_hash
    FROM dbo.privacy_requests AS r
    WHERE r.request_id = @request_id;
END;
