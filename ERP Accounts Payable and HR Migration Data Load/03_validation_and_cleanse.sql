-- ============================================================
--  VALIDATION & CLEANSE  (SQL Server)
--  Run after loading Excel data into stg_ tables.
--
--  stg_Status values:
--    PENDING  — not yet evaluated
--    CLEAN    — passed all checks, ready to post
--    REVIEW   — possible legitimate data, requires business sign-off
--    REJECTED — confirmed defect, do not post
--
--  Workflow:
--    STEP 1  — Defect scorecard  (how bad is it?)
--    STEP 2  — Row-level defect report  (what exactly is wrong?)
--    STEP 3  — Cleanse  (fix what can be fixed automatically)
--    STEP 4  — Re-validate  (confirm defect count dropped to 0)
--    STEP 5  — Post to production  (INSERT into live tables)
--    STEP 6  — Reconciliation  (source vs target row counts)
-- ============================================================

USE ERP_TARGET;
GO

-- ════════════════════════════════════════════════════════════════
-- STEP 1 — DEFECT SCORECARD
-- Run this first. Gives you a summary to open your status call with.
-- Target: every number should be 0 before you run Step 5.
-- ════════════════════════════════════════════════════════════════

SELECT 'VENDORS' AS [Table], '—' AS [Defect Type],
       '—' AS [Column], 0 AS [Count]
WHERE 1 = 0

UNION ALL SELECT 'Vendors', 'Missing VendorID',          'VendorID',      COUNT(*) FROM dbo.stg_Vendors WHERE VendorID IS NULL OR VendorID = ''
UNION ALL SELECT 'Vendors', 'Missing VendorName',        'VendorName',    COUNT(*) FROM dbo.stg_Vendors WHERE VendorName IS NULL OR VendorName = ''
UNION ALL SELECT 'Vendors', 'Missing or bad TaxID',      'TaxID',         COUNT(*) FROM dbo.stg_Vendors WHERE TaxID IS NULL OR TaxID = '' OR TaxID = 'N/A' OR TaxID = 'PENDING' OR TaxID NOT LIKE '[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
UNION ALL SELECT 'Vendors', 'Missing IsActive flag',     'IsActive',      COUNT(*) FROM dbo.stg_Vendors WHERE IsActive IS NULL OR IsActive = ''
UNION ALL SELECT 'Vendors', 'Missing bank account',      'BankAccountNum',COUNT(*) FROM dbo.stg_Vendors WHERE (IsActive = 'Y') AND (BankAccountNum IS NULL OR BankAccountNum = '')
UNION ALL SELECT 'Vendors', 'Missing routing number',    'BankRoutingNum',COUNT(*) FROM dbo.stg_Vendors WHERE (IsActive = 'Y') AND (BankRoutingNum IS NULL OR BankRoutingNum = '')
UNION ALL SELECT 'Vendors', 'Duplicate VendorName',      'VendorName',    COUNT(*) FROM (SELECT LTRIM(RTRIM(UPPER(VendorName))) AS n FROM dbo.stg_Vendors GROUP BY LTRIM(RTRIM(UPPER(VendorName))) HAVING COUNT(*) > 1) x

UNION ALL SELECT 'Employees', 'Missing EmployeeID',      'EmployeeID',    COUNT(*) FROM dbo.stg_Employees WHERE EmployeeID IS NULL OR EmployeeID = ''
UNION ALL SELECT 'Employees', 'Missing FirstName',       'FirstName',     COUNT(*) FROM dbo.stg_Employees WHERE FirstName IS NULL OR FirstName = ''
UNION ALL SELECT 'Employees', 'Missing LastName',        'LastName',      COUNT(*) FROM dbo.stg_Employees WHERE LastName IS NULL OR LastName = ''
UNION ALL SELECT 'Employees', 'Missing HireDate',        'HireDate',      COUNT(*) FROM dbo.stg_Employees WHERE HireDate IS NULL OR HireDate = ''
UNION ALL SELECT 'Employees', 'Missing PayType',         'PayType',       COUNT(*) FROM dbo.stg_Employees WHERE PayType IS NULL OR PayType = ''
UNION ALL SELECT 'Employees', 'Missing CostCenter',      'CostCenter',    COUNT(*) FROM dbo.stg_Employees WHERE CostCenter IS NULL OR CostCenter = ''
UNION ALL SELECT 'Employees', 'No salary or hourly rate','AnnualSalary',  COUNT(*) FROM dbo.stg_Employees WHERE (AnnualSalary IS NULL OR AnnualSalary = '') AND (HourlyRate IS NULL OR HourlyRate = '') AND (IsActive = 'Y')
UNION ALL SELECT 'Employees', 'Invalid PayType value',   'PayType',       COUNT(*) FROM dbo.stg_Employees WHERE PayType NOT IN ('Salary','Hourly','Contract','Part-Time') AND PayType IS NOT NULL AND PayType != ''

UNION ALL SELECT 'BenefitElections', 'Missing ElectionID',   'ElectionID',  COUNT(*) FROM dbo.stg_BenefitElections WHERE ElectionID IS NULL OR ElectionID = ''
UNION ALL SELECT 'BenefitElections', 'Missing EmployeeID',   'EmployeeID',  COUNT(*) FROM dbo.stg_BenefitElections WHERE EmployeeID IS NULL OR EmployeeID = ''
UNION ALL SELECT 'BenefitElections', 'Missing BenefitPlan',  'BenefitPlan', COUNT(*) FROM dbo.stg_BenefitElections WHERE BenefitPlan IS NULL OR BenefitPlan = ''
UNION ALL SELECT 'BenefitElections', 'Missing EffectiveDate','EffectiveDate',COUNT(*) FROM dbo.stg_BenefitElections WHERE EffectiveDate IS NULL OR EffectiveDate = ''
UNION ALL SELECT 'BenefitElections', 'Orphaned election',    'EmployeeID',  COUNT(*) FROM dbo.stg_BenefitElections be LEFT JOIN dbo.stg_Employees e ON be.EmployeeID = e.EmployeeID WHERE e.EmployeeID IS NULL

