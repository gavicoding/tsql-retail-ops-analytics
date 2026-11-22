import re
import sqlite3
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL_DIRS = ("schema", "queries", "procedures", "observability", "security")


def strip_sql_comments(sql: str) -> str:
    no_block = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
    return re.sub(r"--[^\r\n]*", "", no_block)


class TestSQLPortfolioStructure(unittest.TestCase):
    def test_all_expected_sql_files_exist_and_are_non_empty(self):
        sql_files = [p for folder in SQL_DIRS for p in sorted((ROOT / folder).glob("*.sql"))]
        self.assertGreaterEqual(len(sql_files), 13)
        for path in sql_files:
            content = path.read_text(encoding="utf-8")
            self.assertGreater(len(strip_sql_comments(content).strip()), 10, f"Empty SQL in {path}")

    def test_balanced_begin_case_end_blocks(self):
        sql_files = [p for folder in SQL_DIRS for p in sorted((ROOT / folder).glob("*.sql"))]
        for path in sql_files:
            cleaned = strip_sql_comments(path.read_text(encoding="utf-8"))
            openers = re.findall(r"\b(?:CASE|BEGIN(?!\s+TRANSACTION\b))\b", cleaned, re.I)
            closers = re.findall(r"\bEND\b", cleaned, re.I)
            self.assertEqual(
                len(openers),
                len(closers),
                f"Unbalanced BEGIN/CASE/END in {path.name}: {len(openers)} vs {len(closers)}",
            )

    def test_sargable_date_predicates_and_guarded_dml(self):
        for folder in ("queries", "procedures"):
            for path in sorted((ROOT / folder).glob("*.sql")):
                cleaned = strip_sql_comments(path.read_text(encoding="utf-8"))
                self.assertNotRegex(
                    cleaned,
                    re.compile(r"CAST\s*\([^)]+AS\s+DATE\s*\)\s*BETWEEN", re.I),
                    f"Non-SARGable CAST(... AS DATE) BETWEEN found in {path.name}",
                )

                for stmt in cleaned.split(";"):
                    if re.search(r"\bDENY\b", stmt, re.I):
                        continue
                    if re.search(r"\b(?:UPDATE|DELETE)\b", stmt, re.I):
                        self.assertRegex(
                            stmt,
                            re.compile(r"\bWHERE\b", re.I),
                            f"Unguarded UPDATE/DELETE without WHERE in {path.name}",
                        )


