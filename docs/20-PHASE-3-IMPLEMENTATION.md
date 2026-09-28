# Phase 3 Implementation Record

Schemes use integer paise amounts, configurable installment count and benefit,
and a unique human-readable code. Every modification appends an immutable
version record; future enrollments will snapshot that version in Phase 4.
Only principals with `scheme:manage` can create or revise schemes.
