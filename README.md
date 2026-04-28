# SQL Training — RampSpendDB

A structured SQL training project built around a realistic FinTech spend management database modeled after platforms like Ramp. The database simulates corporate card transactions, vendor bill pay, employee reimbursements, budget management, and spend policy enforcement across multiple companies.

---

## Database Overview

The schema (`RampSpendDB`) is a multi-tenant SQL Server / MySQL database covering three fictional companies:

| Company | Industry | Plan Tier |
|---|---|---|
| Acme Corp | Manufacturing | Enterprise |
| NovaTech Solutions | Technology | Plus |
| Bright Horizons Media | Media & Advertising | Free |

**Scale:** ~1,600 employees, ~700 corporate cards, ~21,000 transactions spanning 2023–2025 with realistic seasonal spend patterns and policy violation flags.

---

## Schema

Located in `/schema/ramp_mysql.sql`

**17 tables covering:**
- Company, Department, Employee, CostCenter
- Card, Transaction, TransactionReceipt
- Budget, BudgetAllocation
- Vendor, Bill, BillLineItem
- SpendingLimit
- Reimbursement, ReimbursementItem
- MerchantCategory
- AuditLog

**Key design patterns:**
- Multi-tenant isolation by `company_id`
- Polymorphic `SpendingLimit` table (applies to Employee, Department, or Card)
- Soft deletes via `is_active` flags
- Multi-currency support with `usd_amount` normalization
- Self-referencing `Employee` hierarchy for manager reporting
- MCC (Merchant Category Code) based spend classification

---

## Queries

Located in `/queries/`

### 1. SaaS Dual Channel Spend Analysis
**File:** `saas_dual_channel_spend.sql`

**Business Question:** What are we spending on software subscriptions across all companies — both on cards and through vendor bills — and is anything being paid twice through different channels?

**Concepts:** CTE, UNION ALL, CASE statements, dual-channel aggregation, HIGH RISK flagging for identical card and bill amounts

---

### 2. Sales Rep T&E Spend Analysis
**File:** `sales_te_spend_analysis.sql`

**Business Question:** Which sales reps are spending the most on travel and entertainment, and are any of them consistently hitting or exceeding their monthly limits?

**Concepts:** Multi-CTE structure, MCC code filtering, UNION ALL to combine travel and food categories, monthly aggregation with FORMAT(), polymorphic SpendingLimit join, window functions for months-over-limit count, risk rating classification

---

### 3. CFO Bill Payment Analysis
**File:** `cfo_bill_payment_analysis.sql`

**Business Question:** Which vendors are we consistently paying late, and what is our total outstanding liability right now across all three companies?

**Concepts:** CTE, DATEDIFF date logic, CASE for derived overdue status, UNION ALL for detail and total rows, outstanding liability aggregation by company

---

## Skills Demonstrated

- CTE (Common Table Expressions)
- UNION ALL for multi-source aggregation
- Window functions (COUNT OVER PARTITION BY)
- Date arithmetic with DATEDIFF and GETDATE()
- Polymorphic table joins
- CASE statements for business logic and flagging
- Multi-table joins across normalized schema
- Subqueries and correlated filtering
- Aggregation with GROUP BY and HAVING
- Real-world analytical reasoning applied to financial data

---

## Notes

- Schema was provided as a training foundation; all analytical queries and business logic were independently developed
- Transactions table renamed from `Transaction` to `Transactions` to avoid reserved word conflicts in SQL Server
- MySQL version of schema available in `/schema/ramp_mysql.sql` — compatible with MySQL 8.0+