UNION ALL SELECT 'PayrollRecords', 'Missing PayrollID',         'PayrollID',     COUNT(*) FROM dbo.stg_PayrollRecords WHERE PayrollID IS NULL OR PayrollID = ''
UNION ALL SELECT 'PayrollRecords', 'Missing EmployeeID',        'EmployeeID',    COUNT(*) FROM dbo.stg_PayrollRecords WHERE EmployeeID IS NULL OR EmployeeID = ''
UNION ALL SELECT 'PayrollRecords', 'Missing PayPeriodStart',    'PayPeriodStart',COUNT(*) FROM dbo.stg_PayrollRecords WHERE PayPeriodStart IS NULL OR PayPeriodStart = ''
UNION ALL SELECT 'PayrollRecords', 'Missing PayPeriodEnd',      'PayPeriodEnd',  COUNT(*) FROM dbo.stg_PayrollRecords WHERE PayPeriodEnd IS NULL OR PayPeriodEnd = ''
UNION ALL SELECT 'PayrollRecords', 'Missing or invalid PayCode','PayCode',       COUNT(*) FROM dbo.stg_PayrollRecords WHERE PayCode IS NULL OR PayCode = '' OR PayCode NOT IN ('REG','OT','BONUS','COMM','REIMB','SEVERANCE','PTO','SICK','HOLIDAY','MISC')
UNION ALL SELECT 'PayrollRecords', 'Missing GrossPay',          'GrossPay',      COUNT(*) FROM dbo.stg_PayrollRecords WHERE GrossPay IS NULL OR GrossPay = ''
UNION ALL SELECT 'PayrollRecords', 'Negative GrossPay — likely error (REG/OT/HOLIDAY/SICK/PTO)', 'GrossPay', COUNT(*) FROM dbo.stg_PayrollRecords WHERE TRY_CAST(GrossPay AS DECIMAL(12,2)) < 0 AND PayCode IN ('REG','OT','HOLIDAY','SICK','PTO')
UNION ALL SELECT 'PayrollRecords', 'Negative GrossPay — needs business review (BONUS/COMM/REIMB/SEVERANCE/MISC)', 'GrossPay', COUNT(*) FROM dbo.stg_PayrollRecords WHERE TRY_CAST(GrossPay AS DECIMAL(12,2)) < 0 AND PayCode IN ('BONUS','COMM','REIMB','SEVERANCE','MISC')
UNION ALL SELECT 'PayrollRecords', 'Zero GrossPay',             'GrossPay',      COUNT(*) FROM dbo.stg_PayrollRecords WHERE TRY_CAST(GrossPay AS DECIMAL(12,2)) = 0
UNION ALL SELECT 'PayrollRecords', 'NetPay reconciliation variance > $1','NetPay', COUNT(*)
    FROM dbo.stg_PayrollRecords
    WHERE TRY_CAST(NetPay AS DECIMAL(12,2)) IS NOT NULL
      AND ABS(
            TRY_CAST(GrossPay AS DECIMAL(12,2))
            - (ISNULL(TRY_CAST(FederalTax      AS DECIMAL(10,2)),0)
             + ISNULL(TRY_CAST(StateTax        AS DECIMAL(10,2)),0)
             + ISNULL(TRY_CAST(SocialSecurity  AS DECIMAL(10,2)),0)
             + ISNULL(TRY_CAST(Medicare        AS DECIMAL(10,2)),0)
             + ISNULL(TRY_CAST(OtherDeductions AS DECIMAL(10,2)),0))
            - TRY_CAST(NetPay AS DECIMAL(12,2))
          ) > 1.00

UNION ALL SELECT 'Invoices', 'Missing InvoiceID',       'InvoiceID',     COUNT(*) FROM dbo.stg_Invoices WHERE InvoiceID IS NULL OR InvoiceID = ''
UNION ALL SELECT 'Invoices', 'Missing VendorID',        'VendorID',      COUNT(*) FROM dbo.stg_Invoices WHERE VendorID IS NULL OR VendorID = ''
UNION ALL SELECT 'Invoices', 'Missing InvoiceDate',     'InvoiceDate',   COUNT(*) FROM dbo.stg_Invoices WHERE InvoiceDate IS NULL OR InvoiceDate = ''
UNION ALL SELECT 'Invoices', 'Missing InvoiceAmount',   'InvoiceAmount', COUNT(*) FROM dbo.stg_Invoices WHERE InvoiceAmount IS NULL OR InvoiceAmount = ''
UNION ALL SELECT 'Invoices', 'Negative amount — needs business review (possible credit memo)', 'InvoiceAmount', COUNT(*) FROM dbo.stg_Invoices WHERE TRY_CAST(InvoiceAmount AS DECIMAL(14,2)) < 0
UNION ALL SELECT 'Invoices', 'Zero amount',             'InvoiceAmount', COUNT(*) FROM dbo.stg_Invoices WHERE TRY_CAST(InvoiceAmount AS DECIMAL(14,2)) = 0
UNION ALL SELECT 'Invoices', 'Total mismatch > $0.01',  'TotalAmount',   COUNT(*)
    FROM dbo.stg_Invoices
    WHERE TRY_CAST(TotalAmount AS DECIMAL(14,2)) IS NOT NULL
      AND ABS(TRY_CAST(TotalAmount AS DECIMAL(14,2))
            - (TRY_CAST(InvoiceAmount AS DECIMAL(14,2))
             + ISNULL(TRY_CAST(TaxAmount AS DECIMAL(10,2)),0))) > 0.01
UNION ALL SELECT 'Invoices', 'Invalid Status value',    'Status',        COUNT(*) FROM dbo.stg_Invoices WHERE Status NOT IN ('Paid','Pending','Overdue','Disputed','Cancelled','Partially Paid') AND Status IS NOT NULL AND Status != ''
UNION ALL SELECT 'Invoices', 'Paid with no PaymentDate','PaymentDate',   COUNT(*) FROM dbo.stg_Invoices WHERE Status = 'Paid' AND (PaymentDate IS NULL OR PaymentDate = '')