class TestAnalyticalSQLLogic(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.row_factory = sqlite3.Row
        self._load_synthetic_sqlite_db()

    def tearDown(self):
        self.conn.close()

    def _load_synthetic_sqlite_db(self):
        self.conn.executescript(
            """
            CREATE TABLE stores (
                store_id INTEGER PRIMARY KEY,
                store_code TEXT NOT NULL,
                store_name TEXT NOT NULL
            );
            CREATE TABLE product_categories (
                category_id INTEGER PRIMARY KEY,
                category_name TEXT NOT NULL,
                is_strategic INTEGER NOT NULL
            );
            CREATE TABLE sales (
                sale_id INTEGER PRIMARY KEY AUTOINCREMENT,
                store_id INTEGER NOT NULL,
                category_id INTEGER NOT NULL,
                sale_at TEXT NOT NULL,
                net_amount REAL NOT NULL,
                sale_status TEXT NOT NULL
            );
            CREATE TABLE returnable_asset_movements (
                movement_id INTEGER PRIMARY KEY AUTOINCREMENT,
                asset_code TEXT NOT NULL,
                origin_store_id INTEGER NOT NULL,
                destination_store_id INTEGER NOT NULL,
                operator_badge TEXT NOT NULL,
                movement_type TEXT NOT NULL,
                return_status TEXT NOT NULL,
                moved_at TEXT NOT NULL
            );
            CREATE TABLE pos_cash_reconciliation (
                reconciliation_id INTEGER PRIMARY KEY AUTOINCREMENT,
                store_id INTEGER NOT NULL,
                business_date TEXT NOT NULL,
                payment_method TEXT NOT NULL,
                expected_amount REAL NOT NULL,
                settled_amount REAL NOT NULL
            );
            CREATE TABLE fiscal_transmissions (
                transmission_id INTEGER PRIMARY KEY AUTOINCREMENT,
                store_id INTEGER NOT NULL,
                document_number TEXT NOT NULL,
                business_date TEXT NOT NULL,
                transmission_status TEXT NOT NULL
            );
            CREATE TABLE wms_picking_tasks (
                task_id INTEGER PRIMARY KEY AUTOINCREMENT,
                origin_store_id INTEGER NOT NULL,
                destination_store_id INTEGER NOT NULL,
                stage TEXT NOT NULL,
                task_status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                completed_at TEXT
            );

            INSERT INTO stores VALUES
                (100, 'DC-00', 'Central Distribution Center'),
                (101, 'ST-01', 'Downtown Flagship Store'),
                (102, 'ST-02', 'Westside Express Store'),
                (103, 'ST-03', 'South Plaza Store');

            INSERT INTO product_categories VALUES
                (10, 'Private Label Essentials', 1),
                (20, 'Exclusive Care Line', 1),
                (30, 'General Merchandise', 0),
                (40, 'Beverages & Snacks', 0);

            INSERT INTO sales (store_id, category_id, sale_at, net_amount, sale_status) VALUES
                (101, 10, '2026-11-20T09:15:00', 450.00, 'COMPLETED'),
                (101, 20, '2026-11-20T11:30:00', 300.00, 'COMPLETED'),
                (101, 30, '2026-11-20T14:10:00', 250.00, 'COMPLETED'),
                (101, 10, '2026-11-20T16:00:00', 120.00, 'CANCELLED'),
                (102, 10, '2026-11-20T10:05:00', 200.00, 'COMPLETED'),
                (102, 40, '2026-11-20T18:45:00', 600.00, 'COMPLETED');

            INSERT INTO returnable_asset_movements
                (asset_code, origin_store_id, destination_store_id, operator_badge, movement_type, return_status, moved_at)
            VALUES
                ('BOX-1001', 100, 101, 'OP-412', 'DISPATCH', 'PENDING',  '2026-11-01T08:00:00'),
                ('BOX-1001', 101, 100, 'OP-412', 'RETURN',   'RETURNED', '2026-11-05T14:20:00'),
                ('BOX-1001', 100, 102, 'OP-518', 'DISPATCH', 'PENDING',  '2026-11-12T09:10:00'),
                ('BOX-1002', 100, 103, 'OP-609', 'DISPATCH', 'PENDING',  '2026-11-08T07:45:00'),
                ('BOX-1003', 100, 101, 'OP-412', 'DISPATCH', 'PENDING',  '2026-11-18T10:00:00'),
                ('BOX-1003', 101, 100, 'OP-412', 'RETURN',   'RETURNED', '2026-11-19T16:30:00');

            INSERT INTO pos_cash_reconciliation (store_id, business_date, payment_method, expected_amount, settled_amount) VALUES
                (101, '2026-11-20', 'CARD_CREDIT', 5200.00, 5200.00),
                (101, '2026-11-20', 'INSTANT_PIX', 3100.00, 3100.00),
                (102, '2026-11-20', 'CARD_DEBIT',  2400.00, 2280.00),
                (103, '2026-11-20', 'CASH',        1500.00, 1500.00);

            INSERT INTO fiscal_transmissions (store_id, document_number, business_date, transmission_status) VALUES
                (101, 'NF-000101', '2026-11-20', 'AUTHORIZED'),
                (102, 'NF-000205', '2026-11-20', 'CONTINGENCY'),
                (103, 'NF-000311', '2026-11-20', 'REJECTED');

            INSERT INTO wms_picking_tasks (origin_store_id, destination_store_id, stage, task_status, created_at, completed_at) VALUES
                (100, 101, 'PICKING',  'COMPLETED',   '2026-11-20T06:00:00', '2026-11-20T06:22:00'),
                (100, 102, 'PICKING',  'PENDING',     '2026-11-20T06:15:00', NULL),
                (100, 102, 'CHECKOUT', 'IN_PROGRESS', '2026-11-20T07:00:00', NULL),
                (100, 103, 'TRANSFER', 'PENDING',     '2026-11-20T07:30:00', NULL);
            """
        )

    def test_single_pass_net_sales_and_strategic_categories(self):
        rows = self.conn.execute(
            """
            SELECT
                st.store_code,
                SUM(s.net_amount) AS total_net_sales,
                SUM(CASE WHEN pc.is_strategic = 1 THEN s.net_amount ELSE 0 END) AS strategic_sales
            FROM sales AS s
            JOIN stores AS st ON st.store_id = s.store_id
            JOIN product_categories AS pc ON pc.category_id = s.category_id
            WHERE s.sale_status = 'COMPLETED'
              AND s.sale_at >= '2026-11-20T00:00:00'
              AND s.sale_at <  '2026-11-21T00:00:00'
            GROUP BY st.store_code
            ORDER BY st.store_code
            """
        ).fetchall()

        by_store = {r["store_code"]: dict(r) for r in rows}
        self.assertEqual(by_store["ST-01"]["total_net_sales"], 1000.0)
        self.assertEqual(by_store["ST-01"]["strategic_sales"], 750.0)
        self.assertEqual(by_store["ST-02"]["total_net_sales"], 800.0)
        self.assertEqual(by_store["ST-02"]["strategic_sales"], 200.0)

    def test_row_number_eliminates_multi_trip_duplicates_and_isolates_pending(self):
        latest = self.conn.execute(
            """
            WITH ranked AS (
                SELECT
                    asset_code,
                    destination_store_id,
                    operator_badge,
                    return_status,
                    ROW_NUMBER() OVER (
                        PARTITION BY asset_code
                        ORDER BY moved_at DESC, movement_id DESC
                    ) AS rn
                FROM returnable_asset_movements
            )
            SELECT asset_code, destination_store_id, operator_badge, return_status
            FROM ranked
            WHERE rn = 1
            ORDER BY asset_code
            """
        ).fetchall()

        self.assertEqual(len(latest), 3)
        by_code = {r["asset_code"]: dict(r) for r in latest}
        self.assertEqual(by_code["BOX-1001"]["return_status"], "PENDING")
        self.assertEqual(by_code["BOX-1001"]["operator_badge"], "OP-518")
        self.assertEqual(by_code["BOX-1003"]["return_status"], "RETURNED")

        pending = [r for r in latest if r["return_status"] == "PENDING"]
        self.assertEqual({r["asset_code"] for r in pending}, {"BOX-1001", "BOX-1002"})

    def test_pos_fiscal_reconciliation_and_wms_bottlenecks(self):
        recon = self.conn.execute(
            """
            WITH pos_summary AS (
                SELECT store_id, SUM(settled_amount - expected_amount) AS net_variance
                FROM pos_cash_reconciliation
                GROUP BY store_id
            ),
            fiscal_summary AS (
                SELECT
                    store_id,
                    SUM(CASE WHEN transmission_status = 'CONTINGENCY' THEN 1 ELSE 0 END) AS contingency_docs,
                    SUM(CASE WHEN transmission_status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected_docs
                FROM fiscal_transmissions
                GROUP BY store_id
            )
            SELECT
                st.store_code,
                ps.net_variance,
                CASE
                    WHEN ps.net_variance <> 0 OR COALESCE(fs.rejected_docs, 0) > 0 THEN 'ACTION_REQUIRED'
                    WHEN COALESCE(fs.contingency_docs, 0) > 0 THEN 'MONITOR_CONTINGENCY'
                    ELSE 'RECONCILED'
                END AS audit_status
            FROM pos_summary AS ps
            JOIN stores AS st ON st.store_id = ps.store_id
            LEFT JOIN fiscal_summary AS fs ON fs.store_id = ps.store_id
            ORDER BY st.store_code
            """
        ).fetchall()

        status_map = {r["store_code"]: r["audit_status"] for r in recon}
        self.assertEqual(status_map["ST-01"], "RECONCILED")
        self.assertEqual(status_map["ST-02"], "ACTION_REQUIRED")
        self.assertEqual(status_map["ST-03"], "ACTION_REQUIRED")

        wms = self.conn.execute(
            """
            SELECT
                stage,
                SUM(CASE WHEN task_status = 'PENDING' THEN 1 ELSE 0 END) AS pending_tasks,
                SUM(CASE WHEN task_status = 'IN_PROGRESS' THEN 1 ELSE 0 END) AS in_progress_tasks,
                SUM(CASE WHEN task_status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_tasks
            FROM wms_picking_tasks
            GROUP BY stage
            """
        ).fetchall()
        wms_map = {r["stage"]: dict(r) for r in wms}
        self.assertEqual(wms_map["PICKING"]["pending_tasks"], 1)
        self.assertEqual(wms_map["PICKING"]["completed_tasks"], 1)
        self.assertEqual(wms_map["CHECKOUT"]["in_progress_tasks"], 1)
        self.assertEqual(wms_map["TRANSFER"]["pending_tasks"], 1)


if __name__ == "__main__":
    unittest.main()
