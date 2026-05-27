--select * from stg_vendors

with vendor_dups as (
select	VendorID,
		VendorName,
		TaxID,
		IsActive,

		AddressLine1, 
		City,
		StateCode,
		Zipcode,
		ROW_NUMBER() over (partition by VendorName
		order by VendorName) as DuplicateRank,
		COUNT(*) OVER (
            PARTITION BY LTRIM(RTRIM(UPPER(VendorName)))
        ) AS TotalInGroup
from Stg_vendors
)

select * from vendor_dups where TotalInGroup > 1

/*************client instructions*************/
--We've reviewed all five vendor groups. Here's our direction:

--Acme YICC Corp — VendorID 47 is the correct record. Merge 1 and 5 into 47. Use TaxID 45-1962308.
begin tran
delete stg_vendors
where vendorID in (1,5)

--check
select * from stg_vendors where vendorname = 'Acme YICC Corp'


--Global WPUS LLC — VendorID 124 is correct. Merge 68 and 58 into 124. Use TaxID 57-4926181.
begin tran
delete stg_vendors
where vendorID in (68,58)

--check
select * from stg_vendors where vendorname = 'Global WPUS LLC'

--National SBFH Services — VendorID 244 is correct. Merge 230 and 285 into 244. Use TaxID 52-8575505.
--check
select * from stg_vendors where vendorname = 'National SBFH Services'
/*
VendorID	VendorName	VendorType	TaxID
230	National SBFH Services	Staffing Agency	97-7377917
244	NATIONAL SBFH SERVICES	Supplier	52-8575505
285	national sbfh services	Consultant	28-7332741
*/


begin tran
delete stg_vendors
where vendorID in (230,285)

--recheck
select * from stg_vendors where vendorname = 'National SBFH Services'

--Premier NZJO Inc — VendorID 134 is correct. Merge 127 and 158 into 134. Use TaxID 51-7066680. Note: VendorID 141 ("Premier  NZJO  Inc" with extra spaces) also appears to be a duplicate — please merge that one too.
--check
select * from stg_vendors where vendorname = 'Premier NZJO Inc'

begin tran
delete stg_vendors
where vendorID in (127,158)

--recheck
select * from stg_vendors where vendorname = 'Premier NZJO Inc'

--United VQWP Group — VendorID 161 is correct (active). VendorID 174 is marked inactive — that is correct, it was a legacy record. VendorID 212 should be merged into 161. Use TaxID 37-1189536.
select * from stg_vendors where vendorname = 'United VQWP Group'
/*
VendorID	VendorName	VendorType	TaxID
161	United VQWP Group	Consultant	37-1189536
174	UNITED VQWP GROUP	Staffing Agency	67-6897466
212	united vqwp group	Supplier	23-6428072
*/
begin tran
delete stg_vendors
where vendorID in (212)

--recheck
select * from stg_vendors where vendorname = 'United VQWP Group'

--rollback
--commit