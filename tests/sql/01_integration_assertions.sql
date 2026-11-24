-- Integration assertions executed against a real SQL Server 2022 container in CI.
-- Any wrong result raises an error and fails the build.

SET NOCOUNT ON;

------------------------------------------------------------------------------
-- 1) Optional product filter: blank / invalid text never breaks, filter works
------------------------------------------------------------------------------
CREATE TABLE #report (
    store_id INT, invoice_number VARCHAR(20), issued_at DATETIME2(0), posted_at DATETIME2(0),
    access_key CHAR(44), supplier_name NVARCHAR(100), product_code VARCHAR(32), item_description NVARCHAR(120),
    quantity DECIMAL(12,3), pack_size DECIMAL(12,3), total_units DECIMAL(25,6), unit_price DECIMAL(12,4),
    line_total DECIMAL(14,2), net_unit_cost DECIMAL(12,4), total_cost DECIMAL(38,6), cost_status VARCHAR(20)
);

DECLARE @cases TABLE (product_text NVARCHAR(30) NULL, expected_rows INT NOT NULL);
INSERT INTO @cases VALUES (NULL, 6), (N'', 6), (N'$', 6), (N'1e5', 6), (N'12,5', 6), (N'1', 2), (N' 3 ', 2), (N'999', 0);

DECLARE @p NVARCHAR(30), @expected INT, @got INT, @msg NVARCHAR(400);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT product_text, expected_rows FROM @cases;
OPEN c;
FETCH NEXT FROM c INTO @p, @expected;
WHILE @@FETCH_STATUS = 0
BEGIN
    TRUNCATE TABLE #report;
    INSERT INTO #report EXEC dbo.usp_purchase_items_report '2026-11-01T00:00:00', '2026-11-30T23:59:59', @p;
    SET @got = (SELECT COUNT(*) FROM #report);
    IF @got <> @expected
    BEGIN
        SET @msg = CONCAT(N'usp_purchase_items_report(', ISNULL(@p, N'NULL'), N') returned ', @got, N' rows, expected ', @expected);
        THROW 51001, @msg, 1;
    END
    FETCH NEXT FROM c INTO @p, @expected;
END
CLOSE c;
DEALLOCATE c;

TRUNCATE TABLE #report;
INSERT INTO #report EXEC dbo.usp_purchase_items_report '2026-11-01T00:00:00', '2026-11-30T23:59:59', N'3';
IF NOT EXISTS (SELECT 1 FROM #report WHERE invoice_number = '1907' AND total_cost = 2970 AND cost_status = 'PENDING_COST')
    THROW 51002, 'Cost fallback (net -> gross) is wrong for a line with pending net cost.', 1;

------------------------------------------------------------------------------
-- 2) Idempotent batch ingest: in-batch duplicates, existing key and existing
--    registry are all skipped; running the same batch twice inserts nothing
------------------------------------------------------------------------------
DECLARE @inserted TABLE (access_key CHAR(44), registry_id BIGINT);
DECLARE @batch UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.invoice_ingest_staging (batch_id, access_key, registry_id, issued_at, imported_at, total_amount) VALUES
    (@batch, '35261111222333000181550010000482111000000011', 90000101, '2026-11-03', '2026-11-03T10:00:00', 2420.00), -- key exists
    (@batch, '35261155666777000199550010000000051000000055', 90000005, '2026-11-20', '2026-11-20T10:00:00', 100.00),  -- new
    (@batch, '35261155666777000199550010000000051000000055', 90000005, '2026-11-20', '2026-11-20T09:00:00', 100.00),  -- dup in batch
    (@batch, '35261166777888000110550010000000061000000066', 90000002, '2026-11-20', '2026-11-20T10:00:00', 200.00),  -- registry exists
    (@batch, '35261177888999000121550010000000071000000077', 90000007, '2026-11-20', '2026-11-20T10:00:00', 300.00);  -- new

INSERT INTO @inserted EXEC dbo.usp_ingest_invoice_index_batch @batch;
IF (SELECT COUNT(*) FROM @inserted) <> 2
    THROW 51003, 'Batch ingest should insert exactly 2 new invoices.', 1;
IF EXISTS (SELECT 1 FROM dbo.invoice_ingest_staging WHERE batch_id = @batch)
    THROW 51004, 'Staging rows of the batch should be cleared.', 1;

DELETE FROM @inserted;
SET @batch = NEWID();
INSERT INTO dbo.invoice_ingest_staging (batch_id, access_key, registry_id, issued_at, imported_at, total_amount) VALUES
    (@batch, '35261155666777000199550010000000051000000055', 90000005, '2026-11-20', '2026-11-20T10:00:00', 100.00),
    (@batch, '35261177888999000121550010000000071000000077', 90000007, '2026-11-20', '2026-11-20T10:00:00', 300.00);
INSERT INTO @inserted EXEC dbo.usp_ingest_invoice_index_batch @batch;
IF (SELECT COUNT(*) FROM @inserted) <> 0
    THROW 51005, 'Re-running the same invoices must insert nothing (idempotency).', 1;

------------------------------------------------------------------------------
-- 3) Incremental pre-aggregation: latest state per document, idempotent reruns
------------------------------------------------------------------------------
DECLARE @refreshed TABLE (business_date DATE);
INSERT INTO @refreshed EXEC dbo.usp_refresh_daily_emission_summary @days_per_run = 8, @today = '2026-11-20';
IF (SELECT COUNT(*) FROM @refreshed) <> 3
    THROW 51006, 'Expected 3 days refreshed (18, 19 and 20).', 1;

IF NOT EXISTS (
    SELECT 1 FROM dbo.daily_emission_summary
    WHERE business_date = '2026-11-19' AND store_id = 101 AND authorized_docs = 2 AND contingency_docs = 0
)
    THROW 51007, 'A document authorised after contingency must count as authorised only.', 1;

DECLARE @rows_before INT = (SELECT COUNT(*) FROM dbo.daily_emission_summary);
DELETE FROM @refreshed;
INSERT INTO @refreshed EXEC dbo.usp_refresh_daily_emission_summary @days_per_run = 8, @today = '2026-11-20';
IF (SELECT COUNT(*) FROM dbo.daily_emission_summary) <> @rows_before
    THROW 51008, 'Re-running the summary must not duplicate rows.', 1;

------------------------------------------------------------------------------
-- 4) Time-boxed access: only valid extensions are accepted
------------------------------------------------------------------------------
DECLARE @win TABLE (window_id INT, grantee VARCHAR(60), starts_at DATETIME2(0), ends_at DATETIME2(0));
INSERT INTO @win EXEC dbo.usp_extend_access_window @window_id = 1, @new_ends_at = '2026-11-20T14:00:00';
IF NOT EXISTS (SELECT 1 FROM dbo.access_windows WHERE window_id = 1 AND ends_at = '2026-11-20T14:00:00')
    THROW 51009, 'Valid extension was not applied.', 1;

DECLARE @failed BIT = 0;
BEGIN TRY
    EXEC dbo.usp_extend_access_window @window_id = 1, @new_ends_at = '2026-11-20T13:00:00';
END TRY
BEGIN CATCH
    SET @failed = 1;
END CATCH
IF @failed = 0
    THROW 51010, 'Shortening a window must be rejected.', 1;

PRINT 'All integration assertions passed.';
