/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "03 - Подзапросы, CTE, временные таблицы".

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
-- Для всех заданий, где возможно, сделайте два варианта запросов:
--  1) через вложенный запрос
--  2) через WITH (для производных таблиц)
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Выберите сотрудников (Application.People), которые являются продажниками (IsSalesPerson), 
и не сделали ни одной продажи 04 июля 2015 года. 
Вывести ИД сотрудника и его полное имя. 
Продажи смотреть в таблице Sales.Invoices.
*/

select PersonID, p.FullName from Application.People  p
where IsSalesperson=1
and PersonID not in (select  SalespersonPersonID from Sales.Invoices  s
			where s.InvoiceDate='2015-07-04'
			) 

; with pers as
	(select PersonID, p.FullName from Application.People  p
	where IsSalesperson=1),
	sales as
	(select  SalespersonPersonID from Sales.Invoices  s
			where s.InvoiceDate='2015-07-04')
select pers.*
from pers 
left join sales on sales.SalespersonPersonID=pers.PersonID
where sales.SalespersonPersonID is null
/*
2. Выберите товары с минимальной ценой (подзапросом). Сделайте два варианта подзапроса. 
Вывести: ИД товара, наименование товара, цена.
*/

select s.StockItemID, s.StockItemName, s.UnitPrice from [Warehouse].[StockItems] s
where s.UnitPrice=(select min(s.UnitPrice) from [Warehouse].[StockItems] s)

select s.StockItemID, s.StockItemName, s.UnitPrice
from [Warehouse].[StockItems] s
join (select min(s.UnitPrice) min_price from [Warehouse].[StockItems] s) min_price on min_price.min_price=s.UnitPrice


/*
3. Выберите информацию по клиентам, которые перевели компании пять максимальных платежей 
из Sales.CustomerTransactions. 
Представьте несколько способов (в том числе с CTE). 
*/

;with tr as
(select top 5 t.CustomerID, t.TransactionAmount from Sales.CustomerTransactions t
order by t.TransactionAmount desc)
select  p.CustomerID, p.CustomerName, tr.TransactionAmount from [Sales].[Customers]  p
join tr on tr.CustomerID=p.CustomerID



select  p.CustomerID, p.CustomerName, tr.TransactionAmount from [Sales].[Customers]  p
join (select top 5 t.CustomerID, t.TransactionAmount from Sales.CustomerTransactions t
order by t.TransactionAmount desc) tr on tr.CustomerID=p.CustomerID

/*
4. Выберите города (ид и название), в которые были доставлены товары, 
входящие в тройку самых дорогих товаров, а также имя сотрудника, 
который осуществлял упаковку заказов (PackedByPersonID).
*/

;with expItems as
(
select top  3 with ties s.StockItemID, s.StockItemName, UnitPrice from [Warehouse].[StockItems] s
order by s.UnitPrice desc
),
fact as (
select il.StockItemID, pe.FullName PackedByPersonName, s.CityName, s.CityID from [Sales].[Invoices] si
join [Sales].[InvoiceLines] il on il.InvoiceID=si.InvoiceID
join [Sales].[Customers] c on c.CustomerID=si.CustomerID
join [Application].[Cities] s on s.CityID=c.DeliveryCityID
join [Application].[People] pe on pe.PersonID=si.PackedByPersonID
)
select distinct fact.CityName, fact.CityID, fact.PackedByPersonName from fact
join expItems on expItems.StockItemID=fact.StockItemID



select distinct  pe.FullName PackedByPersonName, s.CityName, s.CityID from [Sales].[Invoices] si
join [Sales].[InvoiceLines] il on il.InvoiceID=si.InvoiceID
join [Sales].[Customers] c on c.CustomerID=si.CustomerID
join [Warehouse].[StockItems] i on i.StockItemID=il.StockItemID
join [Application].[Cities] s on s.CityID=c.DeliveryCityID
join [Application].[People] pe on pe.PersonID=si.PackedByPersonID
where i.UnitPrice in (
select top 3 s.UnitPrice from [Warehouse].[StockItems] s
order by s.UnitPrice desc
)

-- ---------------------------------------------------------------------------
-- Опциональное задание
-- ---------------------------------------------------------------------------
-- Можно двигаться как в сторону улучшения читабельности запроса, 
-- так и в сторону упрощения плана\ускорения. 
-- Сравнить производительность запросов можно через SET STATISTICS IO, TIME ON. 
-- Если знакомы с планами запросов, то используйте их (тогда к решению также приложите планы). 
-- Напишите ваши рассуждения по поводу оптимизации. 

-- 5. Объясните, что делает и оптимизируйте запрос


 SET STATISTICS IO, TIME ON


SELECT 
	Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	(SELECT People.FullName
		FROM Application.People
		WHERE People.PersonID = Invoices.SalespersonPersonID
	) AS SalesPersonName,
	SalesTotals.TotalSumm AS TotalSummByInvoice, 
	(SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
		FROM Sales.OrderLines
		WHERE OrderLines.OrderId = (SELECT Orders.OrderId 
			FROM Sales.Orders
			WHERE Orders.PickingCompletedWhen IS NOT NULL	
				AND Orders.OrderId = Invoices.OrderId)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices 
	JOIN
	(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	FROM Sales.InvoiceLines
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
		ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC


-- --
--Не уверен, что удалось повысить производительность запроса. Удалось только сделать запрос более читаемым без потери производительности.
--запрос берет все заказы, в которых суммарная стоимость всех товаров больше 27 000 и которые уже получены клиентом (PickingCompletedWhen IS NOT NULL)
-- выводит id и дату заказа, сотрудника, сопровождавшего заказ, сумму заказа, расчиттанную двумя способами: через InvoiceLines и через  OrderLines.
--сортирует по убыванию итоговой суммы товаров в заказе.

SELECT 
	Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	 
	People.FullName SalesPersonName,
	TotalSumm 

	, SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice) TotalSummForPickedItems
FROM Sales.Invoices 
join Sales.Orders on Orders.OrderID=Invoices.OrderID
join Sales.OrderLines on OrderLines.OrderID=Orders.OrderID
join Application.People on People.PersonID = Invoices.SalespersonPersonID
JOIN
	(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	FROM Sales.InvoiceLines
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
		ON Invoices.InvoiceID = SalesTotals.InvoiceID
where Orders.PickingCompletedWhen IS NOT NULL
group by Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	People.FullName 
	,	SalesTotals.TotalSumm
ORDER BY TotalSumm DESC




