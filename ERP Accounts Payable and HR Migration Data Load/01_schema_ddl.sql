-- ============================================================
--  ERP MIGRATION PRACTICE SCHEMA  (SQL Server)
--  Target database: ERP_TARGET
--  Run this file first to create the clean target schema.
-- ============================================================

USE master;
GO
IF DB_ID('ERP_TARGET') IS NOT NULL
    DROP DATABASE ERP_TARGET;
GO
CREATE DATABASE ERP_TARGET;
GO
USE ERP_TARGET;
GO

-- ── 1. VENDORS ────────────────────────────────────────────────────────────────
CREATE TABLE dbo.Vendors (
    VendorID        INT             NOT NULL PRIMARY KEY,
    VendorName      NVARCHAR(255)   NOT NULL,
    VendorType      NVARCHAR(100)   NULL,
    TaxID           NVARCHAR(20)    NULL,        -- EIN  XX-XXXXXXX
    IsActive        BIT             NOT NULL DEFAULT 1,
    AddressLine1    NVARCHAR(255)   NULL,
    AddressLine2    NVARCHAR(255)   NULL,
    City            NVARCHAR(100)   NULL,
    StateCode       CHAR(2)         NULL,
    ZipCode         NVARCHAR(10)    NULL,
    Phone           NVARCHAR(20)    NULL,
    Email           NVARCHAR(255)   NULL,
    PaymentTerms    NVARCHAR(50)    NULL,
    PreferredPayMethod NVARCHAR(50) NULL,
    BankAccountNum  NVARCHAR(50)    NULL,
    BankRoutingNum  NVARCHAR(20)    NULL,
    CreatedDate     DATE            NULL,
    LastModified    DATE            NULL,
    Notes           NVARCHAR(MAX)   NULL
);
GO

-- ── 2. EMPLOYEES ─────────────────────────────────────────────────────────────
CREATE TABLE dbo.Employees (
    EmployeeID      INT             NOT NULL PRIMARY KEY,
    FirstName       NVARCHAR(100)   NOT NULL,
    LastName        NVARCHAR(100)   NOT NULL,
    SSN             NVARCHAR(11)    NULL,        -- XXX-XX-XXXX (masked in practice)
    DateOfBirth     DATE            NULL,
    HireDate        DATE            NOT NULL,
    TerminationDate DATE            NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    Department      NVARCHAR(100)   NULL,
    JobTitle        NVARCHAR(100)   NULL,
    ManagerID       INT             NULL,
    CostCenter      NVARCHAR(20)    NULL,
    PayType         NVARCHAR(50)    NULL,
    AnnualSalary    DECIMAL(12,2)   NULL,
    HourlyRate      DECIMAL(8,2)    NULL,
    StandardHours   DECIMAL(5,2)    NULL DEFAULT 40,
    StateCode       CHAR(2)         NULL,
    Email           NVARCHAR(255)   NULL,
    Phone           NVARCHAR(20)    NULL,
    CreatedDate     DATE            NULL,
    LastModified    DATE            NULL
);
GO

-- ── 3. BENEFIT ELECTIONS ──────────────────────────────────────────────────────
CREATE TABLE dbo.BenefitElections (
    ElectionID      INT             NOT NULL PRIMARY KEY,
    EmployeeID      INT             NOT NULL REFERENCES dbo.Employees(EmployeeID),
    BenefitPlan     NVARCHAR(100)   NOT NULL,
    CoverageLevel   NVARCHAR(50)    NULL,        -- Employee, Employee+Spouse, Family
    EmployeeContrib DECIMAL(10,2)   NULL,
    EmployerContrib DECIMAL(10,2)   NULL,
    EffectiveDate   DATE            NOT NULL,
    EndDate         DATE            NULL,
    IsActive        BIT             NOT NULL DEFAULT 1
);
GO

-- ── 4. PAYROLL RECORDS ────────────────────────────────────────────────────────
CREATE TABLE dbo.PayrollRecords (
    PayrollID       INT             NOT NULL PRIMARY KEY,
    EmployeeID      INT             NOT NULL REFERENCES dbo.Employees(EmployeeID),
    PayPeriodStart  DATE            NOT NULL,
    PayPeriodEnd    DATE            NOT NULL,
    PayCode         NVARCHAR(20)    NOT NULL,
    GrossPay        DECIMAL(12,2)   NOT NULL,
    FederalTax      DECIMAL(10,2)   NULL,
    StateTax        DECIMAL(10,2)   NULL,
    SocialSecurity  DECIMAL(10,2)   NULL,
    Medicare        DECIMAL(10,2)   NULL,
    OtherDeductions DECIMAL(10,2)   NULL,
    NetPay          DECIMAL(12,2)   NULL,
    PaymentMethod   NVARCHAR(50)    NULL,
    PaymentDate     DATE            NULL,
    GLAccount       NVARCHAR(20)    NULL,
    CostCenter      NVARCHAR(20)    NULL,
    Notes           NVARCHAR(500)   NULL
);
GO

-- ── 5. INVOICES ───────────────────────────────────────────────────────────────
CREATE TABLE dbo.Invoices (
    InvoiceID       INT             NOT NULL PRIMARY KEY,
    VendorID        INT             NOT NULL REFERENCES dbo.Vendors(VendorID),
    InvoiceNumber   NVARCHAR(100)   NOT NULL,
    InvoiceDate     DATE            NOT NULL,
    DueDate         DATE            NULL,
    InvoiceAmount   DECIMAL(14,2)   NOT NULL,
    TaxAmount       DECIMAL(10,2)   NULL DEFAULT 0,
    TotalAmount     DECIMAL(14,2)   NULL,
    Status          NVARCHAR(50)    NULL,
    GLAccount       NVARCHAR(20)    NULL,
    CostCenter      NVARCHAR(20)    NULL,
    ApprovedBy      NVARCHAR(100)   NULL,
    PaymentDate     DATE            NULL,
    PaymentRef      NVARCHAR(100)   NULL,
    Notes           NVARCHAR(500)   NULL
);
GO

-- ── 6. PAYMENTS ───────────────────────────────────────────────────────────────
CREATE TABLE dbo.Payments (
    PaymentID       INT             NOT NULL PRIMARY KEY,
    InvoiceID       INT             NOT NULL REFERENCES dbo.Invoices(InvoiceID),
    VendorID        INT             NOT NULL REFERENCES dbo.Vendors(VendorID),
    PaymentDate     DATE            NOT NULL,
    PaymentAmount   DECIMAL(14,2)   NOT NULL,
    PaymentMethod   NVARCHAR(50)    NULL,
    PaymentRef      NVARCHAR(100)   NULL,
    BankAccount     NVARCHAR(50)    NULL,
    ClearedDate     DATE            NULL,
    GLAccount       NVARCHAR(20)    NULL,
    Notes           NVARCHAR(500)   NULL
);
GO

PRINT 'Schema created successfully in ERP_TARGET.';
GO
