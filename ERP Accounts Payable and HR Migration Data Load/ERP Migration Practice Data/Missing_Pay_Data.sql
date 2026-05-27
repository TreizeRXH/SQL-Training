/**********update employees with missing pay data*******/
--PAY RATES
--find those with missing


/**********************check for EEs flagged with paytypes and no corresponding payrates EEs*************************/
select	employeeID as EmployeeID,
		paytype as PayType, 
		annualsalary as PayRate, 
		'MISSING ANNUAL SALARY'	as Issue
from dbo.stg_employees
where paytype = 'Salary'
and annualsalary is null
OR AnnualSalary = ''

UNION ALL
--check hourly EEs
select	employeeID,
		paytype, 
		hourlyrate,
		'MISSING HOURLY RATE'
from stg_employees
where paytype = 'Hourly'
and HourlyRate IS NULL 
OR HourlyRate = ''


/********************find missing hourly pay types***************************/
select	employeeID,
		paytype, 
		annualsalary, 
		hourlyrate		
from stg_employees
where paytype is null
and hourlyrate is not null

/********************find missing salary pay types***************************/
select	employeeID,
		paytype, 
		annualsalary, 
		hourlyrate		
from stg_employees
where paytype is null
and annualsalary is not null

/********************find EEs with no pay data at all (report to client)***************************/
select * from stg_employees where employeeid in
(
select	employeeID
from stg_employees
where paytype is null
)

select EmployeeID,
		FirstName,
		LastName,
		SSN,
		IsActive,
		Department,
		JobTitle,
		CostCenter,
		PayType,
		AnnualSalary,
		HourlyRate,
		'NEEDS REVIEW FROM PAYROLL' as ActionNeeded
FROM dbo.stg_Employees 
WHERE (AnnualSalary IS NULL OR AnnualSalary = '') 
AND (HourlyRate IS NULL OR HourlyRate = '')


--/****update records ****/
--begin tran
--update stg_employees
--set annualsalary = 0.00
--where paytype = 'Salary'
--and annualsalary is null



----begin tran
--update stg_employees
--set hourlyrate = 0.00
--where paytype = 'Hourly'
--and hourlyrate is null



--commit
--rollback