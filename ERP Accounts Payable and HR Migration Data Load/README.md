# ERP Data Migration — End-to-End Practice Project

A fully self-contained ERP data migration exercise covering schema design, staging architecture, data cleansing, validation, and production posting. Built as a realistic simulation of an enterprise migration engagement involving vendor, accounts payable, employee, payroll, and benefits data.

---

## Project Overview

This project simulates a real-world ERP migration from a legacy system to a new SQL Server environment. The source data arrives as a client-delivered Excel workbook — intentionally dirty, incomplete, and inconsistent — and the goal is to cleanse, validate, and post it to a production schema with full auditability.

The exercise covers every phase of a real migration:

| Phase | Description |
|---|---|
| Schema design | Production tables with constraints and referential integrity |
| Staging layer | Mirror tables with all columns nullable for raw import |
| Profiling | Defect scorecard across all six tables |
| Cleansing | Targeted UPDATE statements per defect type |
| Validation | Row-level defect reports and status classification |
| Posting | Type-safe INSERT from staging to production |
| Reconciliation | Source vs target row counts with variance reporting |

---

## Dataset

The source data (`ERP_Migration_Source_Data.xlsx`) is a simulated client-delivered workbook containing **6,550 rows** across six sheets, with intentional dirty data seeded throughout:

| Sheet | Rows | Defect types seeded |
|---|---|---|
| Vendors | 500 | Duplicate names, malformed/missing EINs, mixed phone formats, missing bank details |
| Employees | 1,500 | Missing cost centers, null pay types, no salary or hourly rate, invalid SSNs |
| Benefit Elections | 2,000 | Orphaned elections on inactive employees, missing coverage levels |
| Payroll Records | 2,500 | Invalid pay codes, negative gross pay, net pay reconciliation failures |
| Invoices | 1,000 | Negative amounts, total mismatches, paid invoices missing payment dates |
| Payments | 500 | Negative and zero payment amounts, missing bank accounts |

The workbook also includes:
- A **Data Dictionary** tab defining column requirements, formats, and allowed values
- A **Legend** tab explaining the color-coded data quality indicators (yellow = warning, red = error, green = remediated)

---

## Repository Structure

```
erp-migration/
├── README.md
├── sql/
│   ├── 01_schema_ddl.sql                    -- Production schema (ERP_TARGET database)
│   ├── 02_staging_ddl.sql                   -- Staging schema (stg_ tables, all nullable)
│   ├── 03_validation_and_cleanse.sql        -- Full 6-step migration workflow
│   ├── ERP_MIGRATION_PRACTICE_DATA.sql      -- 6,550-row source dataset (INSERT statements)
│   ├── ERP_MIGRATION_VALIDATION_QUERIES.sql -- Standalone defect scorecard and row-level reports
│   ├── check_INVOICE_errors.sql             -- Invoice defect investigation queries
│   ├── Duplicate_VendorName.sql             -- Duplicate vendor detection and resolution
│   ├── Missing_or_bad_TaxID.sql             -- Tax ID defect identification
│   ├── Missing_Pay_Data.sql                 -- Employee pay type and rate gap analysis
│   ├── Negative_or_zero_GrossPay.sql        -- Payroll negative/zero amount classification
│   └── Negative_or_zero_Payment_Amount.sql  -- Payment negative/zero amount identification
├── office-scripts/
│   ├── taxid_1_fix_blanks.ts                -- Fix null/blank Tax IDs
│   ├── taxid_2_fix_na.ts                    -- Fix N/A Tax IDs
│   ├── taxid_3_fix_pending.ts               -- Fix PENDING Tax IDs
│   ├── taxid_4_fix_missing_dash.ts          -- Insert missing dash in 9-digit EINs
│   ├── bankacct_fix_blanks.ts               -- Fill missing bank account numbers
│   ├── routing_fix_blanks.ts                -- Fill missing routing numbers
│   └── routing_validate_checksum.ts         -- ABA mod-10 checksum validation
├── workbooks/
│   ├── ERP_Migration_Source_Data.xlsx       -- Original source workbook (read-only reference)
│   ├── ERP_Migration_Source_Data_WorkingCopy.xlsx -- Active working copy used for cleansing and import
│   └── Validation_Errors.xlsx               -- Client-facing defect report sent for business sign-off
└── docs/
    └── MIGRATION_WORKFLOW.md                -- Step-by-step execution guide
```

