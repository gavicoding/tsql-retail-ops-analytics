-- Least-privilege automation for time-boxed access windows.
--
-- Production lesson behind it:
--   * A bot extends temporary database access when a request is approved. It must be
--     able to move the END of a window and nothing else: no new windows, no earlier
--     start, no deletes, no direct table writes.
--   * The bot's role gets EXECUTE on one procedure only; ownership chaining lets the
--     procedure update the table while direct DML stays denied.

CREATE OR ALTER PROCEDURE dbo.usp_extend_access_window
    @window_id   INT,
    @new_ends_at DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- only extends: the new end must be later than the current one and within 12h
    UPDATE dbo.access_windows
    SET ends_at = @new_ends_at
    WHERE window_id = @window_id
      AND @new_ends_at > ends_at
      AND @new_ends_at <= DATEADD(HOUR, 12, ends_at);

    IF @@ROWCOUNT = 0
    BEGIN
        THROW 50010, 'Window not found, or the new end is not a valid extension.', 1;
    END

    SELECT window_id, grantee, starts_at, ends_at
    FROM dbo.access_windows
    WHERE window_id = @window_id;
END;
GO

IF DATABASE_PRINCIPAL_ID('db_access_window_bot') IS NULL
BEGIN
    CREATE ROLE db_access_window_bot;
END;

GRANT EXECUTE ON OBJECT::dbo.usp_extend_access_window TO db_access_window_bot;
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.access_windows TO db_access_window_bot;
