[🇺🇸 English](README.md) | **🇧🇷 Português**

# 🗄️ tsql-retail-ops-analytics

[![CI](https://github.com/gavicoding/tsql-retail-ops-analytics/actions/workflows/ci.yml/badge.svg)](https://github.com/gavicoding/tsql-retail-ops-analytics/actions/workflows/ci.yml)
[![Dialeto: T-SQL](https://img.shields.io/badge/Dialeto-T--SQL%20(SQL%20Server)-CC2927.svg)](https://learn.microsoft.com/sql/t-sql/)
[![Licença: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-green.svg)](LICENSE)

Portfólio técnico de **T-SQL / SQL Server** sobre um modelo **100% sintético e anonimizado** de varejo multiloja, logística reversa, estoque, conciliação de PDV/fiscal, gargalos de separação (WMS), diagnóstico de bloqueios (`sys.dm_tran_locks`) e segurança de acesso granular.

> **Nota de Privacidade:** Todas as tabelas, colunas, procedures e massas de dados são **100% fictícias**, criadas para demonstrar padrões reais de engenharia de banco de dados sem expor nenhum esquema proprietário ou dado corporativo.

---

## Principais Padrões Demonstrados

- **Agregação Condicional em Passada Única:** consolida venda líquida total, subtotal de categorias estratégicas e participação percentual sem multiplicar linhas (`SUM(CASE WHEN ...)` + `NULLIF`).
- **Deduplicação com Window Functions (`ROW_NUMBER()`):** isola apenas o evento mais recente por ativo retornável (`PARTITION BY asset_code ORDER BY moved_at DESC`), resolvendo duplicidade em múltiplos ciclos CD ↔ loja e atribuindo responsabilidade ao operador.
- **Filtros SARGable com Índices de Cobertura:** intervalos semiabertos (`>= @start_date AND < DATEADD(DAY, 1, @end_date)`) alinhados aos índices em `schema/02_indexes.sql`.
- **Stored Procedures Parametrizadas e Transacionais:** relatório multivisão de movimentações (`'C'` Consolidado, `'D'` Detalhado, `'A'` Auditoria via `LEFT JOIN`) e atualização controlada de parâmetros chave-valor (`UPDLOCK`, `TRY...CATCH`, retorno pré/pós alteração).
- **Observabilidade DBA & Menor Privilégio:** captura assíncrona de contenção (`sys.dm_tran_locks` + `sys.dm_exec_requests`), saúde da última execução de jobs (`msdb.dbo.sysjobhistory`) e papel `db_readonly_analytics` com `GRANT SELECT` explícito e `DENY` de escrita.

---

## Padrões de Produção (casos reais, recriados com dados fictícios)

- **Relatório com filtro opcional por produto:** `TRY_CONVERT` com `NULLIF` para campo vazio ou inválido (o `ISNUMERIC` aceita `'$'`, `'1e5'` e `'12,5'`, e `TRY_CONVERT(INT, '')` devolve `0`) e `OPTION (RECOMPILE)` contra parameter sniffing.
- **Ingestão idempotente em lote:** um único comando, com deduplicação no lote, `NOT EXISTS` nas duas chaves com `UPDLOCK, HOLDLOCK` e `OUTPUT ... INTO @tabela`.
- **Pré-agregação incremental:** alguns dias por rodada com `MERGE`, em vez de varrer 12 meses de log a cada consulta.
- **Agregação em duas etapas com `#temp` indexada:** contorna o timeout e o erro 130 (`EXISTS` dentro de `SUM`).
- **Extended Events:** descobre quais procedures um aplicativo chama antes de automatizá-lo.
- **Menor privilégio para robô:** só `EXECUTE` em uma procedure que apenas prorroga o término de um acesso.

Tudo roda em um **SQL Server 2022 real no CI**, com asserções que quebram o build se o resultado estiver errado.

---

## Execução dos Testes Automatizados

```bash
python -m unittest discover -s tests -v
```

Valida o balanceamento de blocos `BEGIN`/`CASE`/`END`, ausência de predicados não-SARGable em datas, proteção contra `UPDATE`/`DELETE` sem `WHERE` e executa a lógica analítica em banco SQLite em memória equivalente ao `schema/03_seed_data.sql`.

Veja a documentação completa e o diagrama ER em [README.md](README.md) e a licença em [LICENSE](LICENSE).
