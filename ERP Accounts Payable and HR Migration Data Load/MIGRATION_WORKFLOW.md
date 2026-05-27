# Migration Workflow — Step-by-Step Execution Guide

This document walks through the full migration exercise in the order you would execute it in a real project engagement.

---

## Phase 1 — Environment Setup

**Run once before anything else.**

```sql
-- Creates ERP_TARGET database and all production tables
-- with constraints, foreign keys, and correct data types
01_schema_ddl.sql
```

```sql
-- Creates six stg_ staging tables
-- All columns NVARCHAR/nullable — accepts dirty data without errors
02_staging_ddl.sql
```

---

## Phase 2 — Source Data Preparation (Excel)

Before importing, run the Office Scripts against `ERP_Migration_Source_Data.xlsx`
to remediate known formatting defects. Run in this order:

```
1. taxid_1_fix_blanks.ts          -- null/blank EINs
2. taxid_2_fix_na.ts              -- N/A EINs
3. taxid_3_fix_pending.ts         -- PENDING EINs
4. taxid_4_fix_missing_dash.ts    -- 9-digit EINs missing dash
5. bankacct_fix_blanks.ts         -- missing bank account numbers
6. routing_fix_blanks.ts          -- missing routing numbers
7. routing_validate_checksum.ts   -- flag invalid routing numbers
```

After each script, check the `Migration Defect Log` sheet to confirm
what was changed before running the next one.

---

## Phase 3 — Import to Staging

Use SSMS Import and Export Wizard:
**Right-click ERP_TARGET → Tasks → Import Data**

Map each Excel sheet to its staging table:

| Excel Sheet | Staging Table |
|---|---|
| Vendors | dbo.stg_Vendors |
| Employees | dbo.stg_Employees |
| Benefit Elections | dbo.stg_BenefitElections |
| Payroll Records | dbo.stg_PayrollRecords |
| Invoices | dbo.stg_Invoices |
| Payments | dbo.stg_Payments |

> **Important:** Map to `stg_` tables, not the production tables.
> Excel column headers must match staging column names exactly.
> If the wizard drops columns, check for spacing differences between
> the Excel header and the SQL column name.

To clear staging and re-import after fixing issues:
```sql
TRUNCATE TABLE dbo.stg_Payments;
TRUNCATE TABLE dbo.stg_Invoices;
TRUNCATE TABLE dbo.stg_PayrollRecords;
TRUNCATE TABLE dbo.stg_BenefitElections;
TRUNCATE TABLE dbo.stg_Employees;
TRUNCATE TABLE dbo.stg_Vendors;
-- Order matters — child tables first
```

---

## Phase 4 — Validate and Cleanse

Open `03_validation_and_cleanse.sql` and run each step in sequence.
**Do not skip steps or run them out of order.**

### Step 1 — Defect Scorecard
Run the full scorecard query. This is your baseline.
Document the counts — this is what you would present in a project status call.

Expected defects you will find:
- Duplicate vendor names
- Missing/malformed Tax IDs
- Missing bank and routing numbers
- Employees with no cost center, pay type, or compensation
- Invalid payroll pay codes
- Negative and zero gross pay
- Invoice total mismatches
- Paid invoices with no payment date
- Negative and zero payment amounts

### Step 2 — Row-Level Defect Reports
Run each targeted SELECT to see exactly which rows are broken.
Study the output before running any UPDATEs.

### Step 3 — Cleanse
Run each UPDATE block one at a time.
Check `@@ROWCOUNT` after each one — the PRINT statement shows you how many rows were affected.

Cleansing decisions by defect type:

| Defect | Action |
|---|---|
| EIN missing dash | Auto-fix: insert dash at position 2 |
| EIN null/N/A/PENDING | Placeholder: `99-MIGR####` — flag REJECTED for client |
| Missing bank account (active vendor) | Placeholder: `000-MIGR-####` |
| Missing routing (active vendor) | Placeholder: `999999999` |
| Missing IsActive | Default to `Y` |
| Missing StandardHours | Default to `40` |
| Missing employee name/hire date | Flag REJECTED — client must provide |
| Invalid PayCode | Default to `REG` — add note for client review |
| NetPay variance > $1 | Recalculate from GrossPay minus deductions |
| Invoice total mismatch > $0.01 | Recalculate as InvoiceAmount + TaxAmount |
| Negative InvoiceAmount | Flag REJECTED — client must confirm if credit memo |
| Negative GrossPay on REG/OT/HOLIDAY/SICK/PTO | Flag REJECTED — not a valid scenario |
| Negative GrossPay on BONUS/COMM/REIMB/SEVERANCE/MISC | Flag REJECTED — possible clawback, needs Payroll sign-off |
| Zero GrossPay | Flag REJECTED — likely failed payroll run |

### Step 4 — Re-validate
Re-run the status summary.
Target state before proceeding:
- Every row is either `CLEAN` or `REJECTED`
- Zero rows remain `PENDING`

The REJECTED list is your client follow-up document.
Share it with the appropriate business owners and wait for responses
before moving to Step 5.

### Step 5 — Post to Production
Run one INSERT block at a time.
Check the PRINT output after each one for the row count.
If a count is zero or unexpectedly low — stop and investigate before continuing.

### Step 6 — Reconciliation
Run the reconciliation query.
Every table must show `OK` in the Status column before sign-off.
A `MISMATCH` means CLEAN rows in staging did not all make it to production —
this requires investigation before the migration can be closed.

---

## Phase 5 — Sign-off Checklist

Before declaring the migration complete:

- [ ] Step 1 scorecard re-run shows 0 for all production-blocking defects
- [ ] Step 4 status summary shows no PENDING rows
- [ ] REJECTED list has been shared with client and responses documented
- [ ] Step 6 reconciliation shows OK for all six tables
- [ ] Migration Defect Log (Excel) has been saved and archived
- [ ] Any REJECTED rows re-submitted by client have been reprocessed

---

## Common Issues and Fixes

**Import wizard drops most columns**
Column header names in Excel don't match staging column names exactly.
Use F2 in Excel to edit headers — match them character-for-character to the
`stg_` column names in `02_staging_ddl.sql`.

**Msg 245 conversion error on WHERE clause**
You are comparing a raw NVARCHAR staging column to a numeric literal.
SQL Server attempts implicit INT conversion and fails on decimal values.
Always wrap the column in `TRY_CAST` before comparing:
```sql
-- Wrong
WHERE InvoiceAmount >= 0

-- Right
WHERE TRY_CAST(InvoiceAmount AS DECIMAL(14,2)) >= 0
```

**Step 5 INSERT posts zero rows**
The staging rows are not marked CLEAN. Re-run Step 3 and Step 4
to confirm your cleansing UPDATEs ran correctly and the status was set.

**Reconciliation shows MISMATCH**
Check whether any CLEAN rows were excluded from the INSERT due to
failed foreign key lookups. The Step 5 INSERT statements include
`IN (SELECT ... FROM production_table)` filters that silently exclude
rows whose parent records didn't make it to production.
Fix the parent table first, then repost the child table.