---

## SQL Files

### `01_schema_ddl.sql`
Creates the `ERP_TARGET` database and six production tables with full constraints:
- `NOT NULL` enforcement on required fields
- `REFERENCES` foreign key constraints between tables
- Appropriate data types (`DECIMAL` for financial fields, `DATE` for dates, `BIT` for flags)

### `02_staging_ddl.sql`
Creates six `stg_` mirror tables designed to accept raw Excel imports without constraint failures:
- Every column `NVARCHAR` or nullable
- Three migration control columns on every table: `stg_LoadDate`, `stg_Status`, `stg_ErrorNotes`
- `stg_Status` values: `PENDING` → `CLEAN` / `REJECTED`

### `ERP_MIGRATION_PRACTICE_DATA.sql`
The full 6,550-row source dataset as SQL INSERT statements — an alternative to importing the Excel workbook. Contains the same intentional dirty data as the Excel source file. Useful for resetting the exercise to a known starting state or loading data programmatically without the SSMS Import Wizard.

### `03_validation_and_cleanse.sql` / `ERP_MIGRATION_VALIDATION_QUERIES.sql`
The core migration workflow. `03_validation_and_cleanse.sql` is the full six-step file; `ERP_MIGRATION_VALIDATION_QUERIES.sql` is the standalone defect scorecard and row-level reports extracted for use as a quick reference during the cleansing process. Structured as six sequential steps:

**Step 1 — Defect scorecard**
A single query returning ~35 defect counts across all six tables. This is your baseline report before touching anything.

**Step 2 — Row-level defect reports**
Targeted SELECT statements showing exactly which rows are broken and why, organized by table and defect type.

**Step 3 — Cleanse**
UPDATE statements that fix what can be fixed automatically:
- EIN dash insertion (9-digit → XX-XXXXXXX format)
- Bank account and routing number placeholder fill
- IsActive and StandardHours defaulting
- NetPay recalculation where variance exceeds $1.00
- Invoice TotalAmount recalculation where mismatch exceeds $0.01
- PayCode defaulting to REG where null or invalid (flagged for client review)
- Negative GrossPay classification by pay code (REJECTED vs business review)

Anything requiring business input is stamped `REJECTED` with a plain-English error note in `stg_ErrorNotes`.

**Step 4 — Re-validate**
Re-runs the status summary. Target: no `PENDING` rows remain. All rows are either `CLEAN` or `REJECTED` before proceeding.

**Step 5 — Post to production**
One INSERT per table, selecting only `WHERE stg_Status = 'CLEAN'`, with explicit type casting from `NVARCHAR` staging columns to production data types using `TRY_CAST`.

**Step 6 — Reconciliation**
Compares CLEAN row count in staging against posted row count in production. Every table must show zero variance before sign-off.

### Defect-Specific Investigation Scripts

These scripts were written during the active cleansing process to investigate and resolve specific defect categories. They reflect real analyst work — building targeted queries to understand a problem before writing the fix, and documenting findings inline as comments.

**`check_INVOICE_errors.sql`**
Investigates the two invoice defect types flagged in the scorecard: negative/zero amounts (78 records) and paid invoices with no payment date (49 records). Includes a documented lesson on why filtering raw `NVARCHAR` columns against numeric literals causes implicit conversion errors, and the corrected query pattern using `TRY_CAST` in the WHERE clause.

**`Duplicate_VendorName.sql`**
Detects duplicate vendor records using `ROW_NUMBER()` and `COUNT() OVER()` window functions partitioned by normalized vendor name. Includes the full resolution workflow based on client instructions — `BEGIN TRAN / DELETE / SELECT (verify) / COMMIT` per vendor group, with golden record decisions and TaxID selections documented inline. Five vendor groups resolved across 15 records.

**`Missing_or_bad_TaxID.sql`**
Identifies all vendors with null, blank, N/A, PENDING, or format-invalid Tax IDs using a pattern match against the `XX-XXXXXXX` EIN format. Feeds the client follow-up list in `Validation_Errors.xlsx`.