UNION ALL SELECT 'Payments', 'Missing PaymentID',       'PaymentID',     COUNT(*) FROM dbo.stg_Payments WHERE PaymentID IS NULL OR PaymentID = ''
UNION ALL SELECT 'Payments', 'Missing VendorID',        'VendorID',      COUNT(*) FROM dbo.stg_Payments WHERE VendorID IS NULL OR VendorID = ''
UNION ALL SELECT 'Payments', 'Missing PaymentDate',     'PaymentDate',   COUNT(*) FROM dbo.stg_Payments WHERE PaymentDate IS NULL OR PaymentDate = ''
UNION ALL SELECT 'Payments', 'Missing PaymentAmount',   'PaymentAmount', COUNT(*) FROM dbo.stg_Payments WHERE PaymentAmount IS NULL OR PaymentAmount = ''
UNION ALL SELECT 'Payments', 'Negative amount — needs business review', 'PaymentAmount', COUNT(*) FROM dbo.stg_Payments WHERE TRY_CAST(PaymentAmount AS DECIMAL(14,2)) < 0
UNION ALL SELECT 'Payments', 'Zero amount',             'PaymentAmount', COUNT(*) FROM dbo.stg_Payments WHERE TRY_CAST(PaymentAmount AS DECIMAL(14,2)) = 0

ORDER BY [Table], [Defect Type];
GO


-- ════════════════════════════════════════════════════════════════
-- STEP 2 — ROW-LEVEL DEFECT REPORTS
-- ════════════════════════════════════════════════════════════════

-- 2a. Vendors with any critical defect
SELECT
    VendorID, VendorName, TaxID, IsActive, BankAccountNum, BankRoutingNum,
    CASE
        WHEN VendorName IS NULL OR VendorName = ''                              THEN 'Missing VendorName'
        WHEN TaxID IS NULL OR TaxID = '' OR TaxID = 'N/A' OR TaxID = 'PENDING' THEN 'Missing/invalid TaxID'
        WHEN TaxID NOT LIKE '[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'  THEN 'TaxID format invalid'
        WHEN IsActive = 'Y' AND (BankAccountNum IS NULL OR BankAccountNum = '') THEN 'Active vendor missing bank account'
        WHEN IsActive = 'Y' AND (BankRoutingNum IS NULL OR BankRoutingNum = '') THEN 'Active vendor missing routing number'
        ELSE 'Other'
    END AS DefectDescription
FROM dbo.stg_Vendors
WHERE VendorName IS NULL OR VendorName = ''
   OR TaxID IS NULL OR TaxID = '' OR TaxID = 'N/A' OR TaxID = 'PENDING'
   OR TaxID NOT LIKE '[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
   OR (IsActive = 'Y' AND (BankAccountNum IS NULL OR BankAccountNum = ''))
   OR (IsActive = 'Y' AND (BankRoutingNum IS NULL OR BankRoutingNum = ''))
ORDER BY VendorID;
GO

-- 2b. Employees with any critical defect
SELECT
    EmployeeID, FirstName, LastName, HireDate, PayType, CostCenter,
    AnnualSalary, HourlyRate,
    CASE
        WHEN FirstName  IS NULL OR FirstName  = '' THEN 'Missing FirstName'
        WHEN LastName   IS NULL OR LastName   = '' THEN 'Missing LastName'
        WHEN HireDate   IS NULL OR HireDate   = '' THEN 'Missing HireDate'
        WHEN PayType    IS NULL OR PayType    = '' THEN 'Missing PayType'
        WHEN CostCenter IS NULL OR CostCenter = '' THEN 'Missing CostCenter'
        WHEN (AnnualSalary IS NULL OR AnnualSalary = '')
         AND (HourlyRate   IS NULL OR HourlyRate   = '')
         AND IsActive = 'Y'                        THEN 'No salary or hourly rate'
        ELSE 'Other'
    END AS DefectDescription
FROM dbo.stg_Employees
WHERE FirstName  IS NULL OR FirstName  = ''
   OR LastName   IS NULL OR LastName   = ''
   OR HireDate   IS NULL OR HireDate   = ''
   OR PayType    IS NULL OR PayType    = ''
   OR CostCenter IS NULL OR CostCenter = ''
   OR ((AnnualSalary IS NULL OR AnnualSalary = '')
   AND (HourlyRate   IS NULL OR HourlyRate   = '')
   AND IsActive = 'Y')
ORDER BY EmployeeID;
GO

-- 2c. Payroll — negative gross pay broken out by pay code bucket
SELECT
    PayrollID, EmployeeID, PayCode,
    TRY_CAST(GrossPay AS DECIMAL(12,2)) AS GrossPay,
    CASE
        WHEN PayCode IN ('REG','OT','HOLIDAY','SICK','PTO')
            THEN 'REJECT — negative not valid for this pay code'
        WHEN PayCode IN ('BONUS','COMM','REIMB','SEVERANCE','MISC')
            THEN 'REVIEW — possible clawback/reversal, needs Payroll sign-off'
        ELSE 'REVIEW — unknown pay code context'
    END AS RecommendedAction
FROM dbo.stg_PayrollRecords
WHERE TRY_CAST(GrossPay AS DECIMAL(12,2)) < 0
ORDER BY PayCode, PayrollID;
GO

-- 2d. Payroll records with invalid pay code
SELECT
    PayrollID, EmployeeID, PayCode,
    TRY_CAST(GrossPay AS DECIMAL(12,2)) AS GrossPay
FROM dbo.stg_PayrollRecords
WHERE PayCode IS NULL OR PayCode = ''
   OR PayCode NOT IN ('REG','OT','BONUS','COMM','REIMB','SEVERANCE','PTO','SICK','HOLIDAY','MISC')
ORDER BY PayrollID;
GO

-- 2e. Invoice negatives — all flagged for business review
SELECT
    InvoiceID, VendorID, InvoiceNumber,
    TRY_CAST(InvoiceAmount AS DECIMAL(14,2)) AS InvoiceAmount,
    Status,
    'REVIEW — possible credit memo or reversal, needs AP sign-off' AS RecommendedAction
FROM dbo.stg_Invoices
WHERE TRY_CAST(InvoiceAmount AS DECIMAL(14,2)) < 0
ORDER BY InvoiceID;
GO

