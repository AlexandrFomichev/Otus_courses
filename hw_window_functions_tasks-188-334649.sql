/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "06 - Оконные функции".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters;
/*
1. Сделать расчет суммы продаж нарастающим итогом по месяцам с 2015 года 
(в рамках одного месяца он будет одинаковый, нарастать будет в течение времени выборки).
Выведите: id продажи, название клиента, дату продажи, сумму продажи, сумму нарастающим итогом

Пример:
-------------+----------------------------
Дата продажи | Нарастающий итог по месяцу
-------------+----------------------------
 2015-01-29   | 4801725.31
 2015-01-30	 | 4801725.31
 2015-01-31	 | 4801725.31
 2015-02-01	 | 9626342.98
 2015-02-02	 | 9626342.98
 2015-02-03	 | 9626342.98
Продажи можно взять из таблицы Invoices.
Нарастающий итог должен быть без оконной функции.
*/
--set statistics time, io on

with a as
(
select si.[InvoiceID], c.CustomerName,[InvoiceDate], (il.Quantity*il.UnitPrice) sum_sale
, eomonth([InvoiceDate]) InvoiceMonth
--, sum(aa.month_sale_sum)
from 
[Sales].[Invoices] si
join [Sales].[InvoiceLines] il on il.InvoiceID=si.InvoiceID
join [Sales].[Customers] c on c.CustomerID=si.CustomerID
where [InvoiceDate]>'2015-01-01'
--group by si.[InvoiceID], c.CustomerName,[InvoiceDate], eomonth([InvoiceDate])
), 
b as
(
select eomonth([InvoiceDate]) [InvoiceMonth], SUM(ill.Quantity*ill.UnitPrice) month_sale_sum from [Sales].[Invoices] sii
		join [Sales].[InvoiceLines] ill on ill.InvoiceID=sii.InvoiceID
		where [InvoiceDate]>'2015-01-01'
		group by eomonth([InvoiceDate])
)
select a.InvoiceID, a.CustomerName, a.InvoiceDate,  a.sum_sale, sum(b.month_sale_sum) sum_sale_monthly_cumulative from a
left join b on b.InvoiceMonth<=a.InvoiceMonth
group by a.CustomerName, a.InvoiceDate, a.InvoiceID, a.sum_sale
order by a.InvoiceDate



/*
2. Сделайте расчет суммы нарастающим итогом в предыдущем запросе с помощью оконной функции.
   Сравните производительность запросов 1 и 2 с помощью set statistics time, io on
*/

select si.[InvoiceID], c.CustomerName,[InvoiceDate]
, (il.Quantity*il.UnitPrice) sum_sale
, sum(il.Quantity*il.UnitPrice) over (partition by eomonth([InvoiceDate])) sum_sale_monthly_cumulative
from 
[Sales].[Invoices] si
join [Sales].[InvoiceLines] il on il.InvoiceID=si.InvoiceID
join [Sales].[Customers] c on c.CustomerID=si.CustomerID
where [InvoiceDate]>'2015-01-01'



/*
3. Вывести список 2х самых популярных продуктов (по количеству проданных) 
в каждом месяце за 2016 год (по 2 самых популярных продукта в каждом месяце).
*/

select [InvoiceMonth], [Description], [Description_2]
from (
		select [InvoiceMonth], [Description]
		, month_sale_cnt
		, RANK() over(partition by [InvoiceMonth] order by month_sale_cnt desc) rn
		, LEAD([Description]) over(partition by [InvoiceMonth] order by month_sale_cnt desc) [Description_2]
		from
				(
				select  eomonth([InvoiceDate]) [InvoiceMonth]
				, il.Description
				, sum(il.Quantity) month_sale_cnt
				from 
				[Sales].[Invoices] si
				join [Sales].[InvoiceLines] il on il.InvoiceID=si.InvoiceID
				where si.[InvoiceDate] between '2016-01-01' and '2016-12-31'
				group by eomonth([InvoiceDate])
				, il.Description
				) a
	) b
	where b.rn=2
/*
4. Функции одним запросом
Посчитайте по таблице товаров (в вывод также должен попасть ид товара, название, брэнд и цена):
* пронумеруйте записи по названию товара, так чтобы при изменении буквы алфавита нумерация начиналась заново
* посчитайте общее количество товаров и выведете полем в этом же запросе
* посчитайте общее количество товаров в зависимости от первой буквы названия товара
* отобразите следующий id товара исходя из того, что порядок отображения товаров по имени 
* предыдущий ид товара с тем же порядком отображения (по имени)
* названия товара 2 строки назад, в случае если предыдущей строки нет нужно вывести "No items"
* сформируйте 30 групп товаров по полю вес товара на 1 шт

Для этой задачи НЕ нужно писать аналог без аналитических функций.
*/

select s.StockItemID, s.StockItemName, s.Brand,s.UnitPrice
, row_number() over(partition by SUBSTRING(s.StockItemName,1,1) order by s.StockItemName) rn 
, count(StockItemName) over() items_cnt
, count(StockItemName) over(partition by SUBSTRING(s.StockItemName,1,1)) items_cnt_by_letter
, lead(StockItemID) over(order by StockItemName) next_itemid
, lag(StockItemID) over(order by StockItemName) previose_itemid
, coalesce(lag(StockItemName, 2) over(order by StockItemName), 'No items') previose_2_item
, ntile(30) over(order by s.TypicalWeightPerUnit) 

from [Warehouse].[StockItems] s
order by s.StockItemName

/*
5. По каждому сотруднику выведите последнего клиента, которому сотрудник что-то продал.
   В результатах должны быть ид и фамилия сотрудника, ид и название клиента, дата продажи, сумму сделки.
*/


select a.sales_name, a.SalespersonPersonID, a.customer_name, a.CustomerID
	, a.InvoiceDate
	, a.TransactionAmount from 
	(
	select p.FullName sales_name, si.SalespersonPersonID, pp.FullName customer_name, si.CustomerID
	, si.InvoiceDate
	, tr.TransactionAmount
	, row_number() over(partition by si.SalespersonPersonID order by si.InvoiceDate desc) num
	from [Sales].[Invoices] si
	join Application.People p on si.SalespersonPersonID=p.PersonID
	join Application.People pp on si.CustomerID=pp.PersonID
	join [Sales].[CustomerTransactions] tr on tr.InvoiceID=si.InvoiceID
	) a
	where a.num=1



/*
6. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/



select CustomerName , CustomerID
	, StockItemID
	, UnitPrice
	, last_invoce_date from 
	(
	select c.CustomerName , c.CustomerID
	, ol.StockItemID
	, ol.UnitPrice
	, max(o.InvoiceDate) last_invoce_date
	--, dense_rank() over(partition by c.CustomerName order by ol.UnitPrice desc) num
	, row_number() over(partition by c.CustomerName order by ol.UnitPrice desc) num
	from [Sales].[Invoices] o
	join [Sales].[InvoiceLines] ol on ol.InvoiceID=o.InvoiceID
	join [Sales].[Customers] c on c.CustomerID=o.CustomerID
	--where CustomerName ='Aakriti Byrraju'
	group by c.CustomerName , c.CustomerID
	, ol.StockItemID
	, ol.UnitPrice
	) aa
	where aa.num<=2



--Опционально можете для каждого запроса без оконных функций сделать вариант запросов с оконными функциями и сравнить их производительность. 