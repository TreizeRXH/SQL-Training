/*
"I need to understand our SaaS spend exposure. Can you pull together what we're spending on software subscriptions across all three companies 
— both on cards and through bills — and flag anything that looks like it might be getting paid twice through different channels?"

--rename transaction table to transactions first to avoid reserved function call problem:
--EXEC sp_rename 'dbo.Transaction', 'Transactions';

requirements translated:
need: spend on software subscriptions
scope:  across all 3 companies (found in company table)
products: Cards and bills
flag anything getting paid twice through different channels
*/


--select company_id, Company_name, tax_id, plan_tier, *
--from Company
/*
company_id				Company_name			tax_id			plan_tier
1						Acme Corp				12-3456789		Enterprise
2						NovaTech Solutions		98-7654321		Plus
3						Bright Horizons Media	55-1234567		Free
*/


--select * from Card



--select distinct category, * from transactions
-- SaaS/Software mcc_code = 7372

-- now pull just SaaS software data
--select * from Transactions where mcc_code = 7372;

--select * from MerchantCategory;
/*
mcc_code	category_name		parent_category
7372		SaaS / Software		Technology



select * from Transactions where mcc_code = 7372
 select * from merchantcategory
 select * from Vendor where mcc_code = 7372
 select * from bill
*/

with spend as (
	select
		t.vendor_id,
		v.vendor_name,
		sum(usd_amount) as Total_amount,
		'Cards' as Income_Source
	from Transactions t
	join MerchantCategory mc 
		on mc.mcc_code = t.mcc_code
	join Vendor v 
		on v.vendor_id = t.vendor_id
	where t.mcc_code = '7372'
	group by t.vendor_id, v.vendor_name

	union all

	select 
		b.vendor_id,
		v.vendor_name,
		sum(total_amount) as Total_amount,
		'Bills' as Income_Source
	from Bill b
	join Vendor v 
		on v.vendor_id = b.vendor_id
	where b.vendor_id in (select vendor_id from transactions where mcc_code = '7372' and vendor_id = b.vendor_id)
	group by b.vendor_id, v.vendor_name
	)

--select
--	vendor_id,
--	vendor_name,
--	sum(Total_amount)					as combined_spend,
--	COUNT(Distinct Income_Source)		as channel_count, 
--	case 
--		when count(distinct Income_source) > 1
--			then 'REVIEW - Dual Income Source'
--		else 'OK' 
--	end as FLAG
--from spend
--group by vendor_id, vendor_name
--order by channel_count





SELECT
    vendor_id, 
    vendor_name,
    SUM(CASE WHEN Income_Source = 'Cards' THEN Total_amount END) AS card_spend,
    SUM(CASE WHEN Income_Source = 'Bills' THEN Total_amount END) AS bill_spend,
    SUM(Total_amount)                                            AS combined_spend,
	CASE WHEN 
		SUM(CASE WHEN Income_Source = 'Cards' THEN Total_amount END) = SUM(CASE WHEN Income_Source = 'Bills' THEN Total_amount END)
			THEN 'HIGH RISK - Amounts Match'
		ELSE 'REVIEW - Dual Channel'
	END AS flag
FROM spend
GROUP BY vendor_id, vendor_name
HAVING COUNT(DISTINCT Income_Source) > 1
ORDER BY combined_spend DESC;
/*
vendor_id	vendor_name	card_spend	bill_spend	combined_spend	flag
1	AWS	29450.00	15200.00	44650.00	REVIEW - Dual Channel
2	Salesforce	10800.00	5400.00	16200.00	REVIEW - Dual Channel
7	Google Cloud	4200.00	4200.00	8400.00	HIGH RISK - Amounts Match
8	HubSpot	2800.00	2800.00	5600.00	HIGH RISK - Amounts Match
11	Adobe Creative	1200.00	1200.00	2400.00	HIGH RISK - Amounts Match
*/
