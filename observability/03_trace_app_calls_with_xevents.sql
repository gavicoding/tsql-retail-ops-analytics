-- Discover which stored procedures a vendor application calls when a user saves a
-- form, before automating it.
--
-- Production lesson behind it:
--   * Automations must never INSERT straight into ERP tables: saving a document can
--     also move stock, finance and audit rows. The safe path is to call the same
--     procedures the application calls.
--   * A short, filtered Extended Events session (one host / one app, ring buffer,
--     minutes long) shows exactly which procedures run and with which parameters,
--     with negligible overhead. Run it in a test environment while saving one record.

DECLARE @session_name SYSNAME = N'trace_app_calls_demo';
DECLARE @app_filter   NVARCHAR(128) = N'%';      -- e.g. N'ERP Desktop%'
DECLARE @sql          NVARCHAR(MAX);

IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = @session_name)
BEGIN
    SET @sql = N'DROP EVENT SESSION ' + QUOTENAME(@session_name) + N' ON SERVER;';
    EXEC sys.sp_executesql @sql;
END;

SET @sql = N'
CREATE EVENT SESSION ' + QUOTENAME(@session_name) + N' ON SERVER
ADD EVENT sqlserver.rpc_completed (
    ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.session_id, sqlserver.database_name)
    WHERE sqlserver.like_i_sql_unicode_string(sqlserver.client_app_name, N''' + REPLACE(@app_filter, '''', '''''') + N''')
)
ADD TARGET package0.ring_buffer (SET max_memory = 4096)
WITH (MAX_DISPATCH_LATENCY = 1 SECONDS, STARTUP_STATE = OFF);';
EXEC sys.sp_executesql @sql;

SET @sql = N'ALTER EVENT SESSION ' + QUOTENAME(@session_name) + N' ON SERVER STATE = START;';
EXEC sys.sp_executesql @sql;

-- ... save one record in the application here, then read what was captured:
SELECT
    evt.value('(@timestamp)[1]', 'DATETIME2(3)')                              AS captured_at,
    evt.value('(data[@name="object_name"]/value)[1]', 'NVARCHAR(256)')        AS procedure_name,
    evt.value('(data[@name="statement"]/value)[1]', 'NVARCHAR(MAX)')          AS rpc_statement,
    evt.value('(action[@name="client_app_name"]/value)[1]', 'NVARCHAR(256)')  AS client_app,
    evt.value('(action[@name="session_id"]/value)[1]', 'INT')                 AS session_id
FROM (
    SELECT CAST(t.target_data AS XML) AS target_xml
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions        AS s ON s.address = t.event_session_address
    WHERE s.name = @session_name
      AND t.target_name = 'ring_buffer'
) AS src
CROSS APPLY src.target_xml.nodes('RingBufferTarget/event') AS x(evt)
ORDER BY captured_at;

-- Always stop and drop the session when done.
SET @sql = N'ALTER EVENT SESSION ' + QUOTENAME(@session_name) + N' ON SERVER STATE = STOP;';
EXEC sys.sp_executesql @sql;
SET @sql = N'DROP EVENT SESSION ' + QUOTENAME(@session_name) + N' ON SERVER;';
EXEC sys.sp_executesql @sql;
