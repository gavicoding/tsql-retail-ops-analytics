-- Idempotent, set-based ingest of an invoice batch coming from an external API.
--
-- Production lesson behind it:
--   * The legacy tool inserted one row per round trip (100 per page) and crashed the
--     whole run on the first duplicate. Here one statement ingests the batch.
--   * The target has a UNIQUE registry_id but access_key is not unique, so the guard
--     checks BOTH keys. Duplicates inside the batch itself are removed first.
--   * UPDLOCK + HOLDLOCK on the NOT EXISTS probes stops two concurrent runs from
--     inserting the same invoice between the check and the insert.
--   * OUTPUT ... INTO a table variable (not a bare OUTPUT) keeps working even if a
--     trigger is added to the table later, and tells the caller exactly what was new.

CREATE OR ALTER PROCEDURE dbo.usp_ingest_invoice_index_batch
    @batch_id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @inserted TABLE (access_key CHAR(44) NOT NULL, registry_id BIGINT NOT NULL);

    BEGIN TRY
        BEGIN TRANSACTION;

        WITH batch AS (
            SELECT
                st.access_key,
                st.registry_id,
                st.issued_at,
                st.imported_at,
                st.total_amount,
                ROW_NUMBER() OVER (PARTITION BY st.access_key ORDER BY st.imported_at DESC, st.registry_id DESC) AS rn_key,
                ROW_NUMBER() OVER (PARTITION BY st.registry_id ORDER BY st.imported_at DESC) AS rn_reg
            FROM dbo.invoice_ingest_staging AS st
            WHERE st.batch_id = @batch_id
              AND LEN(st.access_key) = 44
        )
        INSERT INTO dbo.invoice_platform_index (access_key, registry_id, issued_at, imported_at, total_amount)
        OUTPUT inserted.access_key, inserted.registry_id INTO @inserted (access_key, registry_id)
        SELECT b.access_key, b.registry_id, b.issued_at, b.imported_at, b.total_amount
        FROM batch AS b
        WHERE b.rn_key = 1
          AND b.rn_reg = 1
          AND NOT EXISTS (
              SELECT 1 FROM dbo.invoice_platform_index AS t WITH (UPDLOCK, HOLDLOCK)
              WHERE t.access_key = b.access_key
          )
          AND NOT EXISTS (
              SELECT 1 FROM dbo.invoice_platform_index AS t WITH (UPDLOCK, HOLDLOCK)
              WHERE t.registry_id = b.registry_id
          );

        DELETE FROM dbo.invoice_ingest_staging WHERE batch_id = @batch_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;
        THROW;
    END CATCH

    SELECT access_key, registry_id FROM @inserted ORDER BY registry_id;
END;
