# Contributing to tsql-retail-ops-analytics

Thank you for contributing!

## Guidelines

1. **100% Synthetic Data Only:** Never submit real company names, store identifiers, production table names, or customer/fiscal data.
2. **SARGable Predicates:** Keep date filters as half-open range bounds (`>= @start AND < DATEADD(DAY, 1, @end)`) rather than wrapping indexed columns in `CAST(...)`.
3. **Guarded DML:** Any `UPDATE` or `DELETE` example must include an explicit `WHERE` clause and transactional handling.
4. **Verify Locally:** Ensure `python -m unittest discover -s tests -v` passes with zero errors before opening a Pull Request.
