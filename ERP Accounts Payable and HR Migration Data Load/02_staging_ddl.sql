-- ============================================================
--  STAGING SCHEMA  (SQL Server)
--  All columns nullable, no FK constraints, no CHECK constraints
--  Purpose: accept raw Excel import as-is, validate before
--           posting to production tables in ERP_TARGET
-- ============================================================

USE ERP_TARGET;
GO

-- drop staging tables if they exist from a previous run
IF OBJECT_ID('dbo.stg_Payments',         'U') IS NOT NULL DROP TABLE dbo.stg_Payments;
IF OBJECT_ID('dbo.stg_Invoices',          'U') IS NOT NULL DROP TABLE dbo.stg_Invoices;
IF OBJECT_ID('dbo.stg_PayrollRecords',    'U') IS NOT NULL DROP TABLE dbo.stg_PayrollRecords;
IF OBJECT_ID('dbo.stg_BenefitElections',  'U') IS NOT NULL DROP TABLE dbo.stg_BenefitElections;
IF OBJECT_ID('dbo.stg_Employees',         'U') IS NOT NULL DROP TABLE dbo.stg_Employees;
IF OBJECT_ID('dbo.stg_Vendors',           'U') IS NOT NULL DROP TABLE dbo.stg_Vendors;
GO

-- ── stg_Vendors ───────────────────────────────────────────────────────────────
CREATE TABLE dbo.stg_Vendors (
    VendorID           NVARCHAR(50)   NULL,
    VendorName         NVARCHAR(255)  NULL,
    VendorType         NVARCHAR(100)  NULL,
    TaxID              NVARCHAR(50)   NULL,
    IsActive           NVARCHAR(10)   NULL,
    AddressLine1       NVARCHAR(255)  NULL,
    AddressLine2       NVARCHAR(255)  NULL,
    City               NVARCHAR(100)  NULL,
    StateCode          NVARCHAR(10)   NULL,
    ZipCode            NVARCHAR(20)   NULL,
    Phone              NVARCHAR(50)   NULL,
    Email              NVARCHAR(255)  NULL,
    PaymentTerms       NVARCHAR(50)   NULL,
    PreferredPayMethod NVARCHAR(50)   NULL,
    BankAccountNum     NVARCHAR(50)   NULL,
    BankRoutingNum     NVARCHAR(20)   NULL,
    CreatedDate        NVARCHAR(20)   NULL,
    LastModified       NVARCHAR(20)   NULL,
    Notes              NVARCHAR(MAX)  NULL,
    -- migration control columns
    stg_LoadDate       DATETIME       NOT NULL DEFAULT GETDATE(),
    stg_Status         NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',  -- PENDING | CLEAN | REJECTED
    stg_ErrorNotes     NVARCHAR(MAX)  NULL
);
GO

-- ── stg_Employees ─────────────────────────────────────────────────────────────
CREATE TABLE dbo.stg_Employees (
    EmployeeID         NVARCHAR(50)   NULL,
    FirstName          NVARCHAR(100)  NULL,
    LastName           NVARCHAR(100)  NULL,
    SSN                NVARCHAR(20)   NULL,
    DateOfBirth        NVARCHAR(20)   NULL,
    HireDate           NVARCHAR(20)   NULL,
    TerminationDate    NVARCHAR(20)   NULL,
    IsActive           NVARCHAR(10)   NULL,
    Department         NVARCHAR(100)  NULL,
    JobTitle           NVARCHAR(100)  NULL,
    ManagerID          NVARCHAR(50)   NULL,
    CostCenter         NVARCHAR(20)   NULL,
    PayType            NVARCHAR(50)   NULL,
    AnnualSalary       NVARCHAR(30)   NULL,
    HourlyRate         NVARCHAR(30)   NULL,
    StandardHours      NVARCHAR(10)   NULL,
    StateCode          NVARCHAR(10)   NULL,
    Email              NVARCHAR(255)  NULL,
    Phone              NVARCHAR(50)   NULL,
    CreatedDate        NVARCHAR(20)   NULL,
    LastModified       NVARCHAR(20)   NULL,
    stg_LoadDate       DATETIME       NOT NULL DEFAULT GETDATE(),
    stg_Status         NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    stg_ErrorNotes     NVARCHAR(MAX)  NULL
);
GO

