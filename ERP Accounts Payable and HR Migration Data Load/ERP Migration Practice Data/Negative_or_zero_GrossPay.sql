/**FIND Payroll issues****/

--PayrollRecords	Negative or zero GrossPay	GrossPay	190



select	payrollid,
		employeeID,
		PayPeriodStart,
		PayPeriodEnd,
		PayCode,
		GrossPay,
		PaymentMethod,
		PaymentDate,
		stg_status,
		stg_errorNotes
from stg_payrollRecords
where PayCode IS NULL OR PayCode = ''
   OR PayCode NOT IN ('REG','OT','BONUS','COMM','REIMB','SEVERANCE','PTO','SICK','HOLIDAY','MISC')
   OR GrossPay IS NULL OR GrossPay = ''
   OR TRY_CAST(GrossPay AS DECIMAL(12,2)) <= 0

--   select distinct paycode
--   from stg_payrollRecords
--where PayCode IS NULL OR PayCode = ''
--   OR PayCode NOT IN ('REG','OT','BONUS','COMM','REIMB','SEVERANCE','PTO','SICK','HOLIDAY','MISC')
--   OR GrossPay IS NULL OR GrossPay = ''
--   OR TRY_CAST(GrossPay AS DECIMAL(12,2)) <= 0


 --flag REG, OT, HOLIDAY, SICK, PTO negatives as likely errors
UPDATE dbo.stg_PayrollRecords
SET    stg_Status     = 'REJECTED',
       stg_ErrorNotes = 'Negative GrossPay on ' + PayCode 
                      + ' — likely reversal entry or data error, confirm with Payroll'
WHERE  TRY_CAST(GrossPay AS DECIMAL(12,2)) < 0
  AND  PayCode IN ('REG','OT','HOLIDAY','SICK','PTO');

-- flag BONUS, COMM, REIMB, SEVERANCE, MISC negatives for business review
UPDATE dbo.stg_PayrollRecords
SET    stg_Status     = 'REVIEW',
       stg_ErrorNotes = 'Negative GrossPay on ' + PayCode 
                      + ' — possible legitimate clawback/reversal, requires Payroll sign-off'
WHERE  TRY_CAST(GrossPay AS DECIMAL(12,2)) < 0
  AND  PayCode IN ('BONUS','COMM','REIMB','SEVERANCE','MISC');