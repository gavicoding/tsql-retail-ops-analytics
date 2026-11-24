-- Synthetic customers (100% fictional names, CPFs, emails and phones).

INSERT INTO dbo.customers (customer_id, full_name, tax_id, email, phone, birth_date, city, created_at) VALUES
    (1, N'Maria Exemplo da Silva', '123.456.789-09', 'maria.exemplo@exemplo.test', '+55 11 90000-0001', '1985-04-12', N'Campinas',  '2024-02-10T10:00:00'),
    (2, N'Joao Ficticio Souza',    '987.654.321-00', 'joao.ficticio@exemplo.test', '+55 21 90000-0002', '1992-09-30', N'Niteroi',   '2024-06-01T15:30:00'),
    (3, N'Ana Demo Pereira',       '111.444.777-35', 'ana.demo@exemplo.test',      '+55 31 90000-0003', '1978-01-05', N'Contagem',  '2025-01-20T09:15:00');

INSERT INTO dbo.customer_orders (customer_id, store_id, ordered_at, total_amount) VALUES
    (1, 101, '2026-10-02T10:00:00', 120.50),
    (2, 101, '2026-10-05T11:20:00',  89.90),
    (2, 102, '2026-11-12T17:45:00', 240.00),
    (2, 103, '2026-11-19T09:05:00',  35.10),
    (3, 102, '2026-11-20T14:00:00', 410.00);

INSERT INTO dbo.privacy_requests (customer_id, request_type, requested_at) VALUES
    (2, 'ERASURE', '2026-11-21T08:30:00');