-- 2f. Invoice total mismatches
SELECT
    InvoiceID, VendorID, InvoiceNumber,
    TRY_CAST(InvoiceAmount AS DECIMAL(14,2))                           AS InvoiceAmount,
    ISNULL(TRY_CAST(TaxAmount AS DECIMAL(10,2)),0)                     AS TaxAmount,
    TRY_CAST(InvoiceAmount AS DECIMAL(14,2))
        + ISNULL(TRY_CAST(TaxAmount AS DECIMAL(10,2)),0)               AS ExpectedTotal,
    TRY_CAST(TotalAmount AS DECIMAL(14,2))                             AS TotalAmount,
    ABS(TRY_CAST(TotalAmount AS DECIMAL(14,2))
        - (TRY_CAST(InvoiceAmount AS DECIMAL(14,2))
         + ISNULL(TRY_CAST(TaxAmount AS DECIMAL(10,2)),0)))            AS Variance
FROM dbo.stg_Invoices
WHERE TRY_CAST(TotalAmount AS DECIMAL(14,2)) IS NOT NULL
  AND ABS(TRY_CAST(TotalAmount AS DECIMAL(14,2))
        - (TRY_CAST(InvoiceAmount AS DECIMAL(14,2))
         + ISNULL(TRY_CAST(TaxAmount AS DECIMAL(10,2)),0))) > 0.01
ORDER BY Variance DESC;
GO


-- ════════════════════════════════════════════════════════════════
-- STEP 3 — CLEANSE
-- ════════════════════════════════════════════════════════════════

-- ── Reset all staging statuses before cleansing ───────────────────────────────
UPDATE dbo.stg_Vendors          SET stg_Status = 'PENDING', stg_ErrorNotes = NULL;
UPDATE dbo.stg_Employees        SET stg_Status = 'PENDING', stg_ErrorNotes = NULL;
UPDATE dbo.stg_BenefitElections SET stg_Status = 'PENDING', stg_ErrorNotes = NULL;
UPDATE dbo.stg_PayrollRecords   SET stg_Status = 'PENDING', stg_ErrorNotes = NULL;
UPDATE dbo.stg_Invoices         SET stg_Status = 'PENDING', stg_ErrorNotes = NULL;
UPDATE dbo.stg_Payments         SET stg_Status = 'PENDING', stg_ErrorNotes = NULL;
GO
PRINT 'All staging rows reset to PENDING.';
GO

-- ── VENDORS ───────────────────────────────────────────────────────────────────

-- Fix TaxID: 9 consecutive digits missing dash
UPDATE dbo.stg_Vendors
SET    TaxID = LEFT(TaxID,2) + '-' + SUBSTRING(TaxID,3,7)
WHERE  TaxID LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
  AND  LEN(TaxID) = 9;
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' vendor TaxID dashes inserted.';

-- Fill missing bank account with placeholder
UPDATE dbo.stg_Vendors
SET    BankAccountNum = '000-MIGR-' + RIGHT('0000' + VendorID, 4)
WHERE (BankAccountNum IS NULL OR BankAccountNum = '')
  AND  IsActive = 'Y';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' vendor bank accounts filled with placeholder.';

-- Fill missing routing with placeholder
UPDATE dbo.stg_Vendors
SET    BankRoutingNum = '999999999'
WHERE (BankRoutingNum IS NULL OR BankRoutingNum = '')
  AND  IsActive = 'Y';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' vendor routing numbers filled with placeholder.';

-- Default IsActive where missing
UPDATE dbo.stg_Vendors
SET    IsActive = 'Y'
WHERE  IsActive IS NULL OR IsActive = '';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' vendor IsActive flags defaulted to Y.';

-- REJECT: unresolvable TaxID — client must provide
UPDATE dbo.stg_Vendors
SET    stg_Status     = 'REJECTED',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'TaxID missing or invalid — client must provide'
WHERE  TaxID IS NULL OR TaxID = '' OR TaxID = 'N/A' OR TaxID = 'PENDING'
   OR  TaxID NOT LIKE '[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][0-9]';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' vendor rows REJECTED — invalid TaxID.';

-- REJECT: missing vendor name
UPDATE dbo.stg_Vendors
SET    stg_Status     = 'REJECTED',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','') + 'Missing VendorName'
WHERE (VendorName IS NULL OR VendorName = '')
  AND  stg_Status != 'REJECTED';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' vendor rows REJECTED — missing VendorName.';

-- CLEAN: everything still PENDING passes
UPDATE dbo.stg_Vendors
SET    stg_Status = 'CLEAN'
WHERE  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' vendor rows marked CLEAN.';
GO

-- ── EMPLOYEES ─────────────────────────────────────────────────────────────────

-- Default StandardHours where missing
UPDATE dbo.stg_Employees
SET    StandardHours = '40'
WHERE  StandardHours IS NULL OR StandardHours = '';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' employee standard hours defaulted to 40.';

-- Default IsActive where missing
UPDATE dbo.stg_Employees
SET    IsActive = 'Y'
WHERE  IsActive IS NULL OR IsActive = '';

-- REJECT: missing required fields
UPDATE dbo.stg_Employees
SET    stg_Status     = 'REJECTED',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + CASE WHEN FirstName  IS NULL OR FirstName  = '' THEN 'Missing FirstName | '  ELSE '' END
                      + CASE WHEN LastName   IS NULL OR LastName   = '' THEN 'Missing LastName | '   ELSE '' END
                      + CASE WHEN HireDate   IS NULL OR HireDate   = '' THEN 'Missing HireDate | '   ELSE '' END
                      + CASE WHEN PayType    IS NULL OR PayType    = '' THEN 'Missing PayType | '    ELSE '' END
                      + CASE WHEN CostCenter IS NULL OR CostCenter = '' THEN 'Missing CostCenter | ' ELSE '' END
WHERE  FirstName  IS NULL OR FirstName  = ''
   OR  LastName   IS NULL OR LastName   = ''
   OR  HireDate   IS NULL OR HireDate   = ''
   OR  PayType    IS NULL OR PayType    = ''
   OR  CostCenter IS NULL OR CostCenter = '';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' employee rows REJECTED — missing required fields.';

