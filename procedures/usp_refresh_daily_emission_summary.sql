-- Incremental pre-aggregation of a large fiscal transmission log.
--
-- Production lesson behind it:
--   * Summarising 12 months of the raw log in one query took more than 2 minutes and
--     hit the application timeout. Instead, each run refreshes only a small window of
--     days (@days_per_run): first the days never summarised, then the most recent
--     ones (which can still change). The dashboard reads the small summary table.
--   * MERGE upserts each (business_date, store_id) row, so reruns are idempotent.

CREATE OR ALTER PROCEDURE dbo.usp_refresh_daily_emission_summary
    @days_per_run INT  = 8,
    @today        DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @today = ISNULL(@today, CAST(SYSDATETIME() AS DATE));

    DECLARE @days TABLE (business_date DATE NOT NULL PRIMARY KEY);

    -- 1) days present in the log but never summarised, oldest first
    INSERT INTO @days (business_date)
    SELECT TOP (@days_per_run) f.business_date
    FROM dbo.fiscal_transmissions AS f
    WHERE f.business_date <= @today
      AND NOT EXISTS (
          SELECT 1 FROM dbo.daily_emission_summary AS d WHERE d.business_date = f.business_date
      )
    GROUP BY f.business_date
    ORDER BY f.business_date;

    -- 2) the last two days are always refreshed (late retries change them)
    INSERT INTO @days (business_date)
    SELECT v.d
    FROM (VALUES (@today), (DATEADD(DAY, -1, @today))) AS v(d)
    WHERE NOT EXISTS (SELECT 1 FROM @days AS x WHERE x.business_date = v.d);

    -- A document counts once, in its latest state of the day.
    WITH latest AS (
        SELECT
            f.business_date,
            f.store_id,
            f.transmission_status,
            ROW_NUMBER() OVER (
                PARTITION BY f.business_date, f.store_id, f.document_number
                ORDER BY f.attempted_at DESC, f.transmission_id DESC
            ) AS rn
        FROM dbo.fiscal_transmissions AS f
        JOIN @days AS d ON d.business_date = f.business_date
    ),
    agg AS (
        SELECT
            business_date,
            store_id,
            SUM(CASE WHEN transmission_status = 'AUTHORIZED'  THEN 1 ELSE 0 END) AS authorized_docs,
            SUM(CASE WHEN transmission_status = 'CONTINGENCY' THEN 1 ELSE 0 END) AS contingency_docs,
            SUM(CASE WHEN transmission_status = 'REJECTED'    THEN 1 ELSE 0 END) AS rejected_docs
        FROM latest
        WHERE rn = 1
        GROUP BY business_date, store_id
    )
    MERGE dbo.daily_emission_summary AS tgt
    USING agg AS src
        ON tgt.business_date = src.business_date
       AND tgt.store_id      = src.store_id
    WHEN MATCHED THEN
        UPDATE SET
            authorized_docs  = src.authorized_docs,
            contingency_docs = src.contingency_docs,
            rejected_docs    = src.rejected_docs,
            refreshed_at     = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (business_date, store_id, authorized_docs, contingency_docs, rejected_docs)
        VALUES (src.business_date, src.store_id, src.authorized_docs, src.contingency_docs, src.rejected_docs);

    SELECT business_date FROM @days ORDER BY business_date;
END;
