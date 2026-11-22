-- Multi-mode operational report for inventory items and stock movements.
-- Supports:
--   'C' = Consolidated (excludes zero-quantity adjustments)
--   'D' = Detailed (all movements in the requested period)
--   'A' = Audit (all active items via LEFT JOIN, including zero-movement items)
-- Uses SARGable half-open DATETIME2 bounds so IX_inventory_movements_movedat_item can seek.

CREATE OR ALTER PROCEDURE dbo.usp_inventory_movements_report
    @start_date DATE,
    @end_date   DATE,
    @view_mode  CHAR(1) = 'C'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @range_start DATETIME2(0) = CAST(@start_date AS DATETIME2(0));
    DECLARE @range_end   DATETIME2(0) = DATEADD(DAY, 1, CAST(@end_date AS DATETIME2(0)));

    IF @view_mode IN ('C', 'D')
    BEGIN
        SELECT
            mov.movement_id,
            mov.moved_at,
            st.store_code,
            mov.movement_type,
            item.item_id,
            item.product_code,
            item.item_description,
            item.unit_of_measure,
            mov.quantity
        FROM dbo.inventory_movements AS mov WITH (NOLOCK)
        INNER JOIN dbo.inventory_items AS item WITH (NOLOCK)
            ON item.item_id = mov.item_id
        INNER JOIN dbo.stores AS st WITH (NOLOCK)
            ON st.store_id = mov.store_id
        WHERE mov.moved_at >= @range_start
          AND mov.moved_at <  @range_end
          AND (@view_mode <> 'C' OR mov.quantity <> 0)
        ORDER BY
            mov.moved_at DESC,
            mov.movement_id DESC;
    END
    ELSE IF @view_mode = 'A'
    BEGIN
        SELECT
            item.item_id,
            item.product_code,
            item.item_description,
            item.unit_of_measure,
            COUNT(mov.movement_id)         AS total_movements,
            COALESCE(SUM(mov.quantity), 0) AS period_quantity_total
        FROM dbo.inventory_items AS item WITH (NOLOCK)
        LEFT JOIN dbo.inventory_movements AS mov WITH (NOLOCK)
            ON mov.item_id = item.item_id
           AND mov.moved_at >= @range_start
           AND mov.moved_at <  @range_end
        WHERE item.is_active = 1
        GROUP BY
            item.item_id,
            item.product_code,
            item.item_description,
            item.unit_of_measure
        ORDER BY
            item.product_code;
    END
    ELSE
    BEGIN
        THROW 50001, 'Invalid @view_mode. Expected ''C'' (Consolidated), ''D'' (Detailed), or ''A'' (Audit).', 1;
    END
END;
