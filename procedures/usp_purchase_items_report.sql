-- Purchase invoice items report with an OPTIONAL product filter ("catch-all" query).
--
-- Production lesson behind it:
--   * The report screen sends the product as free text. A blank field used to break
--     the conversion to a number. TRY_CONVERT turns blank or invalid input into NULL
--     with no error. (ISNUMERIC is not enough: it returns 1 for '$', '.', '-', '1e5'
--     and '12,5', and the conversion still fails afterwards.)
--   * "(col = @p OR @p IS NULL)" with a cached plan suffers from parameter sniffing:
--     the plan built for a single product (index seek) is reused for the full-period
--     extract, and vice versa. OPTION (RECOMPILE) builds the right plan every run.
--   * Cost may still be pending, so the total cost falls back from net cost to gross
--     cost to the invoice line total, and the row says whether cost is final.

CREATE OR ALTER PROCEDURE dbo.usp_purchase_items_report
    @date_from    DATETIME2(0),
    @date_to      DATETIME2(0),
    @product_text NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @item_id INT = TRY_CONVERT(INT, LTRIM(RTRIM(@product_text)));

    SELECT
        pi.store_id,
        pi.invoice_number,
        pi.issued_at,
        pi.posted_at,
        pi.access_key,
        s.supplier_name,
        ii.product_code,
        ii.item_description,
        it.quantity,
        it.pack_size,
        it.quantity * it.pack_size AS total_units,
        it.unit_price,
        it.line_total,
        cs.net_unit_cost,
        CASE
            WHEN cs.net_unit_cost   IS NOT NULL THEN cs.net_unit_cost   * it.quantity * it.pack_size
            WHEN cs.gross_unit_cost IS NOT NULL THEN cs.gross_unit_cost * it.quantity * it.pack_size
            ELSE it.line_total
        END AS total_cost,
        CASE WHEN cs.net_unit_cost IS NULL THEN 'PENDING_COST' ELSE 'COST_FINAL' END AS cost_status
    FROM dbo.purchase_invoice_items AS it
    JOIN dbo.purchase_invoices      AS pi ON pi.invoice_id  = it.invoice_id
    JOIN dbo.suppliers              AS s  ON s.supplier_id  = pi.supplier_id
    JOIN dbo.inventory_items        AS ii ON ii.item_id     = it.item_id
    LEFT JOIN dbo.item_cost_snapshots AS cs ON cs.line_id   = it.line_id
    WHERE pi.issued_at >= @date_from
      AND pi.issued_at <= @date_to
      AND (it.item_id = @item_id OR @item_id IS NULL)
    ORDER BY pi.posted_at, pi.invoice_number, it.line_id
    OPTION (RECOMPILE);
END;
