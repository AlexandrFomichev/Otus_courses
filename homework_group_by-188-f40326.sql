/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, GROUP BY, HAVING".

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

USE WideWorldImporters

/*
1. Посчитать среднюю цену товара, общую сумму продажи по месяцам.
Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Средняя цена за месяц по всем товарам
* Общая сумма продаж за месяц

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select YEAR(i.InvoiceDate) InvoiceYear
, MONTH(i.InvoiceDate) InvoiceMonth
, AVG(il.UnitPrice) AVG_unit_price
, SUM(il.Quantity*il.UnitPrice) SaleSum
, SUM(il.ExtendedPrice) SaleSumTax
from Sales.Invoices i
join [Sales].[InvoiceLines] il on il.InvoiceID=i.InvoiceID
group by YEAR(i.InvoiceDate), MONTH(i.InvoiceDate) 
order by YEAR(i.InvoiceDate), MONTH(i.InvoiceDate) 

/*
2. Отобразить все месяцы, где общая сумма продаж превысила 4 600 000

Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Общая сумма продаж

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select YEAR(i.InvoiceDate) InvoiceYear
, MONTH(i.InvoiceDate) InvoiceMonth
, SUM(il.Quantity*il.UnitPrice) SaleSum
from Sales.Invoices i
join [Sales].[InvoiceLines] il on il.InvoiceID=i.InvoiceID
group by YEAR(i.InvoiceDate), MONTH(i.InvoiceDate) 
having SUM(il.Quantity*il.UnitPrice)>4600000


/*
3. Вывести сумму продаж, дату первой продажи
и количество проданного по месяцам, по товарам,
продажи которых менее 50 ед в месяц.
Группировка должна быть по году,  месяцу, товару.

Вывести:
* Год продажи
* Месяц продажи
* Наименование товара
* Сумма продаж
* Дата первой продажи
* Количество проданного

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select YEAR(i.InvoiceDate) InvoiceYear
, MONTH(i.InvoiceDate) InvoiceMonth
, ite.StockItemName
, SUM(il.Quantity*il.UnitPrice) SaleSum
, min(i.InvoiceDate) FirstSaleDateInMonth
, SUM(il.Quantity) SaleQty
from Sales.Invoices i
join [Sales].[InvoiceLines] il on il.InvoiceID=i.InvoiceID
join [Warehouse].[StockItems] ite on ite.StockItemID=il.StockItemID
group by YEAR(i.InvoiceDate), MONTH(i.InvoiceDate) , ite.StockItemName
having SUM(il.Quantity) <50


-- ---------------------------------------------------------------------------
-- Опционально
-- ---------------------------------------------------------------------------
/*
Написать запросы 2-3 так, чтобы если в каком-то месяце не было продаж,
то этот месяц также отображался бы в результатах, но там были нули.
*/
select a.InvoiceYear InvoiceYear
, a.InvoiceMonth InvoiceMonth
, SUM(coalesce(il.Quantity*il.UnitPrice, 0)) SaleSum
from  (select distinct YEAR(aa.InvoiceDate) InvoiceYear
		, MONTH(aa.InvoiceDate) InvoiceMonth from 
		Sales.Invoices aa
		union select 2024 , 1) a
left join Sales.Invoices i on YEAR(i.InvoiceDate)=a.InvoiceYear and MONTH(i.InvoiceDate)=a.InvoiceMonth
left join  [Sales].[InvoiceLines] il on il.InvoiceID=i.InvoiceID
group by  a.InvoiceYear, a.InvoiceMonth 
having SUM(il.Quantity*il.UnitPrice)>4600000 or SUM(coalesce(il.Quantity*il.UnitPrice, 0))=0



select a.InvoiceYear InvoiceYear
, a.InvoiceMonth InvoiceMonth
, ite.StockItemName
, SUM(il.Quantity*il.UnitPrice) SaleSum
, min(i.InvoiceDate) FirstSaleDateInMonth
, SUM(coalesce(il.Quantity,0)) SaleQty
from (select distinct YEAR(aa.InvoiceDate) InvoiceYear
		, MONTH(aa.InvoiceDate) InvoiceMonth from 
		Sales.Invoices aa
		union select 2024 , 1) a
left join Sales.Invoices i on YEAR(i.InvoiceDate)=a.InvoiceYear and MONTH(i.InvoiceDate)=a.InvoiceMonth
left join [Sales].[InvoiceLines] il on il.InvoiceID=i.InvoiceID
left join [Warehouse].[StockItems] ite on ite.StockItemID=il.StockItemID
group by a.InvoiceYear 
, a.InvoiceMonth  , ite.StockItemName
having SUM(il.Quantity) <50 or SUM(coalesce(il.Quantity,0))=0


--------------------
