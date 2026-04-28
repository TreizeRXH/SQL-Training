/*

task from CFO: i want to undersand our pbill payment performance.  

Which vendors are we consistently paying late, and what is our total outstanding liability right now across all three companies?"

items to investigate:
1.) Which vendors are we consistently paying late
2.) What is our total outstanding liability right now across all three companies?

*/

--start with Bill table
--select * from bill
--select * from Vendor
--use RampSpendDB

with overdue_bills as (
	select	c.company_id,
			c.company_name,
			b.vendor_id,
			v.vendor_name, 
			b.due_date, 
			b.total_amount, 
			b.status,
			b.paid_date,
			b.paid_amount,
			--DATEDIFF(DAY, b.due_date, GETDATE()) as days_overdue --this does not take into account any payment terms that may not necessarily be overdue yet (will show negative number in results)
			CASE 
				WHEN due_date < CAST(GETDATE() AS DATE) 
					THEN DATEDIFF(DAY, b.due_date, GETDATE())
				ELSE 0 
			END AS days_overdue --addresses issue above about negative results
	from bill b
	JOIN vendor v on b.vendor_id = v.vendor_id
	JOIN Company c on c.company_id = b.company_id
	where status in ('Approved','Pending Approval')
	),


	 late_payments as (
	select	c.company_id,
			c.company_name,
			v.vendor_name, 
			b.due_date, 
			b.total_amount, 
			b.status,
			b.paid_date,
			b.paid_amount,
			--DATEDIFF(DAY, b.due_date, GETDATE()) as days_overdue --this does not take into account any payment terms that may not necessarily be overdue yet (will show negative number in results)
			CASE 
				WHEN paid_date > due_date
					THEN DATEDIFF(DAY, b.due_date, paid_date)
				ELSE 0 
			END AS days_late --addresses issue above about negative results
	from bill b
	JOIN vendor v on b.vendor_id = v.vendor_id
	JOIN Company c on c.company_id = b.company_id
	where status = 'Paid'
	)
-- Outstanding liability
SELECT 
    'OUTSTANDING'        AS payment_status,
    company_name,
    vendor_name,
    due_date,
    total_amount,
    days_overdue         AS days
FROM overdue_bills

UNION ALL

-- Late payments
SELECT
    'LATE PAYMENT',
    company_name,
    vendor_name,
    due_date,
    total_amount,
    days_late
FROM late_payments
WHERE days_late > 0      -- only show actually late ones
