
select stg_errorNotes, count(*) as qty
from stg_employees
where stg_status = 'rejected'
group by stg_errornotes 

select * from stg_employees

/* issues with header data to staging table column headers
Delete all staging table data and start again */

TRUNCATE TABLE dbo.stg_Payments;
TRUNCATE TABLE dbo.stg_Invoices;
TRUNCATE TABLE dbo.stg_PayrollRecords;
TRUNCATE TABLE dbo.stg_BenefitElections;
TRUNCATE TABLE dbo.stg_Employees;
TRUNCATE TABLE dbo.stg_Vendors;




SELECT column_name, ordinal_position
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'stg_Employees'
ORDER BY ordinal_position;

SELECT column_name, ordinal_position
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'stg_Vendors'
ORDER BY ordinal_position;

SELECT column_name, ordinal_position
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'stg_BenefitElections'
ORDER BY ordinal_position;

SELECT column_name, ordinal_position
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'stg_PayrollRecords'
ORDER BY ordinal_position;

SELECT column_name, ordinal_position
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'stg_Invoices'
ORDER BY ordinal_position;

SELECT column_name, ordinal_position
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'stg_Payments'
ORDER BY ordinal_position;