-- CLEAN: everything still PENDING passes
UPDATE dbo.stg_Employees
SET    stg_Status = 'CLEAN'
WHERE  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' employee rows marked CLEAN.';
GO

-- ── PAYROLL RECORDS ───────────────────────────────────────────────────────────

-- Default PayCode to REG where missing/invalid — note for client review
UPDATE dbo.stg_PayrollRecords
SET    PayCode        = 'REG',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'PayCode was null/invalid — defaulted to REG, verify with Payroll'
WHERE  PayCode IS NULL OR PayCode = ''
   OR  PayCode NOT IN ('REG','OT','BONUS','COMM','REIMB','SEVERANCE','PTO','SICK','HOLIDAY','MISC');
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' payroll pay codes defaulted to REG.';

-- Recalculate NetPay where variance > $1
UPDATE dbo.stg_PayrollRecords
SET    NetPay         = CAST(
                          TRY_CAST(GrossPay AS DECIMAL(12,2))
                          - (ISNULL(TRY_CAST(FederalTax      AS DECIMAL(10,2)),0)
                           + ISNULL(TRY_CAST(StateTax        AS DECIMAL(10,2)),0)
                           + ISNULL(TRY_CAST(SocialSecurity  AS DECIMAL(10,2)),0)
                           + ISNULL(TRY_CAST(Medicare        AS DECIMAL(10,2)),0)
                           + ISNULL(TRY_CAST(OtherDeductions AS DECIMAL(10,2)),0))
                        AS NVARCHAR(30)),
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'NetPay recalculated from GrossPay minus deductions — verify with Payroll'
WHERE  TRY_CAST(NetPay AS DECIMAL(12,2)) IS NOT NULL
  AND  ABS(
         TRY_CAST(GrossPay AS DECIMAL(12,2))
         - (ISNULL(TRY_CAST(FederalTax      AS DECIMAL(10,2)),0)
          + ISNULL(TRY_CAST(StateTax        AS DECIMAL(10,2)),0)
          + ISNULL(TRY_CAST(SocialSecurity  AS DECIMAL(10,2)),0)
          + ISNULL(TRY_CAST(Medicare        AS DECIMAL(10,2)),0)
          + ISNULL(TRY_CAST(OtherDeductions AS DECIMAL(10,2)),0))
         - TRY_CAST(NetPay AS DECIMAL(12,2))
       ) > 1.00;
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' payroll NetPay values recalculated.';

-- REJECT: negative GrossPay on pay codes where it is never valid
UPDATE dbo.stg_PayrollRecords
SET    stg_Status     = 'REJECTED',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'Negative GrossPay on ' + PayCode
                      + ' — not a valid scenario, likely reversal entry or data error'
WHERE  TRY_CAST(GrossPay AS DECIMAL(12,2)) < 0
  AND  PayCode IN ('REG','OT','HOLIDAY','SICK','PTO');
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' payroll rows REJECTED — negative GrossPay on invalid pay code.';

-- REVIEW: negative GrossPay on pay codes where clawback/reversal is possible
UPDATE dbo.stg_PayrollRecords
SET    stg_Status     = 'REVIEW',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'Negative GrossPay on ' + PayCode
                      + ' — possible clawback or reversal, requires Payroll sign-off before posting'
WHERE  TRY_CAST(GrossPay AS DECIMAL(12,2)) < 0
  AND  PayCode IN ('BONUS','COMM','REIMB','SEVERANCE','MISC')
  AND  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' payroll rows flagged REVIEW — negative GrossPay needs Payroll sign-off.';

-- REJECT: missing or zero GrossPay
UPDATE dbo.stg_PayrollRecords
SET    stg_Status     = 'REJECTED',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'GrossPay missing or zero — cannot post'
WHERE (GrossPay IS NULL OR GrossPay = ''
   OR  TRY_CAST(GrossPay AS DECIMAL(12,2)) = 0)
  AND  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' payroll rows REJECTED — missing or zero GrossPay.';

-- CLEAN: everything still PENDING passes
UPDATE dbo.stg_PayrollRecords
SET    stg_Status = 'CLEAN'
WHERE  stg_Status     = 'PENDING'
  AND  EmployeeID    IS NOT NULL AND EmployeeID    != ''
  AND  PayPeriodStart IS NOT NULL AND PayPeriodStart != ''
  AND  PayPeriodEnd   IS NOT NULL AND PayPeriodEnd   != ''
  AND  GrossPay      IS NOT NULL AND GrossPay      != '';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' payroll rows marked CLEAN.';
GO

-- ── INVOICES ──────────────────────────────────────────────────────────────────

-- Recalculate TotalAmount where mismatch > $0.01
UPDATE dbo.stg_Invoices
SET    TotalAmount    = CAST(
                          TRY_CAST(InvoiceAmount AS DECIMAL(14,2))
                          + ISNULL(TRY_CAST(TaxAmount AS DECIMAL(10,2)),0)
                        AS NVARCHAR(30)),
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'TotalAmount recalculated as InvoiceAmount + TaxAmount'
WHERE  TRY_CAST(TotalAmount AS DECIMAL(14,2)) IS NOT NULL
  AND  ABS(TRY_CAST(TotalAmount AS DECIMAL(14,2))
         - (TRY_CAST(InvoiceAmount AS DECIMAL(14,2))
          + ISNULL(TRY_CAST(TaxAmount AS DECIMAL(10,2)),0))) > 0.01;
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' invoice totals recalculated.';

-- REVIEW: negative InvoiceAmount — possible credit memo, needs AP sign-off
UPDATE dbo.stg_Invoices
SET    stg_Status     = 'REVIEW',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'Negative InvoiceAmount — possible credit memo or reversal, requires AP sign-off'
WHERE  TRY_CAST(InvoiceAmount AS DECIMAL(14,2)) < 0
  AND  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' invoice rows flagged REVIEW — negative amount needs AP sign-off.';

