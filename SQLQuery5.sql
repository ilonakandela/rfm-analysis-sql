--- Imspecting Data
select * from [dbo].[sales_data_sample]



--- Checking unique values
select distinct STATUS from [dbo].[sales_data_sample] --- plot
select distinct YEAR_ID from [dbo].[sales_data_sample]
select distinct PRODUCTLINE from [dbo].[sales_data_sample] --- plot
select distinct COUNTRY from [dbo].[sales_data_sample] --- plot
select distinct DEALSIZE from [dbo].[sales_data_sample] --- plot
select distinct TERRITORY from [dbo].[sales_data_sample] --- plot

--- Analysis
--- Grouping sales by productline
select PRODUCTLINE, sum(cast(sales as float)) Revenue
from [dbo].[sales_data_sample] 
group by PRODUCTLINE
order by 2 desc

--- Grouping sales by year
select YEAR_ID, sum(cast(sales as float)) Revenue
from [dbo].[sales_data_sample] 
group by YEAR_ID
order by 2 desc  --- in 2005 revenue is much less, so why?

select distinct MONTH_ID from [dbo].[sales_data_sample] 
where YEAR_ID = 2005 --- cos company worked only 5 month in 2005

--- Grouping sales by deal size
select DEALSIZE, sum(cast(sales as float)) Revenue
from [dbo].[sales_data_sample] 
group by DEALSIZE
order by 2 desc

--- Best month for sales in 2003, 2004 and profit
select MONTH_ID, sum(cast(sales as float)) Revenue, count(ORDERNUMBER)  Frequency
from [dbo].[sales_data_sample] 
where YEAR_ID = 2003 --- november
--- where YEAR_ID = 2004 --- november
group by MONTH_ID
order by 2 desc

--- and what prosuct was the most buying in november?
select MONTH_ID, PRODUCTLINE, sum(cast(sales as float)) Revenue, count(ORDERNUMBER) Frequency
from [dbo].[sales_data_sample] 
where YEAR_ID = 2003 and MONTH_ID = 11  -- classic cars
--- where YEAR_ID = 2004 and MONTH_ID = 11  -- classic cars
group by MONTH_ID, PRODUCTLINE
order by 3 desc

--- best cuatomer (RFM analysis)
DROP TABLE IF EXISTS #rfm
;with rfm as
(
	select
		CUSTOMERNAME,
		sum(cast(sales as float)) TotalSpend,
		avg(cast(sales as float)) AverangeSpend,
		count(ORDERDATE) Frequency,
		max(cast(ORDERDATE as date)) LastOrderDate,
		(select max(cast(ORDERDATE as date))  from [dbo].[sales_data_sample]) AS MaxOrderDate,
		DATEDIFF(DD, max(cast(ORDERDATE as date)), (select max(cast(ORDERDATE as date))  from [dbo].[sales_data_sample])) Recency
	from [dbo].[sales_data_sample] 
	group by CUSTOMERNAME
),
rfm_calc as 
(
	select r.*,
		NTILE(4) OVER (order by Recency desc) rfm_recency, --- 4 - closer to max order date
		NTILE(4) OVER (order by Frequency) rfm_frequency, --- 4 - more orders
		NTILE(4) OVER (order by AverangeSpend) rfm_monetary --- 4 - more spend
	from rfm r
)
select 
	c.*, rfm_recency+rfm_frequency+rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar) rfm_cell_string
into #rfm
from rfm_calc c

select * from #rfm

select CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary, rfm_recency+rfm_frequency+rfm_monetary
from #rfm

select CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary,
	case
		when rfm_cell > 9 then 'high value customer'
		when 6 < rfm_cell and rfm_cell <= 9 then '3/4 value customer'
		when 3< rfm_cell and rfm_cell <= 6 then '2/4 value customer'
		when rfm_cell <= 3 then 'low value customer'
	end rfm_segment

from #rfm

--- what products are often sold together
--- select * from [dbo].[sales_data_sample] where ORDERNUMBER = 10411
select distinct ORDERNUMBER, stuff(	
	(select ',' + PRODUCTCODE
	from [dbo].[sales_data_sample] p
	where ORDERNUMBER in 
		(
			select ORDERNUMBER
			from (
				select ORDERNUMBER, count(*) rn
				from [dbo].[sales_data_sample]
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			--- where rn = 2
			where rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path('')), 
		1, 1, '') ProductCodes
from [dbo].[sales_data_sample] s
order by 2 desc