**`Missing_Pay_Data.sql`**
Multi-query investigation of employee compensation gaps: salary employees with no annual salary, hourly employees with no hourly rate, employees with no pay type but existing compensation data, and employees with neither pay type nor any compensation. Includes a `UNION ALL` pattern for combining related defect types into a single report. Commented UPDATE blocks show the considered approach to defaulting values (zeroing out) before determining that client sign-off was required instead.

**`Negative_or_zero_GrossPay.sql`**
Identifies payroll records with negative or zero gross pay, then applies business-context-aware classification: records on REG, OT, HOLIDAY, SICK, and PTO pay codes are stamped `REJECTED` as likely data errors; records on BONUS, COMM, REIMB, SEVERANCE, and MISC are stamped `REVIEW` as possible legitimate clawbacks requiring Payroll sign-off before posting.

**`Negative_or_zero_Payment_Amount.sql`**
Identifies payment records with negative or zero amounts for client review. Negative payments may represent legitimate vendor refunds; zero-amount payments are data entry errors to be rejected.

---

## Workbooks

Three Excel files representing the actual documents produced and exchanged during the migration process.

### `ERP_Migration_Source_Data.xlsx` — Original source file
The simulated client-delivered workbook. This is the read-only reference copy — it represents exactly what arrived from the legacy system before any cleansing work began. Contains six data sheets plus a Data Dictionary tab and a Legend tab explaining the color-coded quality indicators.

### `ERP_Migration_Source_Data_WorkingCopy.xlsx` — Active working copy
The file used for actual cleansing and import. The Office Scripts in the `office-scripts/` folder were run against this workbook, which is why it contains the `Migration Defect Log` sheet capturing every automated change with its original value, replacement, defect type, and timestamp. This is the version imported into the staging tables via the SSMS Import and Export Wizard.

Keeping the original and working copy separate is intentional — it preserves the ability to diff before vs after, rerun any script from scratch, and demonstrate exactly what the automation changed.

### `Validation_Errors.xlsx` — Client-facing defect report
A structured workbook sent to the client documenting all defects that could not be resolved automatically due to the sensitivity of the underlying data. Contains five tabs:

| Tab | Contents |
|---|---|
| All Errors | Full defect scorecard showing counts by table and defect type |
| Duplicate Vendors | All duplicate vendor groups with DuplicateRank and TotalInGroup for client to identify golden record |
| Missing or Bad Tax IDs | All 34 vendors with placeholder EINs requiring client to supply real values |
| Negative or Zero Invoice Amount | All 41 negative invoices for AP to confirm as credit memos or reject |
| Negative or Zero Payment Amount | All 35 negative/zero payments for AP to classify |
| No Salary or Hourly Rate | All 62 employees with missing compensation for Payroll sign-off |
| Missing Pay Type | All 6 employees with no pay type for Payroll to classify |
| Negative or Zero GrossPay | All 190 payroll records flagged REJECTED or REVIEW |

This workbook simulates the real-world client communication step that sits between automated cleansing and production posting — the point where a migration analyst stops making assumptions and gets binding business decisions in writing before touching sensitive data.

---

## Office Scripts (Microsoft 365 / Excel for the Web)

> **🚧 Active Development**
> This scripting library is actively being expanded as the migration exercise progresses. Current scripts address the initial defect types identified during data profiling. Additional scripts are being conceptualized and developed as further data quality issues surface and as the pre-load cleansing strategy evolves to smooth the eventual SSIS data load into the target environment. This section will be updated as new scripts are added.

Seven TypeScript Office Scripts for pre-import data cleansing directly in Excel. All scripts share a common pattern:
- Write every change to a `Migration Defect Log` sheet with timestamp, original value, new value, and defect classification
- Use color coding: yellow = flagged/replaced, green = remediated, red = manual review required
- Safe to run independently and in any order — each script skips values handled by the others

### Tax ID (EIN) Scripts — run in order
| Script | What it fixes |
|---|---|
| `taxid_1_fix_blanks.ts` | Null or empty Tax IDs → `99-MIGR####` placeholder |
| `taxid_2_fix_na.ts` | `N/A` Tax IDs → `99-MIGR####` placeholder |
| `taxid_3_fix_pending.ts` | `PENDING` Tax IDs → `99-MIGR####` placeholder |
| `taxid_4_fix_missing_dash.ts` | 9-digit EINs → inserts dash at position 2 (e.g. `123456789` → `12-3456789`). Unknown formats flagged red for manual review. |