-- REJECT: zero or missing InvoiceAmount
UPDATE dbo.stg_Invoices
SET    stg_Status     = 'REJECTED',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'InvoiceAmount missing or zero — cannot post'
WHERE (InvoiceAmount IS NULL OR InvoiceAmount = ''
   OR  TRY_CAST(InvoiceAmount AS DECIMAL(14,2)) = 0)
  AND  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' invoice rows REJECTED — missing or zero InvoiceAmount.';

-- CLEAN: everything still PENDING passes
UPDATE dbo.stg_Invoices
SET    stg_Status = 'CLEAN'
WHERE  stg_Status     = 'PENDING'
  AND  VendorID      IS NOT NULL AND VendorID      != ''
  AND  InvoiceDate   IS NOT NULL AND InvoiceDate   != ''
  AND  InvoiceAmount IS NOT NULL AND InvoiceAmount != '';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' invoice rows marked CLEAN.';
GO

-- ── BENEFIT ELECTIONS ─────────────────────────────────────────────────────────

-- REJECT: missing required fields
UPDATE dbo.stg_BenefitElections
SET    stg_Status     = 'REJECTED',
       stg_ErrorNotes = 'Missing EmployeeID, BenefitPlan, or EffectiveDate'
WHERE  EmployeeID    IS NULL OR EmployeeID    = ''
   OR  BenefitPlan   IS NULL OR BenefitPlan   = ''
   OR  EffectiveDate IS NULL OR EffectiveDate = '';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' benefit election rows REJECTED — missing required fields.';

-- REVIEW: orphaned elections (EmployeeID not found in stg_Employees)
UPDATE dbo.stg_BenefitElections
SET    stg_Status     = 'REVIEW',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'EmployeeID not found in Employees table — possible orphaned record'
WHERE  stg_Status != 'REJECTED'
  AND  EmployeeID NOT IN (SELECT EmployeeID FROM dbo.stg_Employees WHERE EmployeeID IS NOT NULL);
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' benefit election rows flagged REVIEW — orphaned EmployeeID.';

-- CLEAN: everything still PENDING passes
UPDATE dbo.stg_BenefitElections
SET    stg_Status = 'CLEAN'
WHERE  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' benefit election rows marked CLEAN.';
GO

-- ── PAYMENTS ──────────────────────────────────────────────────────────────────

-- REVIEW: negative payment amount — possible refund or reversal
UPDATE dbo.stg_Payments
SET    stg_Status     = 'REVIEW',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'Negative PaymentAmount — possible refund or reversal, requires AP sign-off'
WHERE  TRY_CAST(PaymentAmount AS DECIMAL(14,2)) < 0
  AND  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' payment rows flagged REVIEW — negative amount needs AP sign-off.';

-- REJECT: missing or zero payment amount or date
UPDATE dbo.stg_Payments
SET    stg_Status     = 'REJECTED',
       stg_ErrorNotes = ISNULL(stg_ErrorNotes + ' | ','')
                      + 'PaymentDate missing or PaymentAmount missing/zero — cannot post'
WHERE (PaymentDate   IS NULL OR PaymentDate   = ''
   OR  PaymentAmount IS NULL OR PaymentAmount = ''
   OR  TRY_CAST(PaymentAmount AS DECIMAL(14,2)) = 0)
  AND  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' payment rows REJECTED — missing or zero amount/date.';

-- CLEAN: everything still PENDING passes
UPDATE dbo.stg_Payments
SET    stg_Status = 'CLEAN'
WHERE  stg_Status = 'PENDING';
PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' payment rows marked CLEAN.';
GO


-- ════════════════════════════════════════════════════════════════
-- STEP 4 — RE-VALIDATE
-- ════════════════════════════════════════════════════════════════

-- 4a. Status summary per table — target: no PENDING rows remain
SELECT 'Vendors'          AS [Table], stg_Status, COUNT(*) AS [Rows] FROM dbo.stg_Vendors          GROUP BY stg_Status
UNION ALL
SELECT 'Employees',                   stg_Status, COUNT(*) FROM dbo.stg_Employees                  GROUP BY stg_Status
UNION ALL
SELECT 'BenefitElections',            stg_Status, COUNT(*) FROM dbo.stg_BenefitElections           GROUP BY stg_Status
UNION ALL
SELECT 'PayrollRecords',              stg_Status, COUNT(*) FROM dbo.stg_PayrollRecords             GROUP BY stg_Status
UNION ALL
SELECT 'Invoices',                    stg_Status, COUNT(*) FROM dbo.stg_Invoices                   GROUP BY stg_Status
UNION ALL
SELECT 'Payments',                    stg_Status, COUNT(*) FROM dbo.stg_Payments                   GROUP BY stg_Status
ORDER BY [Table], stg_Status;
GO

-- 4b. REVIEW rows — export this to client for sign-off before proceeding
SELECT 'Vendors' AS [Table], VendorID AS [ID], VendorName AS [Description], stg_ErrorNotes
FROM dbo.stg_Vendors WHERE stg_Status = 'REVIEW'
UNION ALL
SELECT 'Employees', EmployeeID, FirstName + ' ' + ISNULL(LastName,''), stg_ErrorNotes
FROM dbo.stg_Employees WHERE stg_Status = 'REVIEW'
UNION ALL
SELECT 'PayrollRecords', PayrollID, 'EmpID: ' + ISNULL(EmployeeID,'') + ' | PayCode: ' + ISNULL(PayCode,''), stg_ErrorNotes
FROM dbo.stg_PayrollRecords WHERE stg_Status = 'REVIEW'
UNION ALL
SELECT 'Invoices', InvoiceID, 'InvNum: ' + ISNULL(InvoiceNumber,'') + ' | Vendor: ' + ISNULL(VendorID,''), stg_ErrorNotes
FROM dbo.stg_Invoices WHERE stg_Status = 'REVIEW'
UNION ALL
SELECT 'Payments', PaymentID, 'VendorID: ' + ISNULL(VendorID,''), stg_ErrorNotes
FROM dbo.stg_Payments WHERE stg_Status = 'REVIEW'
ORDER BY [Table], [ID];
GO

