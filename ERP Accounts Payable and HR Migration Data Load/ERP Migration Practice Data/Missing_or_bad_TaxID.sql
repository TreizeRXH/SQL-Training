--Missing or bad TaxID

select * 
FROM dbo.stg_Vendors 
WHERE TaxID IS NULL 
OR TaxID = '' OR TaxID = 'N/A' 
OR TaxID = 'PENDING' 
OR TaxID NOT LIKE '[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'