### Banking Scripts
| Script | What it fixes |
|---|---|
| `bankacct_fix_blanks.ts` | Missing bank account numbers → `000-MIGR-####` placeholder |
| `routing_fix_blanks.ts` | Missing routing numbers → `999999999` placeholder (clearly invalid, immediately identifiable) |
| `routing_validate_checksum.ts` | Validates existing routing numbers against ABA mod-10 checksum algorithm. Flags failures red. |

### Planned Scripts
Additional cleansing scripts under development, targeting defect types identified during the current cleansing pass and in preparation for SSIS package configuration:
- Phone number format standardization across Vendors and Employees sheets
- Duplicate vendor detection and golden record flagging
- Employee cost center validation against the cost center master list
- Pay type / compensation consistency checks (e.g. Salary employees with no annual salary)
- State code validation against a known state abbreviation list

---

## Key Concepts Demonstrated

**Staging layer architecture**
Loading raw source data into nullable staging tables before applying constraints prevents import failures and preserves the original data for audit purposes. The staging layer also serves as the defect tracking layer throughout cleansing.

**Explicit type casting**
All financial and date comparisons use `TRY_CAST` rather than relying on implicit conversion. Filtering on raw `NVARCHAR` columns against numeric literals causes implicit INT conversion errors — always cast first.

**Negative value classification by business context**
Not all negative values are errors. Negative invoice amounts may be legitimate credit memos. Negative payroll amounts on BONUS, COMM, REIMB, SEVERANCE, and MISC pay codes may be legitimate clawbacks or reversals. The cleansing logic separates automatic rejections from records requiring business sign-off.

**ABA routing number checksum (mod-10)**
Routing numbers have a built-in validity check: `3(d1+d4+d7) + 7(d2+d5+d8) + 1(d3+d6+d9)` must be divisible by 10. The validation script implements this algorithm to catch routing numbers that would fail downstream payment processing.

**Dummy value strategy**
Placeholder values are chosen to be immediately identifiable as migration artifacts:
- Tax IDs: `99-MIGR####` (99- prefix is not a valid IRS EIN prefix)
- Bank accounts: `000-MIGR-####` (000 prefix is not a valid bank prefix)
- Routing numbers: `999999999` (clearly invalid, stands out in any query or report)

**Defect log as audit trail**
Every automated change is written to a `Migration Defect Log` sheet with the original value, replacement value, defect type, and timestamp — so any downstream question about why a value changed can be answered without relying on memory.

---

## How to Run

1. Run `01_schema_ddl.sql` — creates `ERP_TARGET` database and production tables
2. Run `02_staging_ddl.sql` — creates the six `stg_` staging tables
3. Run the Office Scripts against `ERP_Migration_Source_Data_WorkingCopy.xlsx` in the order listed above
4. Import the working copy into staging tables using the SSMS Import and Export Wizard, mapping each sheet to its `stg_` table — or load via `ERP_MIGRATION_PRACTICE_DATA.sql` to skip the Excel import entirely
5. Run `03_validation_and_cleanse.sql` step by step — Step 1 through Step 6
6. Use the defect-specific scripts (`check_INVOICE_errors.sql`, `Duplicate_VendorName.sql`, etc.) to investigate individual defect categories as they surface
7. Export unresolvable defects to a client communication document following the `Validation_Errors.xlsx` format — get written sign-off before posting sensitive payroll or HR records

**Prerequisites**
- SQL Server 2019 or later (Developer or Standard edition)
- SQL Server Management Studio 18+
- Microsoft 365 (for Office Scripts) or Excel desktop with Developer tab enabled (for VBA alternatives)

---

## Skills Demonstrated

`SQL Server` `T-SQL` `ETL` `SSIS` `Data Cleansing` `Data Validation` `Staging Tables` `Window Functions` `TRY_CAST` `TRUNCATE / DELETE` `INSERT...SELECT` `BEGIN TRAN / COMMIT / ROLLBACK` `Reconciliation` `TypeScript` `Office Scripts` `Excel Automation` `ERP Migration` `Accounts Payable` `Payroll Data` `Vendor Master` `Data Quality` `Client Communication` `Defect Documentation`