-- 4c. REJECTED rows — these will not post; document for client follow-up
SELECT 'Vendors' AS [Table], VendorID AS [ID], VendorName AS [Description], stg_ErrorNotes
FROM dbo.stg_Vendors WHERE stg_Status = 'REJECTED'
UNION ALL
SELECT 'Employees', EmployeeID, FirstName + ' ' + ISNULL(LastName,''), stg_ErrorNotes
FROM dbo.stg_Employees WHERE stg_Status = 'REJECTED'
UNION ALL
SELECT 'PayrollRecords', PayrollID, 'EmpID: ' + ISNULL(EmployeeID,'') + ' | PayCode: ' + ISNULL(PayCode,''), stg_ErrorNotes
FROM dbo.stg_PayrollRecords WHERE stg_Status = 'REJECTED'
UNION ALL
SELECT 'Invoices', InvoiceID, 'InvNum: ' + ISNULL(InvoiceNumber,'') + ' | Vendor: ' + ISNULL(VendorID,''), stg_ErrorNotes
FROM dbo.stg_Invoices WHERE stg_Status = 'REJECTED'
UNION ALL
SELECT 'Payments', PaymentID, 'VendorID: ' + ISNULL(VendorID,''), stg_ErrorNotes
FROM dbo.stg_Payments WHERE stg_Status = 'REJECTED'
ORDER BY [Table], [ID];
GO


-- ════════════════════════════════════════════════════════════════
-- STEP 5 — POST TO PRODUCTION
-- Only CLEAN rows move forward.
-- REVIEW rows stay in staging until client provides sign-off.
-- Run each block separately and confirm row counts before next.
-- ════════════════════════════════════════════════════════════════

-- 5a. Vendors
INSERT INTO dbo.Vendors (
    VendorID, VendorName, VendorType, TaxID, IsActive,
    AddressLine1, AddressLine2, City, StateCode, ZipCode,
    Phone, Email, PaymentTerms, PreferredPayMethod,
    BankAccountNum, BankRoutingNum, CreatedDate, LastModified, Notes)
SELECT
    TRY_CAST(VendorID AS INT),
    VendorName, VendorType, TaxID,
    CASE WHEN UPPER(IsActive) = 'Y' THEN 1 ELSE 0 END,
    AddressLine1, AddressLine2, City, LEFT(StateCode,2), ZipCode,
    Phone, Email, PaymentTerms, PreferredPayMethod,
    BankAccountNum, BankRoutingNum,
    TRY_CAST(CreatedDate AS DATE),
    TRY_CAST(LastModified AS DATE),
    Notes
FROM dbo.stg_Vendors
WHERE stg_Status = 'CLEAN';
PRINT 'Vendors posted: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- 5b. Employees
INSERT INTO dbo.Employees (
    EmployeeID, FirstName, LastName, SSN, DateOfBirth,
    HireDate, TerminationDate, IsActive, Department, JobTitle,
    ManagerID, CostCenter, PayType, AnnualSalary, HourlyRate,
    StandardHours, StateCode, Email, Phone, CreatedDate, LastModified)
SELECT
    TRY_CAST(EmployeeID AS INT),
    FirstName, LastName, SSN,
    TRY_CAST(DateOfBirth AS DATE),
    TRY_CAST(HireDate AS DATE),
    TRY_CAST(TerminationDate AS DATE),
    CASE WHEN UPPER(IsActive) = 'Y' THEN 1 ELSE 0 END,
    Department, JobTitle,
    TRY_CAST(ManagerID AS INT),
    CostCenter, PayType,
    TRY_CAST(AnnualSalary AS DECIMAL(12,2)),
    TRY_CAST(HourlyRate AS DECIMAL(8,2)),
    TRY_CAST(StandardHours AS DECIMAL(5,2)),
    LEFT(StateCode,2),
    Email, Phone,
    TRY_CAST(CreatedDate AS DATE),
    TRY_CAST(LastModified AS DATE)
FROM dbo.stg_Employees
WHERE stg_Status = 'CLEAN';
PRINT 'Employees posted: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- 5c. BenefitElections
INSERT INTO dbo.BenefitElections (
    ElectionID, EmployeeID, BenefitPlan, CoverageLevel,
    EmployeeContrib, EmployerContrib, EffectiveDate, EndDate, IsActive)
SELECT
    TRY_CAST(ElectionID AS INT),
    TRY_CAST(EmployeeID AS INT),
    BenefitPlan, CoverageLevel,
    TRY_CAST(EmployeeContrib AS DECIMAL(10,2)),
    TRY_CAST(EmployerContrib AS DECIMAL(10,2)),
    TRY_CAST(EffectiveDate AS DATE),
    TRY_CAST(EndDate AS DATE),
    CASE WHEN UPPER(IsActive) = 'Y' THEN 1 ELSE 0 END
FROM dbo.stg_BenefitElections
WHERE stg_Status = 'CLEAN'
  AND TRY_CAST(EmployeeID AS INT) IN (SELECT EmployeeID FROM dbo.Employees);
PRINT 'BenefitElections posted: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- 5d. PayrollRecords
INSERT INTO dbo.PayrollRecords (
    PayrollID, EmployeeID, PayPeriodStart, PayPeriodEnd, PayCode,
    GrossPay, FederalTax, StateTax, SocialSecurity, Medicare,
    OtherDeductions, NetPay, PaymentMethod, PaymentDate,
    GLAccount, CostCenter, Notes)
SELECT
    TRY_CAST(PayrollID AS INT),
    TRY_CAST(EmployeeID AS INT),
    TRY_CAST(PayPeriodStart AS DATE),
    TRY_CAST(PayPeriodEnd AS DATE),
    PayCode,
    TRY_CAST(GrossPay AS DECIMAL(12,2)),
    TRY_CAST(FederalTax AS DECIMAL(10,2)),
    TRY_CAST(StateTax AS DECIMAL(10,2)),
    TRY_CAST(SocialSecurity AS DECIMAL(10,2)),
    TRY_CAST(Medicare AS DECIMAL(10,2)),
    TRY_CAST(OtherDeductions AS DECIMAL(10,2)),
    TRY_CAST(NetPay AS DECIMAL(12,2)),
    PaymentMethod,
    TRY_CAST(PaymentDate AS DATE),
    GLAccount, CostCenter, Notes
