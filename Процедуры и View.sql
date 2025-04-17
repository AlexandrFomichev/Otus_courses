USE [MyStore]
GO

/****** Object:  StoredProcedure [fact].[delivery_to_store_insert]    Script Date: 17.04.2025 21:04:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---Процедура для наполнения магазинов поставкой
CREATE procedure [fact].[delivery_to_store_insert] as
begin

declare @current_fullnest numeric(10,2);
declare @current_store_id int;
declare @current_date date;


set @current_store_id=(select max(store_id) from [MyStore].[fact].[Current_Deliveriy_to_store] );
set @current_date=(select max(cast(Delivery_date_time as date)) from [MyStore].[fact].[Current_Deliveriy_to_store] );


begin transaction [apply_delivery]

delete from fact.current_store_fullnest
where store_id=@current_store_id;


insert into fact.current_store_fullnest([store_id], [Fullnest_area])
select  ss.store_id, sum(i.item_weight) 
from dict.stores ss
  left join [fact].[Store_rests] s on s.store_id=ss.store_id and s.rest_date=@current_date
  left join [MyStore].[dict].[items] i on i.item_id=s.item_id
  where 1=1 --(select max(ss.rest_date) from [MyStore].[fact].[Store_rests]  ss)
  and ss.store_id=@current_store_id
  group by ss.store_id

declare @current_delivery int;
set @current_delivery=(select max(delivery_id) from [MyStore].[fact].[Current_Deliveriy_to_store]);
 
insert into [fact].[Deliveriy_to_store] ([Delivery_id]
      ,[Delivery_date_time]
      ,[Delivery_date]
      ,[supplier_id]
      ,[store_id]
      ,[item_id]
      ,[item_cost])
SELECT [Delivery_id]
      ,[Delivery_date_time]
	  , cast([Delivery_date_time] as date) [Delivery_date]
      ,[supplier_id]
      ,[store_id]
      ,[item_id]
      ,[item_cost]
  FROM (
		SELECT [Delivery_id]
      ,[Delivery_date_time]
	  , cast([Delivery_date_time] as date) [Delivery_date]
      ,[supplier_id]
      ,d.[store_id]
      ,d.[item_id]
      ,d.[item_cost]
	  , s.trade_area
	  , coalesce(f.[Fullnest_area], 0) [Fullnest_area]
	  ,sum(i.item_weight) over (order by d.[item_id] rows between unbounded preceding and current row) cummulated_Fullnest
  FROM [MyStore].[fact].[Current_Deliveriy_to_store] d
  join [MyStore].[dict].[items] i on i.item_id=d.item_id 
  join [MyStore].[dict].[stores] s on s.store_id=d.store_id
  left join fact.current_store_fullnest f on f.store_id=d.store_id

		)  aa
		where trade_area>=[Fullnest_area]+cummulated_Fullnest
		;



truncate table [MyStore].[fact].[Current_Deliveriy_to_store];

insert into [MyStore].fact.Store_rests([store_id]
      ,[delivery_id]
      ,[item_id]
      ,[rest_date]
      ,[item_price])
select [store_id]
      ,[delivery_id]
      ,d.[item_id]
      ,d.Delivery_date [rest_date]
      ,i.[item_price_start] [item_price]
from [MyStore].[fact].[Deliveriy_to_store] d
join [MyStore].[dict].[items] i on i.item_id=d.item_id 
where d.Delivery_id=@current_delivery



delete from fact.current_store_fullnest
where store_id=@current_store_id;



insert into fact.current_store_fullnest([store_id], [Fullnest_area])
select  ss.store_id, sum(i.item_weight) 
from dict.stores ss
  left join [fact].[Store_rests] s on s.store_id=ss.store_id and s.rest_date=@current_date
  left join [MyStore].[dict].[items] i on i.item_id=s.item_id
  where 1=1 --(select max(ss.rest_date) from [MyStore].[fact].[Store_rests]  ss)
  and ss.store_id=@current_store_id
  group by ss.store_id
  ;
commit transaction [apply_delivery];

end;


GO




---Процедура для расширения календаря
CREATE PROCEDURE   [dbo].[set_calendar](@date_from date, @date_to date)
as
begin
SET NOCOUNT ON;
delete from  [dict].[Calendar]
where [Report_DT] between @date_from and @date_to;

declare @cur_dt as date;
set @cur_dt=@date_from;

while @cur_dt<=@date_to 
		begin

		insert into  [dict].[Calendar]([Report_DT]
			  ,[Week_Day_nm]
			  ,[DayOfWeek]
			  ,[DayOfMonth]
			  ,[DayOfYear]
			  ,[PreviousDay]
			  ,[NextDay]
			  ,[WeekOfYear]
			  ,[Month]
			  ,[MonthOfYear]
			  ,[QuarterOfYear]
			  ,[Year]
			  ,[IsWeekend])

		select @cur_dt [Report_DT], DATENAME(weekday, @cur_dt) [week_day_nm]
		, DATEPART ( dw , @cur_dt )  [day_of_week]
		, DAY(@cur_dt) [day_of_month]
		, DATEPART ( y , @cur_dt )  [day_of_year]
		, cast(dateadd(day, -1,@cur_dt) as date) [PreviousDay]
		, cast(dateadd(day, -2,@cur_dt) as date) [NextDay]
		, DATEPART(week,@cur_dt) [week_of_year]
		, DATENAME(month, @cur_dt)  [month]
		, DATEPART ( mm , @cur_dt ) [month_of_year]
		, DATEPART ( qq , @cur_dt ) [quater_of_year]
		, DATEPART ( yyyy , @cur_dt ) [year]
		, case when DATENAME(weekday,@cur_dt)  in ('суббота','воскресенье') then 1 else 0 end is_weekend;

		set @cur_dt=dateadd(day, 1, @cur_dt);
		end;

end;
GO




---Процедура для проведения транзакций (покупок товаров)

CREATE procedure [fact].[Cash_transactions_insert] as
begin

--declare @current_fullnest numeric(10,2);
declare @current_date date;
declare @store_id int;

set @current_date=(select max([Operation_date]) from [fact].[Current_Cash_transactions]);
set @store_id=(select max(store_id) from [fact].[Current_Cash_transactions]);



update fact.Current_Cash_transactions  set discount_card_id =r.discount_card_id, sale_price=tr.sale_price*(1-dp.discount_value)

from  [fact].[current_receipts] r
join dict.anket_discount_cards dc on r.discount_card_id=dc.discount_card_id
join dict.discount_cards_types dp on dp.discount_card_type_id=dc.discount_card_type_id
join dict.items i on i.item_id=r.item_id
join fact.Current_Cash_transactions tr on tr.Operation_date=r.Report_DT and tr.item_id=r.item_id and tr.store_id=r.store_id
where r.discount_card_id is not null
;

begin transaction [apply_tran]
--заполняем продажи
insert into [fact].[Cash_transactions] ([cash_transaction_id]
      ,[store_id]
      ,[transaction_type_id]
      ,[Operator_id]
      ,[Operation_date_time]
      ,[Operation_date]
      ,[discount_card_id]
      ,[item_id]
      ,[item_price]
      ,[Promotional_Campaign_id]
      ,[sale_price])
select cast(concat(store_id, item_id) as int)
, [store_id]
, [transaction_type_id]
, [Operator_id]
, [Operation_date_time]
, [Operation_date]
, [discount_card_id]
, [item_id]
, [item_price]
, [Promotional_Campaign_id]
, [sale_price]
from  [fact].[Current_Cash_transactions];



--корректируем остатки на проданные товары
delete s from [fact].[Store_rests] s
where exists (select [store_id], [item_id], [Operation_date] from [fact].[Current_Cash_transactions] c
			where s.[store_id]=c.store_id and s.item_id=c.item_id and s.rest_date=c.Operation_date);


truncate table [fact].[Current_Cash_transactions];


--Актуализируем наполненность магазинов
truncate table fact.current_store_fullnest;
insert into fact.current_store_fullnest([store_id], [Fullnest_area])
select  store_id, sum(i.item_weight) 
from [fact].[Store_rests] s
  join [MyStore].[dict].[items] i on i.item_id=s.item_id
  where s.rest_date=@current_date
  group by store_id


insert into [MyStore].[fact].[Store_visitors]([store_id],[Report_DT],[visitors_count])
SELECT [store_id]
      ,[Report_DT]
      ,sum([visit_fact])
  FROM [MyStore].[fact].[Current_Store_visitors]
  group by [store_id]
      ,[Report_DT];

truncate table [MyStore].[fact].[Current_Store_visitors];


--Заполняем чеки
insert into fact.receipts([receipt_no]
      ,[store_id]
      ,[Report_DT]
      ,[item_id]
      ,[Transactions_type_id]
      ,[discount_card_id])
select [receipt_no]
      ,[store_id]
      ,[Report_DT]
      ,[item_id]
      ,[Transactions_type_id]
      ,[discount_card_id] from fact.current_receipts;


truncate table fact.current_receipts;


--Переносим остаток товара на следующий день
insert into [fact].[Store_rests]([store_id]
      ,[delivery_id]
      ,[item_id]
      ,[rest_date]
      ,[item_price])
select [store_id]
      ,[delivery_id]
      ,[item_id]
      ,dateadd(day, 1, @current_date)
      ,[item_price] from [fact].[Store_rests]
		where [rest_date]=@current_date
		and store_id=@store_id;

commit transaction [apply_tran];

end;


GO



-----------------------ВЬЮ ДЛЯ КУБА------------------------
CREATE view [cb_rpt].[vf_sales] as
select c.Operation_date [Report_DT]
, c.store_id, i.item_group_id, i.item_cost, c.transaction_type_id, c.item_price, c.sale_price, i.item_price_start, i.item_supplier_id, i.item_weight
, r.receipt_no, r.discount_card_id, i.item_id
, d.Delivery_date
from fact.Cash_transactions c
join dict.items i on i.item_id=c.item_id
join fact.receipts r on r.item_id=c.item_id 
	and r.Report_DT=c.Operation_date 
	and r.store_id=c.store_id
left join fact.Deliveriy_to_store d on d.item_id=i.item_id

GO


CREATE view [cb_rpt].[vf_rests] as
select c.rest_date [Report_DT]
, c.store_id, i.item_group_id, i.item_cost,  c.item_price, i.item_price_start, i.item_supplier_id, i.item_weight
, i.item_id
, c.item_price rest_price
, d.Delivery_date
, i.item_weight/st.trade_area item_weight_part
from fact.Store_rests c
join dict.items i on i.item_id=c.item_id
join dict.stores st on st.store_id=c.store_id
left join fact.Deliveriy_to_store d on d.item_id=i.item_id

GO

create view [cb_rpt].[vf_deliveries_periods] as
select r.Report_DT, r.Month, r.QuarterOfYear, r.MonthOfYear, r.Year
from [dict].[Calendar] r
GO

create view [cb_rpt].[vf_deliveries] as
select r.Delivery_date, r.item_id, r.store_id, r.supplier_id, r.item_cost
from [fact].[Deliveriy_to_store] r
GO

CREATE view [cb_rpt].[vf_visitors] as
select c.store_id, c.Report_DT, c.visitors_count
from fact.Store_visitors c


GO

