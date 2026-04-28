-- ============================================================
-- CREATE THE DATABASE
-- ============================================================
USE master;
GO

-- Drop and recreate if it already exists
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'RampSpendDB')
BEGIN
    ALTER DATABASE RampSpendDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RampSpendDB;
END
GO

CREATE DATABASE RampSpendDB
    COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

-- Switch into the new database
USE RampSpendDB;
GO

-- ============================================================
-- PASTE YOUR SCHEMA + SEED DATA BELOW THIS LINE
-- ============================================================

-- ============================================================
-- RAMP-STYLE SPEND MANAGEMENT DATABASE
-- SQL Server (T-SQL) Version
-- ============================================================

-- ============================================================
-- SCHEMA / TABLE CREATION
-- ============================================================

-- Drop tables in reverse dependency order (for re-runs)
IF OBJECT_ID('dbo.AuditLog',           'U') IS NOT NULL DROP TABLE dbo.AuditLog;
IF OBJECT_ID('dbo.ReimbursementItem',  'U') IS NOT NULL DROP TABLE dbo.ReimbursementItem;
IF OBJECT_ID('dbo.Reimbursement',      'U') IS NOT NULL DROP TABLE dbo.Reimbursement;
IF OBJECT_ID('dbo.TransactionReceipt', 'U') IS NOT NULL DROP TABLE dbo.TransactionReceipt;
IF OBJECT_ID('dbo.Transaction',        'U') IS NOT NULL DROP TABLE dbo.Transaction;
IF OBJECT_ID('dbo.BillLineItem',       'U') IS NOT NULL DROP TABLE dbo.BillLineItem;
IF OBJECT_ID('dbo.Bill',               'U') IS NOT NULL DROP TABLE dbo.Bill;
IF OBJECT_ID('dbo.Card',               'U') IS NOT NULL DROP TABLE dbo.Card;
IF OBJECT_ID('dbo.SpendingLimit',      'U') IS NOT NULL DROP TABLE dbo.SpendingLimit;
IF OBJECT_ID('dbo.Vendor',             'U') IS NOT NULL DROP TABLE dbo.Vendor;
IF OBJECT_ID('dbo.BudgetAllocation',   'U') IS NOT NULL DROP TABLE dbo.BudgetAllocation;
IF OBJECT_ID('dbo.Budget',             'U') IS NOT NULL DROP TABLE dbo.Budget;
IF OBJECT_ID('dbo.Employee',           'U') IS NOT NULL DROP TABLE dbo.Employee;
IF OBJECT_ID('dbo.Department',         'U') IS NOT NULL DROP TABLE dbo.Department;
IF OBJECT_ID('dbo.CostCenter',         'U') IS NOT NULL DROP TABLE dbo.CostCenter;
IF OBJECT_ID('dbo.Company',            'U') IS NOT NULL DROP TABLE dbo.Company;
IF OBJECT_ID('dbo.MerchantCategory',   'U') IS NOT NULL DROP TABLE dbo.MerchantCategory;
GO

-- ── MerchantCategory ────────────────────────────────────────
CREATE TABLE dbo.MerchantCategory (
    mcc_code        CHAR(4)      NOT NULL PRIMARY KEY,  -- ISO 18245 MCC
    category_name   VARCHAR(100) NOT NULL,
    parent_category VARCHAR(50)  NOT NULL
);
GO

-- ── Company ─────────────────────────────────────────────────
CREATE TABLE dbo.Company (
    company_id      INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    company_name    VARCHAR(150)  NOT NULL,
    industry        VARCHAR(100)  NOT NULL,
    tax_id          VARCHAR(20)   NOT NULL UNIQUE,
    billing_email   VARCHAR(150)  NOT NULL,
    plan_tier       VARCHAR(20)   NOT NULL CHECK (plan_tier IN ('Free','Plus','Enterprise')),
    created_at      DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    is_active       BIT           NOT NULL DEFAULT 1
);
GO

-- ── CostCenter ──────────────────────────────────────────────
CREATE TABLE dbo.CostCenter (
    cost_center_id   INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    company_id       INT          NOT NULL REFERENCES dbo.Company(company_id),
    code             VARCHAR(20)  NOT NULL,
    name             VARCHAR(100) NOT NULL,
    UNIQUE (company_id, code)
);
GO

-- ── Department ──────────────────────────────────────────────
CREATE TABLE dbo.Department (
    department_id    INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    company_id       INT          NOT NULL REFERENCES dbo.Company(company_id),
    cost_center_id   INT          NULL     REFERENCES dbo.CostCenter(cost_center_id),
    department_name  VARCHAR(100) NOT NULL,
    head_employee_id INT          NULL     -- FK added after Employee table
);
GO