FROM dbo.stg_PayrollRecords
WHERE stg_Status = 'CLEAN'
  AND TRY_CAST(EmployeeID AS INT) IN (SELECT EmployeeID FROM dbo.Employees);
PRINT 'PayrollRecords posted: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- 5e. Invoices
INSERT INTO dbo.Invoices (
    InvoiceID, VendorID, InvoiceNumber, InvoiceDate, DueDate,
    InvoiceAmount, TaxAmount, TotalAmount, Status,
    GLAccount, CostCenter, ApprovedBy, PaymentDate, PaymentRef, Notes)
SELECT
    TRY_CAST(InvoiceID AS INT),
    TRY_CAST(VendorID AS INT),
    InvoiceNumber,
    TRY_CAST(InvoiceDate AS DATE),
    TRY_CAST(DueDate AS DATE),
    TRY_CAST(InvoiceAmount AS DECIMAL(14,2)),
    TRY_CAST(TaxAmount AS DECIMAL(10,2)),
    TRY_CAST(TotalAmount AS DECIMAL(14,2)),
    Status, GLAccount, CostCenter, ApprovedBy,
    TRY_CAST(PaymentDate AS DATE),
    PaymentRef, Notes
FROM dbo.stg_Invoices
WHERE stg_Status = 'CLEAN'
  AND TRY_CAST(VendorID AS INT) IN (SELECT VendorID FROM dbo.Vendors);
PRINT 'Invoices posted: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO

-- 5f. Payments
INSERT INTO dbo.Payments (
    PaymentID, InvoiceID, VendorID, PaymentDate, PaymentAmount,
    PaymentMethod, PaymentRef, BankAccount, ClearedDate, GLAccount, Notes)
SELECT
    TRY_CAST(PaymentID AS INT),
    TRY_CAST(InvoiceID AS INT),
    TRY_CAST(VendorID AS INT),
    TRY_CAST(PaymentDate AS DATE),
    TRY_CAST(PaymentAmount AS DECIMAL(14,2)),
    PaymentMethod, PaymentRef, BankAccount,
    TRY_CAST(ClearedDate AS DATE),
    GLAccount, Notes
FROM dbo.stg_Payments
WHERE stg_Status = 'CLEAN'
  AND TRY_CAST(VendorID  AS INT) IN (SELECT VendorID  FROM dbo.Vendors)
  AND TRY_CAST(InvoiceID AS INT) IN (SELECT InvoiceID FROM dbo.Invoices);
PRINT 'Payments posted: ' + CAST(@@ROWCOUNT AS VARCHAR);
GO


-- ════════════════════════════════════════════════════════════════
-- STEP 6 — RECONCILIATION
-- CLEAN rows in staging must equal posted rows in production.
-- REVIEW rows are excluded — they are awaiting business sign-off.
-- ════════════════════════════════════════════════════════════════

SELECT
    src.[Table],
    src.CleanRows                                                AS [Staging CLEAN],
    src.ReviewRows                                               AS [Staging REVIEW — pending sign-off],
    src.RejectedRows                                             AS [Staging REJECTED],
    tgt.PostedRows                                               AS [Production Rows],
    src.CleanRows - tgt.PostedRows                               AS [Variance],
    CASE
        WHEN src.CleanRows = tgt.PostedRows THEN 'OK'
        ELSE 'MISMATCH — INVESTIGATE'
    END                                                          AS [Status]
FROM (
    SELECT 'Vendors'         AS [Table],
           SUM(CASE WHEN stg_Status='CLEAN'    THEN 1 ELSE 0 END) AS CleanRows,
           SUM(CASE WHEN stg_Status='REVIEW'   THEN 1 ELSE 0 END) AS ReviewRows,
           SUM(CASE WHEN stg_Status='REJECTED' THEN 1 ELSE 0 END) AS RejectedRows
    FROM dbo.stg_Vendors
    UNION ALL
    SELECT 'Employees',
           SUM(CASE WHEN stg_Status='CLEAN'    THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REVIEW'   THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REJECTED' THEN 1 ELSE 0 END)
    FROM dbo.stg_Employees
    UNION ALL
    SELECT 'BenefitElections',
           SUM(CASE WHEN stg_Status='CLEAN'    THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REVIEW'   THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REJECTED' THEN 1 ELSE 0 END)
    FROM dbo.stg_BenefitElections
    UNION ALL
    SELECT 'PayrollRecords',
           SUM(CASE WHEN stg_Status='CLEAN'    THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REVIEW'   THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REJECTED' THEN 1 ELSE 0 END)
    FROM dbo.stg_PayrollRecords
    UNION ALL
    SELECT 'Invoices',
           SUM(CASE WHEN stg_Status='CLEAN'    THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REVIEW'   THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REJECTED' THEN 1 ELSE 0 END)
    FROM dbo.stg_Invoices
    UNION ALL
    SELECT 'Payments',
           SUM(CASE WHEN stg_Status='CLEAN'    THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REVIEW'   THEN 1 ELSE 0 END),
           SUM(CASE WHEN stg_Status='REJECTED' THEN 1 ELSE 0 END)
    FROM dbo.stg_Payments
) src
JOIN (
    SELECT 'Vendors'          AS [Table], COUNT(*) AS PostedRows FROM dbo.Vendors
    UNION ALL SELECT 'Employees',         COUNT(*) FROM dbo.Employees
    UNION ALL SELECT 'BenefitElections',  COUNT(*) FROM dbo.BenefitElections
    UNION ALL SELECT 'PayrollRecords',    COUNT(*) FROM dbo.PayrollRecords
    UNION ALL SELECT 'Invoices',          COUNT(*) FROM dbo.Invoices
    UNION ALL SELECT 'Payments',          COUNT(*) FROM dbo.Payments
) tgt ON src.[Table] = tgt.[Table]
ORDER BY src.[Table];
GO

PRINT '';
PRINT 'Migration complete.';
PRINT 'Variance column must show OK for all CLEAN rows before sign-off.';
PRINT 'REVIEW rows remain in staging pending business sign-off.';
PRINT 'Share the REJECTED list with the client for remediation and reprocessing.';
GO
