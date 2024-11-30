/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "05 - Операторы CROSS APPLY, PIVOT, UNPIVOT".

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
1. Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.

Клиентов взять с ID 2-6, это все подразделение Tailspin Toys.
Имя клиента нужно поменять так чтобы осталось только уточнение.
Например, исходное значение "Tailspin Toys (Gasport, NY)" - вы выводите только "Gasport, NY".
Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+-------------+--------------+------------
InvoiceMonth | Peeples Valley, AZ | Medicine Lodge, KS | Gasport, NY | Sylvanite, MT | Jessie, ND
-------------+--------------------+--------------------+-------------+--------------+------------
01.01.2013   |      3             |        1           |      4      |      2        |     2
01.02.2013   |      7             |        3           |      4      |      2        |     1
-------------+--------------------+--------------------+-------------+--------------+------------
*/
select month_first_date, [Sylvanite, MT]
,[Peeples Valley, AZ]
,[Medicine Lodge, KS]
,[Gasport, NY]
,[Jessie, ND]
 from 
 (
select 
TRIM('()' from TRIM( 'Tailspin Toys' FROM c.CustomerName)) customerName 
, DATEADD(month, DATEDIFF(month, 0,  i.InvoiceDate),0) month_first_date
, i.InvoiceID 
, c.CustomerID 
from [Sales].[Customers] c
join [Sales].[Invoices] i on i.CustomerID=c.CustomerID
where c.CustomerID between 2 and 6
) as src
pivot
(
count(src.InvoiceID )
for customerName in ([Sylvanite, MT]
,[Peeples Valley, AZ]
,[Medicine Lodge, KS]
,[Gasport, NY]
,[Jessie, ND])

) pvt

/*
2. Для всех клиентов с именем, в котором есть "Tailspin Toys"
вывести все адреса, которые есть в таблице, в одной колонке.

Пример результата:
----------------------------+--------------------
CustomerName                | AddressLine
----------------------------+--------------------
Tailspin Toys (Head Office) | Shop 38
Tailspin Toys (Head Office) | 1877 Mittal Road
Tailspin Toys (Head Office) | PO Box 8975
Tailspin Toys (Head Office) | Ribeiroville
----------------------------+--------------------
*/

select c.CustomerName, cc.DeliveryAddressLine1  from [Sales].[Customers] c
 cross apply (select distinct DeliveryAddressLine1 from [Sales].[Customers]) cc
where c.CustomerName like '%Tailspin Toys%'
--72963
--проверка кол-ва:
select (select count(distinct CustomerName) from [Sales].[Customers]
		where CustomerName like '%Tailspin Toys%')*(select count(distinct DeliveryAddressLine1) from [Sales].[Customers] )

/*
3. В таблице стран (Application.Countries) есть поля с цифровым кодом страны и с буквенным.
Сделайте выборку ИД страны, названия и ее кода так, 
чтобы в поле с кодом был либо цифровой либо буквенный код.

Пример результата:
--------------------------------
CountryId | CountryName | Code
----------+-------------+-------
1         | Afghanistan | AFG
1         | Afghanistan | 4
3         | Albania     | ALB
3         | Albania     | 8
----------+-------------+-------
*/

select CountryID,CountryName, cn 
from 
		(
		select c.CountryID, c.CountryName
		, cast(c.IsoAlpha3Code as nvarchar(100))  IsoAlpha3Code 
		, cast(c.IsoNumericCode as nvarchar(100))  IsoNumericCode from Application.Countries c
		) aa
unpivot  
		( 
		cn for code in (IsoAlpha3Code, IsoNumericCode) 
		) pv
/*
4. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

SELECT c.CustomerID ,C.CustomerName, aa.StockItemID ,aa.UnitPrice, aa.last_invoice_date
FROM Sales.Customers C
OUTER APPLY (SELECT   TOP 2  il.UnitPrice, il.StockItemID, max(i.InvoiceDate) last_invoice_date
                FROM Sales.InvoiceLines il
				join sales.Invoices i on i.InvoiceID=il.InvoiceID
                WHERE i.CustomerID = C.CustomerID
				group by il.UnitPrice, il.StockItemID
                ORDER BY il.UnitPrice DESC) AS aa
ORDER BY C.CustomerName