-- ── Employee ─────────────────────────────────────────────────
CREATE TABLE dbo.Employee (
    employee_id      INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    company_id       INT           NOT NULL REFERENCES dbo.Company(company_id),
    department_id    INT           NULL     REFERENCES dbo.Department(department_id),
    manager_id       INT           NULL     REFERENCES dbo.Employee(employee_id),
    first_name       VARCHAR(80)   NOT NULL,
    last_name        VARCHAR(80)   NOT NULL,
    email            VARCHAR(150)  NOT NULL UNIQUE,
    role             VARCHAR(50)   NOT NULL CHECK (role IN ('Admin','Finance','Manager','Employee')),
    hire_date        DATE          NOT NULL,
    employment_status VARCHAR(20)  NOT NULL CHECK (employment_status IN ('Active','Inactive','On Leave')),
    created_at       DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

-- Back-fill the FK on Department
ALTER TABLE dbo.Department
    ADD CONSTRAINT FK_Dept_HeadEmployee
    FOREIGN KEY (head_employee_id) REFERENCES dbo.Employee(employee_id);
GO

-- ── Budget ───────────────────────────────────────────────────
CREATE TABLE dbo.Budget (
    budget_id        INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    company_id       INT            NOT NULL REFERENCES dbo.Company(company_id),
    budget_name      VARCHAR(150)   NOT NULL,
    fiscal_year      SMALLINT       NOT NULL,
    fiscal_quarter   TINYINT        NULL CHECK (fiscal_quarter BETWEEN 1 AND 4),
    total_amount     DECIMAL(18,2)  NOT NULL,
    currency         CHAR(3)        NOT NULL DEFAULT 'USD',
    created_at       DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ── BudgetAllocation ─────────────────────────────────────────
CREATE TABLE dbo.BudgetAllocation (
    allocation_id    INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    budget_id        INT            NOT NULL REFERENCES dbo.Budget(budget_id),
    department_id    INT            NOT NULL REFERENCES dbo.Department(department_id),
    allocated_amount DECIMAL(18,2)  NOT NULL,
    UNIQUE (budget_id, department_id)
);
GO

-- ── Vendor ───────────────────────────────────────────────────
CREATE TABLE dbo.Vendor (
    vendor_id        INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    company_id       INT           NOT NULL REFERENCES dbo.Company(company_id),
    vendor_name      VARCHAR(150)  NOT NULL,
    mcc_code         CHAR(4)       NULL REFERENCES dbo.MerchantCategory(mcc_code),
    payment_terms    VARCHAR(30)   NULL,   -- e.g. 'Net30', 'Net60'
    preferred_currency CHAR(3)     NOT NULL DEFAULT 'USD',
    contact_email    VARCHAR(150)  NULL,
    is_active        BIT           NOT NULL DEFAULT 1
);
GO

-- ── SpendingLimit ────────────────────────────────────────────
CREATE TABLE dbo.SpendingLimit (
    limit_id         INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    company_id       INT            NOT NULL REFERENCES dbo.Company(company_id),
    applies_to       VARCHAR(20)    NOT NULL CHECK (applies_to IN ('Employee','Department','Card')),
    applies_to_id    INT            NOT NULL,  -- FK resolved in application logic
    mcc_code         CHAR(4)        NULL REFERENCES dbo.MerchantCategory(mcc_code),
    period           VARCHAR(20)    NOT NULL CHECK (period IN ('Daily','Weekly','Monthly','Annual','Per Transaction')),
    limit_amount     DECIMAL(18,2)  NOT NULL,
    is_active        BIT            NOT NULL DEFAULT 1
);
GO

-- ── Card ─────────────────────────────────────────────────────
CREATE TABLE dbo.Card (
    card_id          INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    company_id       INT           NOT NULL REFERENCES dbo.Company(company_id),
    employee_id      INT           NOT NULL REFERENCES dbo.Employee(employee_id),
    card_type        VARCHAR(20)   NOT NULL CHECK (card_type IN ('Physical','Virtual')),
    last_four        CHAR(4)       NOT NULL,
    card_network     VARCHAR(20)   NOT NULL DEFAULT 'Visa',
    status           VARCHAR(20)   NOT NULL CHECK (status IN ('Active','Frozen','Cancelled','Expired')),
    issued_date      DATE          NOT NULL,
    expiry_date      DATE          NOT NULL,
    credit_limit     DECIMAL(18,2) NOT NULL,
    nickname         VARCHAR(100)  NULL
);
GO

-- ── Transaction ──────────────────────────────────────────────
CREATE TABLE dbo.[Transaction] (
    transaction_id       INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    card_id              INT            NOT NULL REFERENCES dbo.Card(card_id),
    vendor_id            INT            NULL     REFERENCES dbo.Vendor(vendor_id),
    mcc_code             CHAR(4)        NULL     REFERENCES dbo.MerchantCategory(mcc_code),
    amount               DECIMAL(18,2)  NOT NULL,
    currency             CHAR(3)        NOT NULL DEFAULT 'USD',
    usd_amount           DECIMAL(18,2)  NOT NULL,
    merchant_name        VARCHAR(150)   NOT NULL,
    transaction_date     DATETIME2      NOT NULL,
    posted_date          DATETIME2      NULL,
    status               VARCHAR(20)    NOT NULL CHECK (status IN ('Pending','Posted','Declined','Disputed','Reversed')),
    category             VARCHAR(100)   NULL,
    memo                 NVARCHAR(500)  NULL,
    policy_flag          BIT            NOT NULL DEFAULT 0,
    policy_flag_reason   VARCHAR(200)   NULL,
    cost_center_id       INT            NULL REFERENCES dbo.CostCenter(cost_center_id),
    budget_id            INT            NULL REFERENCES dbo.Budget(budget_id),
    approved_by          INT            NULL REFERENCES dbo.Employee(employee_id),
    approved_at          DATETIME2      NULL
);
GO

-- ── TransactionReceipt ───────────────────────────────────────
CREATE TABLE dbo.TransactionReceipt (
    receipt_id       INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    transaction_id   INT           NOT NULL REFERENCES dbo.[Transaction](transaction_id),
    file_url         VARCHAR(500)  NOT NULL,
    uploaded_at      DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    uploaded_by      INT           NOT NULL REFERENCES dbo.Employee(employee_id)
);
GO

-- ── Bill ─────────────────────────────────────────────────────
CREATE TABLE dbo.Bill (
    bill_id          INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    company_id       INT            NOT NULL REFERENCES dbo.Company(company_id),
    vendor_id        INT            NOT NULL REFERENCES dbo.Vendor(vendor_id),
    invoice_number   VARCHAR(100)   NOT NULL,
    invoice_date     DATE           NOT NULL,
    due_date         DATE           NOT NULL,
    total_amount     DECIMAL(18,2)  NOT NULL,
    currency         CHAR(3)        NOT NULL DEFAULT 'USD',
    status           VARCHAR(20)    NOT NULL CHECK (status IN ('Draft','Pending Approval','Approved','Paid','Overdue','Cancelled')),
    paid_date        DATE           NULL,
    paid_amount      DECIMAL(18,2)  NULL,
    submitted_by     INT            NOT NULL REFERENCES dbo.Employee(employee_id),
    approved_by      INT            NULL     REFERENCES dbo.Employee(employee_id),
    cost_center_id   INT            NULL     REFERENCES dbo.CostCenter(cost_center_id),
    budget_id        INT            NULL     REFERENCES dbo.Budget(budget_id),
    notes            NVARCHAR(1000) NULL
);
GO

-- ── BillLineItem ─────────────────────────────────────────────
CREATE TABLE dbo.BillLineItem (
    line_item_id     INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    bill_id          INT            NOT NULL REFERENCES dbo.Bill(bill_id),
    description      VARCHAR(300)   NOT NULL,
    quantity         DECIMAL(10,3)  NOT NULL DEFAULT 1,
    unit_price       DECIMAL(18,2)  NOT NULL,
    line_total       AS (quantity * unit_price) PERSISTED,
    gl_account       VARCHAR(50)    NULL
);
GO

-- ── Reimbursement ────────────────────────────────────────────
CREATE TABLE dbo.Reimbursement (
    reimbursement_id INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    employee_id      INT            NOT NULL REFERENCES dbo.Employee(employee_id),
    company_id       INT            NOT NULL REFERENCES dbo.Company(company_id),
    report_name      VARCHAR(200)   NOT NULL,
    submitted_date   DATE           NOT NULL,
    total_amount     DECIMAL(18,2)  NOT NULL,
    currency         CHAR(3)        NOT NULL DEFAULT 'USD',
    status           VARCHAR(20)    NOT NULL CHECK (status IN ('Draft','Submitted','Approved','Paid','Rejected')),
    approved_by      INT            NULL REFERENCES dbo.Employee(employee_id),
    approved_date    DATE           NULL,
    paid_date        DATE           NULL
);
GO

-- ── ReimbursementItem ────────────────────────────────────────
CREATE TABLE dbo.ReimbursementItem (
    item_id            INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    reimbursement_id   INT           NOT NULL REFERENCES dbo.Reimbursement(reimbursement_id),
    expense_date       DATE          NOT NULL,
    category           VARCHAR(100)  NOT NULL,
    merchant_name      VARCHAR(150)  NOT NULL,
    amount             DECIMAL(18,2) NOT NULL,
    currency           CHAR(3)       NOT NULL DEFAULT 'USD',
    receipt_url        VARCHAR(500)  NULL,
    notes              VARCHAR(500)  NULL
);
GO

-- ── AuditLog ─────────────────────────────────────────────────
CREATE TABLE dbo.AuditLog (
    log_id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    table_name       VARCHAR(100)   NOT NULL,
    record_id        INT            NOT NULL,
    action           VARCHAR(10)    NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
    changed_by       INT            NULL REFERENCES dbo.Employee(employee_id),
    changed_at       DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    old_values       NVARCHAR(MAX)  NULL,  -- JSON snapshot
    new_values       NVARCHAR(MAX)  NULL   -- JSON snapshot
);
GO

-- ============================================================
-- USEFUL INDEXES
-- ============================================================
CREATE INDEX IX_Transaction_CardId         ON dbo.[Transaction](card_id);
CREATE INDEX IX_Transaction_Date           ON dbo.[Transaction](transaction_date DESC);
CREATE INDEX IX_Transaction_Status         ON dbo.[Transaction](status);
CREATE INDEX IX_Transaction_PolicyFlag     ON dbo.[Transaction](policy_flag) WHERE policy_flag = 1;
CREATE INDEX IX_Card_EmployeeId            ON dbo.Card(employee_id);
CREATE INDEX IX_Bill_CompanyVendor         ON dbo.Bill(company_id, vendor_id);
CREATE INDEX IX_Bill_DueDate               ON dbo.Bill(due_date);
CREATE INDEX IX_Reimbursement_EmployeeId   ON dbo.Reimbursement(employee_id);
GO

-- ============================================================
-- SEED DATA
-- ============================================================

-- MerchantCategory
INSERT INTO dbo.MerchantCategory VALUES
('5411','Grocery Stores','Food & Dining'),
('5812','Restaurants','Food & Dining'),
('5814','Fast Food','Food & Dining'),
('4111','Transportation','Travel'),
('4411','Airlines','Travel'),
('7011','Hotels & Lodging','Travel'),
('5541','Gas Stations','Auto'),
('5045','Computers & Electronics','Technology'),
('7372','SaaS / Software','Technology'),
('5065','Electronic Parts','Technology'),
('5940','Sporting Goods','Retail'),
('5912','Drug Stores','Health'),
('8011','Medical Services','Health'),
('7389','Business Services','Professional Services'),
('8742','Management Consulting','Professional Services'),
('5200','Office Supplies','Office'),
('4813','Telecom Services','Utilities'),
('4900','Utilities','Utilities');
GO

-- Company
INSERT INTO dbo.Company (company_name, industry, tax_id, billing_email, plan_tier) VALUES
('Acme Corp',              'Manufacturing',      '12-3456789', 'finance@acmecorp.com',        'Enterprise'),
('NovaTech Solutions',     'Technology',         '98-7654321', 'billing@novatech.io',         'Plus'),
('Bright Horizons Media',  'Media & Advertising','55-1234567', 'ap@brighthorizons.com',       'Free');
GO

-- CostCenter
INSERT INTO dbo.CostCenter (company_id, code, name) VALUES
(1,'CC-100','Engineering'),
(1,'CC-200','Sales & Marketing'),
(1,'CC-300','General & Administrative'),
(1,'CC-400','Operations'),
(2,'CC-110','Product'),
(2,'CC-210','Growth'),
(2,'CC-310','Finance & Legal'),
(3,'CC-120','Content Production'),
(3,'CC-220','Ad Sales');
GO

-- Department (head_employee_id filled after employees)
INSERT INTO dbo.Department (company_id, cost_center_id, department_name) VALUES
(1, 1, 'Engineering'),       -- dept 1
(1, 2, 'Sales'),             -- dept 2
(1, 3, 'Finance'),           -- dept 3
(1, 4, 'Operations'),        -- dept 4
(2, 5, 'Product'),           -- dept 5
(2, 6, 'Marketing'),         -- dept 6
(2, 7, 'Finance'),           -- dept 7
(3, 8, 'Content'),           -- dept 8
(3, 9, 'Ad Sales');          -- dept 9
GO

-- Employee  (first 3 = managers/admins for company 1)
INSERT INTO dbo.Employee (company_id, department_id, manager_id, first_name, last_name, email, role, hire_date, employment_status) VALUES
-- Acme Corp
(1, 3, NULL, 'Sarah',    'Mitchell',  'sarah.mitchell@acmecorp.com',   'Admin',    '2018-03-01', 'Active'),   -- 1
(1, 2, NULL, 'James',    'Thornton',  'james.thornton@acmecorp.com',   'Manager',  '2019-06-15', 'Active'),   -- 2
(1, 1, NULL, 'Linda',    'Park',      'linda.park@acmecorp.com',       'Manager',  '2020-01-10', 'Active'),   -- 3
(1, 1, 3,    'Michael',  'Reyes',     'michael.reyes@acmecorp.com',    'Employee', '2021-04-20', 'Active'),   -- 4
(1, 1, 3,    'Amy',      'Chen',      'amy.chen@acmecorp.com',         'Employee', '2022-07-11', 'Active'),   -- 5
(1, 2, 2,    'David',    'Nguyen',    'david.nguyen@acmecorp.com',     'Employee', '2021-09-01', 'Active'),   -- 6
(1, 2, 2,    'Priya',    'Sharma',    'priya.sharma@acmecorp.com',     'Employee', '2023-02-14', 'Active'),   -- 7
(1, 3, 1,    'Kevin',    'Walsh',     'kevin.walsh@acmecorp.com',      'Finance',  '2020-11-03', 'Active'),   -- 8
(1, 4, NULL, 'Olivia',   'Brooks',    'olivia.brooks@acmecorp.com',    'Manager',  '2019-08-22', 'Active'),   -- 9
(1, 4, 9,    'Ryan',     'Foster',    'ryan.foster@acmecorp.com',      'Employee', '2022-03-05', 'On Leave'), -- 10
-- NovaTech Solutions
(2, 5, NULL, 'Elena',    'Vasquez',   'elena.vasquez@novatech.io',     'Admin',    '2020-05-17', 'Active'),   -- 11
(2, 6, NULL, 'Marcus',   'Jordan',    'marcus.jordan@novatech.io',     'Manager',  '2021-02-08', 'Active'),   -- 12
(2, 5, 11,   'Tiffany',  'Lee',       'tiffany.lee@novatech.io',       'Employee', '2022-10-19', 'Active'),   -- 13
(2, 6, 12,   'Connor',   'Hughes',    'connor.hughes@novatech.io',     'Employee', '2023-06-01', 'Active'),   -- 14
(2, 7, NULL, 'Rachel',   'Kim',       'rachel.kim@novatech.io',        'Finance',  '2021-07-30', 'Active'),   -- 15
-- Bright Horizons Media
(3, 8, NULL, 'Andre',    'Williams',  'andre.williams@brighthorizons.com', 'Admin', '2019-01-14','Active'),  -- 16
(3, 9, NULL, 'Jessica',  'Monroe',    'jessica.monroe@brighthorizons.com', 'Manager','2020-09-28','Active'), -- 17
(3, 8, 16,   'Tommy',    'Garcia',    'tommy.garcia@brighthorizons.com',   'Employee','2023-03-15','Active'); -- 18
GO

-- Update department heads
UPDATE dbo.Department SET head_employee_id = 3  WHERE department_id = 1;
UPDATE dbo.Department SET head_employee_id = 2  WHERE department_id = 2;
UPDATE dbo.Department SET head_employee_id = 1  WHERE department_id = 3;
UPDATE dbo.Department SET head_employee_id = 9  WHERE department_id = 4;
UPDATE dbo.Department SET head_employee_id = 11 WHERE department_id = 5;
UPDATE dbo.Department SET head_employee_id = 12 WHERE department_id = 6;
UPDATE dbo.Department SET head_employee_id = 15 WHERE department_id = 7;
UPDATE dbo.Department SET head_employee_id = 16 WHERE department_id = 8;
UPDATE dbo.Department SET head_employee_id = 17 WHERE department_id = 9;
GO

-- Budget
INSERT INTO dbo.Budget (company_id, budget_name, fiscal_year, fiscal_quarter, total_amount) VALUES
(1, 'Acme FY2024 Annual',        2024, NULL, 2500000.00),
(1, 'Acme Q1-2025 Operations',   2025, 1,     450000.00),
(1, 'Acme Q2-2025 Operations',   2025, 2,     480000.00),
(2, 'NovaTech FY2024',           2024, NULL,  800000.00),
(2, 'NovaTech Q1-2025',          2025, 1,     210000.00),
(3, 'BHM FY2024',                2024, NULL,  350000.00);
GO

-- BudgetAllocation
INSERT INTO dbo.BudgetAllocation (budget_id, department_id, allocated_amount) VALUES
(1, 1, 900000.00),(1, 2, 600000.00),(1, 3, 300000.00),(1, 4, 700000.00),
(2, 1, 160000.00),(2, 2, 130000.00),(2, 3,  60000.00),(2, 4, 100000.00),
(3, 1, 175000.00),(3, 2, 140000.00),(3, 3,  65000.00),(3, 4, 100000.00),
(4, 5, 350000.00),(4, 6, 250000.00),(4, 7, 200000.00),
(5, 5,  90000.00),(5, 6,  70000.00),(5, 7,  50000.00),
(6, 8, 200000.00),(6, 9, 150000.00);
GO

-- Vendor
INSERT INTO dbo.Vendor (company_id, vendor_name, mcc_code, payment_terms, contact_email) VALUES
(1, 'AWS',              '7372', 'Net30', 'billing@aws.amazon.com'),
(1, 'Salesforce',       '7372', 'Net30', 'ar@salesforce.com'),
(1, 'Delta Airlines',   '4411', 'Net15', NULL),
(1, 'Marriott Hotels',  '7011', 'Net15', NULL),
(1, 'Office Depot',     '5200', 'Net30', 'ar@officedepot.com'),
(1, 'AT&T',             '4813', 'Net30', 'billing@att.com'),
(2, 'Google Cloud',     '7372', 'Net30', 'billing@google.com'),
(2, 'HubSpot',          '7372', 'Net30', 'ar@hubspot.com'),
(2, 'United Airlines',  '4411', 'Net15', NULL),
(2, 'Hilton Hotels',    '7011', 'Net15', NULL),
(3, 'Adobe Creative',   '7372', 'Net30', 'ar@adobe.com'),
(3, 'Comcast Business', '4813', 'Net30', 'billing@comcast.com');
GO

-- SpendingLimit
INSERT INTO dbo.SpendingLimit (company_id, applies_to, applies_to_id, mcc_code, period, limit_amount) VALUES
(1, 'Employee',    4,    NULL,   'Monthly',          5000.00),
(1, 'Employee',    5,    NULL,   'Monthly',          5000.00),
(1, 'Employee',    6,    NULL,   'Monthly',          8000.00),
(1, 'Employee',    7,    NULL,   'Monthly',          5000.00),
(1, 'Employee',    4,    '5812', 'Monthly',           200.00),  -- dining cap
(1, 'Department',  2,    '4411', 'Monthly',         15000.00),  -- Sales travel cap
(1, 'Employee',    10,   NULL,   'Per Transaction',   500.00),
(2, 'Employee',    13,   NULL,   'Monthly',          6000.00),
(2, 'Employee',    14,   NULL,   'Monthly',          4000.00),
(2, 'Department',  6,    '7372', 'Monthly',         10000.00);
GO

-- Card
INSERT INTO dbo.Card (company_id, employee_id, card_type, last_four, status, issued_date, expiry_date, credit_limit, nickname) VALUES
(1,  4, 'Physical', '4821', 'Active',    '2023-01-15', '2026-01-31', 10000.00, 'Engineering Card'),
(1,  5, 'Virtual',  '7743', 'Active',    '2023-03-01', '2026-03-31',  5000.00, 'AWS Subscription'),
(1,  6, 'Physical', '3302', 'Active',    '2022-09-10', '2025-09-30', 15000.00, 'Sales Card'),
(1,  7, 'Virtual',  '9981', 'Active',    '2023-06-20', '2026-06-30',  5000.00, 'Salesforce License'),
(1,  8, 'Physical', '1154', 'Active',    '2021-11-05', '2024-11-30', 20000.00, 'Finance Card'),
(1,  9, 'Physical', '6637', 'Active',    '2022-04-18', '2025-04-30', 25000.00, 'Ops Manager'),
(1, 10, 'Physical', '2290', 'Frozen',    '2023-02-01', '2026-02-28',  3000.00, NULL),
(2, 13, 'Physical', '5512', 'Active',    '2023-07-11', '2026-07-31',  8000.00, 'Product Card'),
(2, 14, 'Virtual',  '8834', 'Active',    '2024-01-05', '2027-01-31',  4000.00, 'Growth Marketing'),
(2, 15, 'Physical', '3367', 'Active',    '2022-12-01', '2025-12-31', 12000.00, 'Finance Ops'),
(3, 17, 'Physical', '7721', 'Active',    '2023-05-22', '2026-05-31',  6000.00, 'Ad Sales'),
(3, 18, 'Virtual',  '4490', 'Active',    '2024-02-14', '2027-02-28',  3000.00, 'Content Tools');
GO

-- Transaction (rich realistic mix)
INSERT INTO dbo.[Transaction] (card_id, vendor_id, mcc_code, amount, currency, usd_amount, merchant_name, transaction_date, posted_date, status, category, memo, policy_flag, policy_flag_reason, cost_center_id, budget_id, approved_by, approved_at)
VALUES
-- Michael Reyes (card 1, eng)
(1,  1, '7372',  3200.00, 'USD',  3200.00, 'Amazon Web Services',  '2025-01-05 09:12:00', '2025-01-06 08:00:00', 'Posted',  'SaaS/Software',       'Jan EC2 usage',     0, NULL, 1, 2,  8, '2025-01-06 10:00:00'),
(1, NULL,'5812',   185.50, 'USD',   185.50, 'The Capital Grille',  '2025-01-14 19:45:00', '2025-01-15 08:00:00', 'Posted',  'Food & Dining',       'Team dinner',       1, 'Exceeds dining limit', 1, 2, 1, '2025-01-15 09:30:00'),
(1, NULL,'4411',   842.00, 'USD',   842.00, 'Delta Airlines',      '2025-02-02 07:00:00', '2025-02-03 08:00:00', 'Posted',  'Travel - Air',        'SFO conf trip',     0, NULL, 1, 3,  3, '2025-02-03 09:00:00'),
(1, NULL,'7011',   429.00, 'USD',   429.00, 'Marriott San Fran',   '2025-02-04 15:00:00', '2025-02-06 08:00:00', 'Posted',  'Travel - Hotel',      'SFO conf hotel',    0, NULL, 1, 3,  3, '2025-02-06 09:00:00'),
(1, NULL,'5812',    62.30, 'USD',    62.30, 'Chipotle Mexican Grill','2025-03-10 12:30:00','2025-03-11 08:00:00','Posted',  'Food & Dining',       NULL,                0, NULL, 1, 3, NULL, NULL),
-- Amy Chen (card 2, virtual/AWS)
(2,  1, '7372', 12800.00, 'USD', 12800.00, 'Amazon Web Services',  '2025-01-31 23:59:00', '2025-02-01 08:00:00', 'Posted',  'SaaS/Software',       'Prod infra - Jan',  0, NULL, 1, 2,  8, '2025-02-01 10:00:00'),
(2,  1, '7372', 13450.00, 'USD', 13450.00, 'Amazon Web Services',  '2025-02-28 23:59:00', '2025-03-01 08:00:00', 'Posted',  'SaaS/Software',       'Prod infra - Feb',  0, NULL, 1, 3,  8, '2025-03-01 10:00:00'),
-- David Nguyen (card 3, Sales)
(3, NULL,'4411',  1240.00, 'USD',  1240.00, 'United Airlines',     '2025-01-08 06:30:00', '2025-01-09 08:00:00', 'Posted',  'Travel - Air',        'NYC client visit',  0, NULL, 2, 2,  2, '2025-01-09 09:00:00'),
(3, NULL,'7011',   695.00, 'USD',   695.00, 'Hilton Midtown NYC',  '2025-01-08 14:00:00', '2025-01-10 08:00:00', 'Posted',  'Travel - Hotel',      'NYC client hotel',  0, NULL, 2, 2,  2, '2025-01-10 09:00:00'),
(3, NULL,'5812',   340.75, 'USD',   340.75, 'Per Se Restaurant',   '2025-01-09 20:00:00', '2025-01-10 08:00:00', 'Posted',  'Food & Dining',       'Client dinner',     1, 'Missing client name in memo', 2, 2, 2, '2025-01-11 10:00:00'),
(3, NULL,'4411',   988.00, 'USD',   988.00, 'Delta Airlines',      '2025-02-18 06:00:00', '2025-02-19 08:00:00', 'Posted',  'Travel - Air',        'Chicago sales conf',0, NULL, 2, 3,  2, '2025-02-19 09:00:00'),
(3, NULL,'5541',    78.42, 'USD',    78.42, 'Shell Gas Station',   '2025-03-05 08:15:00', '2025-03-06 08:00:00', 'Posted',  'Auto - Fuel',         'Rental car fuel',   0, NULL, 2, 3, NULL, NULL),
-- Priya Sharma (card 4, virtual/Salesforce)
(4,  2, '7372',  5400.00, 'USD',  5400.00, 'Salesforce',          '2025-01-15 09:00:00', '2025-01-16 08:00:00', 'Posted',  'SaaS/Software',       'Q1 SFDC license',   0, NULL, 2, 2,  8, '2025-01-16 10:00:00'),
(4,  2, '7372',  5400.00, 'USD',  5400.00, 'Salesforce',          '2025-04-15 09:00:00', '2025-04-16 08:00:00', 'Pending', 'SaaS/Software',       'Q2 SFDC license',   0, NULL, 2, 3, NULL, NULL),
-- Kevin Walsh (card 5, Finance)
(5, NULL,'5200',   412.88, 'USD',   412.88, 'Office Depot',       '2025-01-20 10:00:00', '2025-01-21 08:00:00', 'Posted',  'Office Supplies',     'Printer paper/ink', 0, NULL, 3, 2,  1, '2025-01-21 11:00:00'),
(5, NULL,'4813',  1800.00, 'USD',  1800.00, 'AT&T Business',      '2025-02-01 00:00:00', '2025-02-02 08:00:00', 'Posted',  'Telecom',             'Feb phone plan',    0, NULL, 3, 3,  1, '2025-02-02 09:00:00'),
(5, NULL,'8742', 18500.00, 'USD', 18500.00, 'Deloitte Consulting', '2025-03-01 09:00:00','2025-03-02 08:00:00', 'Posted',  'Professional Svcs',  'Audit prep Q1',     0, NULL, 3, 3,  1, '2025-03-02 10:00:00'),
-- Olivia Brooks (card 6, Ops)
(6, NULL,'4111',   215.00, 'USD',   215.00, 'Uber for Business',  '2025-01-12 07:30:00', '2025-01-13 08:00:00', 'Posted',  'Transportation',      'Airport transfer',  0, NULL, 4, 2,  9, '2025-01-13 09:00:00'),
(6,  5, '5200',  1250.00, 'USD',  1250.00, 'Office Depot',        '2025-02-10 11:00:00', '2025-02-11 08:00:00', 'Posted',  'Office Supplies',     'New hire setup x5', 0, NULL, 4, 3,  1, '2025-02-11 09:00:00'),
-- Ryan Foster (card 7, Frozen)
(7, NULL,'5812',   620.00, 'USD',   620.00, 'Nobu Restaurant',    '2024-12-20 19:00:00', '2024-12-21 08:00:00', 'Disputed','Food & Dining',       NULL,                1, 'Card frozen post-dispute', 3, 1, NULL, NULL),
-- NovaTech - Tiffany Lee (card 8)
(8,  7, '7372',  4200.00, 'USD',  4200.00, 'Google Cloud',        '2025-01-31 23:59:00', '2025-02-01 08:00:00', 'Posted',  'SaaS/Software',       'GCP Jan infra',     0, NULL, 5, 5, 15, '2025-02-01 10:00:00'),
(8, NULL,'4411',   776.00, 'USD',   776.00, 'United Airlines',    '2025-02-14 06:00:00', '2025-02-15 08:00:00', 'Posted',  'Travel - Air',        'LA product summit', 0, NULL, 5, 5, 11, '2025-02-15 09:00:00'),
-- NovaTech - Connor Hughes (card 9)
(9,  8, '7372',  2800.00, 'USD',  2800.00, 'HubSpot',             '2025-01-20 09:00:00', '2025-01-21 08:00:00', 'Posted',  'SaaS/Software',       'HubSpot Q1',        0, NULL, 6, 5, 15, '2025-01-21 10:00:00'),
(9, NULL,'5812',   140.00, 'USD',   140.00, 'The Olive Garden',   '2025-02-05 12:30:00', '2025-02-06 08:00:00', 'Posted',  'Food & Dining',       'Team lunch',        0, NULL, 6, 5, 12, '2025-02-06 09:00:00'),
(9, NULL,'5045',  3750.00, 'USD',  3750.00, 'Apple Store B2B',    '2025-03-01 10:00:00', '2025-03-02 08:00:00', 'Posted',  'Electronics',         'MacBook for hire',  1, 'Exceeds per-transaction limit', 6, 5, 11, '2025-03-02 10:00:00'),
-- BHM - Jessica Monroe (card 11)
(11,NULL,'5812',   275.60, 'USD',   275.60, 'STK Steakhouse',     '2025-01-28 20:00:00', '2025-01-29 08:00:00', 'Posted',  'Food & Dining',       'Client dinner',     0, NULL, 9, 6, 16, '2025-01-29 09:00:00'),
(11,NULL,'4411',   590.00, 'USD',   590.00, 'American Airlines',  '2025-02-20 07:00:00', '2025-02-21 08:00:00', 'Posted',  'Travel - Air',        'Chicago client',    0, NULL, 9, 6, 16, '2025-02-21 09:00:00'),
-- BHM - Tommy Garcia (card 12)
(12,11, '7372',  1200.00, 'USD',  1200.00, 'Adobe Creative Cloud','2025-01-01 09:00:00', '2025-01-02 08:00:00', 'Posted',  'SaaS/Software',       'Annual CC plan',    0, NULL, 8, 6, 16, '2025-01-02 09:00:00'),
(12,NULL,'5812',    48.90, 'USD',    48.90, 'Sweetgreen',         '2025-03-15 13:00:00', '2025-03-16 08:00:00', 'Declined','Food & Dining',       NULL,                1, 'Card over limit', 8, 6, NULL, NULL);
GO

-- TransactionReceipt
INSERT INTO dbo.TransactionReceipt (transaction_id, file_url, uploaded_by) VALUES
(1,  'https://receipts.ramp.com/acme/txn-0001.pdf', 4),
(3,  'https://receipts.ramp.com/acme/txn-0003.pdf', 4),
(4,  'https://receipts.ramp.com/acme/txn-0004.pdf', 4),
(6,  'https://receipts.ramp.com/acme/txn-0006.pdf', 5),
(7,  'https://receipts.ramp.com/acme/txn-0007.pdf', 5),
(8,  'https://receipts.ramp.com/acme/txn-0008.pdf', 6),
(9,  'https://receipts.ramp.com/acme/txn-0009.pdf', 6),
(13, 'https://receipts.ramp.com/acme/txn-0013.pdf', 7),
(15, 'https://receipts.ramp.com/acme/txn-0015.pdf', 8),
(17, 'https://receipts.ramp.com/acme/txn-0017.pdf', 8),
(21, 'https://receipts.ramp.com/nova/txn-0021.pdf', 13),
(24, 'https://receipts.ramp.com/nova/txn-0024.pdf', 14),
(27, 'https://receipts.ramp.com/bhm/txn-0027.pdf', 17);
GO

-- Bill
INSERT INTO dbo.Bill (company_id, vendor_id, invoice_number, invoice_date, due_date, total_amount, status, paid_date, paid_amount, submitted_by, approved_by, cost_center_id, budget_id, notes) VALUES
(1, 1, 'AWS-2025-0102', '2025-01-31', '2025-03-02',  15200.00, 'Paid',            '2025-02-28', 15200.00,  8, 1, 1, 2,  'Jan+Feb AWS consolidated'),
(1, 2, 'SF-Q1-2025',    '2025-01-15', '2025-02-14',   5400.00, 'Paid',            '2025-02-10',  5400.00,  8, 1, 2, 2,  'Salesforce Q1 seats'),
(1, 6, 'ATT-202502',    '2025-02-01', '2025-03-03',   1800.00, 'Paid',            '2025-02-28',  1800.00,  8, 1, 3, 3,  'Feb telecom'),
(1, 5, 'OD-2025-0320',  '2025-03-10', '2025-04-09',    825.50, 'Approved',        NULL,          NULL,      8, 1, 3, 3,  'Office supplies Q1'),
(1, 3, 'DAL-2025-0201', '2025-02-15', '2025-03-17',   3070.00, 'Paid',            '2025-03-15',  3070.00,  8, 1, 1, 3,  'Feb travel reimbursements'),
(2, 7, 'GCP-2025-FEB',  '2025-02-28', '2025-03-30',   4200.00, 'Pending Approval',NULL,          NULL,     15, NULL,5, 5,  NULL),
(2, 8, 'HS-Q1-2025',    '2025-01-20', '2025-02-19',   2800.00, 'Paid',            '2025-02-18',  2800.00, 15, 11, 6, 5,  'HubSpot annual'),
(3,11, 'ADO-2025-01',   '2025-01-01', '2025-01-31',   1200.00, 'Paid',            '2025-01-28',  1200.00, 18, 16, 8, 6,  'Adobe Creative Cloud');
GO

-- BillLineItem
INSERT INTO dbo.BillLineItem (bill_id, description, quantity, unit_price, gl_account) VALUES
(1, 'EC2 Compute - us-east-1',     1, 8400.00, '6100-Cloud'),
(1, 'S3 Storage',                  1, 3200.00, '6100-Cloud'),
(1, 'RDS Database',                1, 3600.00, '6100-Cloud'),
(2, 'Salesforce Sales Cloud - 10 seats', 10, 540.00, '6200-SaaS'),
(3, 'AT&T Business Phone Plan',    30,   60.00, '6400-Telecom'),
(4, 'Printer Paper (case x10)',    10,   52.50, '6500-Office'),
(4, 'Toner Cartridges',             5,   37.00, '6500-Office'),
(5, 'Delta Corp Travel - Feb',      1, 3070.00, '6300-Travel'),
(6, 'GCP Compute Engine',          1, 2800.00, '6100-Cloud'),
(6, 'BigQuery',                    1, 1400.00, '6100-Cloud'),
(7, 'HubSpot Marketing Hub',       5,  560.00, '6200-SaaS'),
(8, 'Adobe Creative Cloud - All Apps', 1, 1200.00, '6200-SaaS');
GO

-- Reimbursement
INSERT INTO dbo.Reimbursement (employee_id, company_id, report_name, submitted_date, total_amount, status, approved_by, approved_date, paid_date) VALUES
(4,  1, 'Michael - Feb Conference Expenses',   '2025-02-10', 1271.00, 'Paid',      8, '2025-02-12', '2025-02-20'),
(6,  1, 'David - NYC Client Trip Jan 2025',    '2025-01-15', 2278.75, 'Paid',      2, '2025-01-17', '2025-01-25'),
(9,  1, 'Olivia - Q1 Misc Expenses',           '2025-03-31',  215.00, 'Approved',  1, '2025-04-02', NULL),
(13, 2, 'Tiffany - LA Summit Feb 2025',        '2025-02-20',  776.00, 'Paid',     11, '2025-02-22', '2025-03-01'),
(17, 3, 'Jessica - Chicago Trip Feb 2025',     '2025-03-01',  865.60, 'Submitted', NULL, NULL,      NULL);
GO

-- ReimbursementItem
INSERT INTO dbo.ReimbursementItem (reimbursement_id, expense_date, category, merchant_name, amount, receipt_url, notes) VALUES
(1, '2025-02-02', 'Travel - Air',   'Delta Airlines',          842.00, 'https://receipts.ramp.com/acme/reimb-001-a.pdf', 'SFO conf flight'),
(1, '2025-02-04', 'Travel - Hotel', 'Marriott San Francisco',  429.00, 'https://receipts.ramp.com/acme/reimb-001-b.pdf', '2 nights'),
(2, '2025-01-08', 'Travel - Air',   'United Airlines',        1240.00, 'https://receipts.ramp.com/acme/reimb-002-a.pdf', 'NYC flight'),
(2, '2025-01-08', 'Travel - Hotel', 'Hilton Midtown NYC',      695.00, 'https://receipts.ramp.com/acme/reimb-002-b.pdf', '2 nights'),
(2, '2025-01-09', 'Food & Dining',  'Per Se Restaurant',       340.75, 'https://receipts.ramp.com/acme/reimb-002-c.pdf', 'Client dinner'),
(2, '2025-01-12', 'Transportation', 'Uber for Business',         3.00, NULL, 'Airport ride'),
(3, '2025-01-12', 'Transportation', 'Uber for Business',       215.00, 'https://receipts.ramp.com/acme/reimb-003-a.pdf', 'Airport transfer'),
(4, '2025-02-14', 'Travel - Air',   'United Airlines',         776.00, 'https://receipts.ramp.com/nova/reimb-004-a.pdf', 'LA summit'),
(5, '2025-01-28', 'Food & Dining',  'STK Steakhouse',          275.60, 'https://receipts.ramp.com/bhm/reimb-005-a.pdf',  'Client dinner'),
(5, '2025-02-20', 'Travel - Air',   'American Airlines',       590.00, 'https://receipts.ramp.com/bhm/reimb-005-b.pdf',  'Chicago client trip');
GO

-- ============================================================
-- SAMPLE INTERVIEW QUERIES
-- ============================================================

-- 1. Monthly spend by department (Acme Corp, 2025)
/*
SELECT
    d.department_name,
    FORMAT(t.transaction_date, 'yyyy-MM')   AS [Month],
    SUM(t.usd_amount)                       AS total_spend,
    COUNT(*)                                AS txn_count
FROM dbo.[Transaction] t
JOIN dbo.Card          c  ON t.card_id       = c.card_id
JOIN dbo.Employee      e  ON c.employee_id   = e.employee_id
JOIN dbo.Department    d  ON e.department_id = d.department_id
WHERE d.company_id = 1
  AND t.status     = 'Posted'
  AND YEAR(t.transaction_date) = 2025
GROUP BY d.department_name, FORMAT(t.transaction_date, 'yyyy-MM')
ORDER BY [Month], total_spend DESC;
*/

-- 2. Policy violations with employee detail
/*
SELECT
    e.first_name + ' ' + e.last_name AS employee,
    d.department_name,
    t.merchant_name,
    t.usd_amount,
    t.policy_flag_reason,
    t.transaction_date
FROM dbo.[Transaction] t
JOIN dbo.Card       c ON t.card_id     = c.card_id
JOIN dbo.Employee   e ON c.employee_id = e.employee_id
JOIN dbo.Department d ON e.department_id = d.department_id
WHERE t.policy_flag = 1
ORDER BY t.transaction_date DESC;
*/

-- 3. Budget utilization by department
/*
SELECT
    d.department_name,
    b.budget_name,
    ba.allocated_amount,
    ISNULL(SUM(t.usd_amount),0)                              AS actual_spend,
    ba.allocated_amount - ISNULL(SUM(t.usd_amount),0)       AS remaining,
    CAST(ISNULL(SUM(t.usd_amount),0) * 100.0
         / ba.allocated_amount AS DECIMAL(5,1))              AS pct_used
FROM dbo.BudgetAllocation ba
JOIN dbo.Budget     b  ON ba.budget_id     = b.budget_id
JOIN dbo.Department d  ON ba.department_id = d.department_id
LEFT JOIN dbo.[Transaction] t
       ON t.budget_id = ba.budget_id
      AND t.status    = 'Posted'
WHERE b.company_id = 1
GROUP BY d.department_name, b.budget_name, ba.allocated_amount
ORDER BY pct_used DESC;
*/

-- 4. Top 5 merchants by total spend (all companies)
/*
SELECT TOP 5
    merchant_name,
    COUNT(*)           AS txn_count,
    SUM(usd_amount)    AS total_spend
FROM dbo.[Transaction]
WHERE status = 'Posted'
GROUP BY merchant_name
ORDER BY total_spend DESC;
*/

-- 5. Overdue bills
/*
SELECT
    c.company_name,
    v.vendor_name,
    b.invoice_number,
    b.due_date,
    b.total_amount,
    DATEDIFF(DAY, b.due_date, CAST(GETDATE() AS DATE)) AS days_overdue
FROM dbo.Bill    b
JOIN dbo.Company c ON b.company_id = c.company_id
JOIN dbo.Vendor  v ON b.vendor_id  = v.vendor_id
WHERE b.status NOT IN ('Paid','Cancelled')
  AND b.due_date < CAST(GETDATE() AS DATE)
ORDER BY days_overdue DESC;
*/