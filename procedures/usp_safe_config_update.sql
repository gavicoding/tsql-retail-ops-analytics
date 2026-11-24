-- Controlled, auditable key-value parameter update stored procedure.
-- Enforces existence validation, strict WHERE key filtering, and pre/post audit output.

CREATE OR ALTER PROCEDURE dbo.usp_safe_config_update
    @config_key VARCHAR(80),
    @new_value  NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @previous_value NVARCHAR(400);
    DECLARE @updated_at     DATETIME2(0) = SYSDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @previous_value = c.config_value
        FROM dbo.integration_config AS c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.config_key = @config_key;

        IF @previous_value IS NULL
        BEGIN
            THROW 50002, 'Target configuration key does not exist.', 1;
        END

        UPDATE dbo.integration_config
        SET
            config_value = @new_value,
            updated_at   = @updated_at
        WHERE config_key = @config_key;

        COMMIT TRANSACTION;

        SELECT
            @config_key     AS config_key,
            @previous_value AS previous_value,
            @new_value      AS new_value,
            @updated_at     AS updated_at;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;
        THROW;
    END CATCH
END;
