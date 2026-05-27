--check INVOICE errors
/*
Table		Defect Type					Column			Count
Invoices	Negative or zero amount		InvoiceAmount	78
Invoices	Paid with no PaymentDate	PaymentDate		49
*/
select * from stg_invoices

--find negative amounts
select	InvoiceID, 
		VendorID, 
		TRY_cast(InvoiceAmount as decimal(14,2)) as InvoiceAmount, 
		paymentdate
from stg_invoices
where invoiceamount <=0 --this fails as the TRY_cast is trying to compare a decimal to a nvarchar; must place the try_case in the where clause as well

--better query to work with nvarchar conversions
SELECT  InvoiceID,
        VendorID,
		invoiceNumber,
		GLAccount,
		CostCenter,
        TRY_CAST(InvoiceAmount AS DECIMAL(14,2)) AS InvoiceAmount,
        PaymentDate
FROM    dbo.stg_Invoices
WHERE   TRY_CAST(InvoiceAmount AS DECIMAL(14,2)) < 0;