-- ── stg_BenefitElections ──────────────────────────────────────────────────────
CREATE TABLE dbo.stg_BenefitElections (
    ElectionID         NVARCHAR(50)   NULL,
    EmployeeID         NVARCHAR(50)   NULL,
    BenefitPlan        NVARCHAR(100)  NULL,
    CoverageLevel      NVARCHAR(50)   NULL,
    EmployeeContrib    NVARCHAR(30)   NULL,
    EmployerContrib    NVARCHAR(30)   NULL,
    EffectiveDate      NVARCHAR(20)   NULL,
    EndDate            NVARCHAR(20)   NULL,
    IsActive           NVARCHAR(10)   NULL,
    stg_LoadDate       DATETIME       NOT NULL DEFAULT GETDATE(),
    stg_Status         NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    stg_ErrorNotes     NVARCHAR(MAX)  NULL
);
GO

-- ── stg_PayrollRecords ────────────────────────────────────────────────────────
CREATE TABLE dbo.stg_PayrollRecords (
    PayrollID          NVARCHAR(50)   NULL,
    EmployeeID         NVARCHAR(50)   NULL,
    PayPeriodStart     NVARCHAR(20)   NULL,
    PayPeriodEnd       NVARCHAR(20)   NULL,
    PayCode            NVARCHAR(20)   NULL,
    GrossPay           NVARCHAR(30)   NULL,
    FederalTax         NVARCHAR(30)   NULL,
    StateTax           NVARCHAR(30)   NULL,
    SocialSecurity     NVARCHAR(30)   NULL,
    Medicare           NVARCHAR(30)   NULL,
    OtherDeductions    NVARCHAR(30)   NULL,
    NetPay             NVARCHAR(30)   NULL,
    PaymentMethod      NVARCHAR(50)   NULL,
    PaymentDate        NVARCHAR(20)   NULL,
    GLAccount          NVARCHAR(20)   NULL,
    CostCenter         NVARCHAR(20)   NULL,
    Notes              NVARCHAR(500)  NULL,
    stg_LoadDate       DATETIME       NOT NULL DEFAULT GETDATE(),
    stg_Status         NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    stg_ErrorNotes     NVARCHAR(MAX)  NULL
);
GO

-- ── stg_Invoices ──────────────────────────────────────────────────────────────
CREATE TABLE dbo.stg_Invoices (
    InvoiceID          NVARCHAR(50)   NULL,
    VendorID           NVARCHAR(50)   NULL,
    InvoiceNumber      NVARCHAR(100)  NULL,
    InvoiceDate        NVARCHAR(20)   NULL,
    DueDate            NVARCHAR(20)   NULL,
    InvoiceAmount      NVARCHAR(30)   NULL,
    TaxAmount          NVARCHAR(30)   NULL,
    TotalAmount        NVARCHAR(30)   NULL,
    Status             NVARCHAR(50)   NULL,
    GLAccount          NVARCHAR(20)   NULL,
    CostCenter         NVARCHAR(20)   NULL,
    ApprovedBy         NVARCHAR(100)  NULL,
    PaymentDate        NVARCHAR(20)   NULL,
    PaymentRef         NVARCHAR(100)  NULL,
    Notes              NVARCHAR(500)  NULL,
    stg_LoadDate       DATETIME       NOT NULL DEFAULT GETDATE(),
    stg_Status         NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    stg_ErrorNotes     NVARCHAR(MAX)  NULL
);
GO

-- ── stg_Payments ──────────────────────────────────────────────────────────────
CREATE TABLE dbo.stg_Payments (
    PaymentID          NVARCHAR(50)   NULL,
    InvoiceID          NVARCHAR(50)   NULL,
    VendorID           NVARCHAR(50)   NULL,
    PaymentDate        NVARCHAR(20)   NULL,
    PaymentAmount      NVARCHAR(30)   NULL,
    PaymentMethod      NVARCHAR(50)   NULL,
    PaymentRef         NVARCHAR(100)  NULL,
    BankAccount        NVARCHAR(50)   NULL,
    ClearedDate        NVARCHAR(20)   NULL,
    GLAccount          NVARCHAR(20)   NULL,
    Notes              NVARCHAR(500)  NULL,
    stg_LoadDate       DATETIME       NOT NULL DEFAULT GETDATE(),
    stg_Status         NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    stg_ErrorNotes     NVARCHAR(MAX)  NULL
);
GO

PRINT 'Staging tables created successfully.';
PRINT '';
PRINT 'Import your Excel sheets into these stg_ tables.';
PRINT 'Then run 03_validation_and_cleanse.sql to validate and post to production.';
GO
