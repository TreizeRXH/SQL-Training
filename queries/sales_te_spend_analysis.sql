/********************************************************
ask: 
whic reps are spending the most on travel and entertainment, and whether any of them are consistently hitting or exceeding their monthly limits"

For this request you'd interpret it as:

Travel → Travel - Air and Travel - Hotel
Entertainment → Food & Dining (client dinners, team meals etc. is the closest equivalent)
********************************************************/
--use RampSpendDB
--EXEC sp_help 'dbo.SpendingLimit';

--select * from SpendingLimit
--select distinct category from Transactions
--select * from Transactions where left(category, 6) = 'Travel' or category = 'Food & Dining'

--select * from Card
--select * from Employee
--select * from [dbo].[SpendingLimit]


--select * from MerchantCategory where parent_category in ('travel','Food & Dining')
--and category_name not in ('Grocery Stores', 'Fast Food')
/*
mcc_code	category_name		parent_category
4111		Transportation		Travel
4411		Airlines			Travel
5411		Grocery Stores		Food & Dining
5812		Restaurants			Food & Dining
5814		Fast Food			Food & Dining
7011		Hotels & Lodging	Travel
*/
--use RampSpendDB
--select * from SpendingLimit

with total_spend as (
select 
	e.employee_id,
	e.first_name,
	e.last_name, 
	'TRAVEL' as category,
	--sum(amount) as total_spend,
	FORMAT(t.transaction_date, 'yyyy-MM') AS spend_month,
	sum(amount) as monthly_spend
from Transactions t
join Card c on c.card_id = t.card_id
join Employee e 
	on e.employee_id = c.employee_id
join Department d 
	on d.department_id = e.department_id 
	and d.department_name = 'Sales'
where t.mcc_code in 
	(select mcc_code 
	from MerchantCategory mc 
	where parent_category in ('travel')
	and category_name not in ('Grocery Stores', 'Fast Food')
	) 
--group by e.employee_id, e.first_name, e.last_name, category, s.limit_amount
GROUP BY e.employee_id, e.first_name, e.last_name, 
         FORMAT(t.transaction_date, 'yyyy-MM'), 
         category
union all 

select 
	e.employee_id,
	e.first_name,
	e.last_name, 
	'FOOD' as category,
	--sum(amount) as total_spend,
	FORMAT(t.transaction_date, 'yyyy-MM') AS spend_month,
	sum(amount) as monthly_spend
from Transactions t
join Card c on c.card_id = t.card_id
join Employee e 
	on e.employee_id = c.employee_id
join Department d 
	on d.department_id = e.department_id 
	and d.department_name = 'Sales'
where t.mcc_code in 
	(select mcc_code 
	from MerchantCategory mc 
	where parent_category in ('Food & Dining')
	and category_name not in ('Grocery Stores', 'Fast Food')
	)
--group by e.employee_id, e.first_name, e.last_name, category, s.limit_amount
GROUP BY e.employee_id, e.first_name, e.last_name, 
         FORMAT(t.transaction_date, 'yyyy-MM'), 
         category
)

, monthly_combined AS (
    SELECT
        employee_id,
        first_name,
        last_name,
        spend_month,
        SUM(monthly_spend) AS combined_monthly_spend
    FROM total_spend
    GROUP BY employee_id, first_name, last_name, spend_month
)




SELECT
    employee_id,
    first_name,
    last_name,
    SUM(combined_monthly_spend)                          AS total_te_spend,
    MAX(combined_monthly_spend)                          AS highest_month,
    COUNT(CASE WHEN flag = 'EXCEEDS MONTHLY ALLOWANCE' THEN 1 END) AS months_over_limit,
    CASE
        WHEN COUNT(CASE WHEN flag = 'EXCEEDS MONTHLY ALLOWANCE' THEN 1 END) >= 2 
             THEN 'HIGH RISK'
        WHEN COUNT(CASE WHEN flag = 'EXCEEDS MONTHLY ALLOWANCE' THEN 1 END) = 1 
             THEN 'REVIEW'
        ELSE 'OK'
    END AS risk_rating
FROM (select 
			employee_id,
			first_name,
			last_name,
			spend_month,
			combined_monthly_spend,
			s.limit_amount,
			case
				when combined_monthly_spend > s.limit_amount then 'EXCEEDS MONTHLY ALLOWANCE'
			ELSE 'No Issues' end as FLAG
		from monthly_combined 
		join SpendingLimit s 
			on s.applies_to_id = employee_id 
			and applies_to = 'Employee' 
			and period = 'Monthly') x
GROUP BY  employee_id, first_name, last_name
order BY months_over_limit DESC, total_te_spend DESC; 


/*
	-- Sanity check all employees in Sales
	select * from Department where department_name = 'Sales'

	department_id	company_id	cost_center_id	department_name	head_employee_id
2	1	2	Sales	2
15	2	15	Sales	NULL


--find all employees in sales who have card spending
	
	select * from Transactions t
join Card c on c.card_id = t.card_id
join Employee e 
	on e.employee_id = c.employee_id
	where e.employee_id in (select employee_id from Employee where department_id in (2,15) and dbo.employee.role = 'Employee')
	and t.mcc_code in 
	(select mcc_code 
	from MerchantCategory mc 
	where parent_category in ('travel','Food & Dining')
	and category_name not in ('Grocery Stores', 'Fast Food')
	)
*/

