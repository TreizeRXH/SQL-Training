/***********Negative or zero amount - Payment Amount***************/


select * 
FROM dbo.stg_Payments 
WHERE TRY_CAST(PaymentAmount AS DECIMAL(14,2)) <= 0