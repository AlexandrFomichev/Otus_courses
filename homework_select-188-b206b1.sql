/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, JOIN".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД WideWorldImporters можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Все товары, в названии которых есть "urgent" или название начинается с "Animal".
Вывести: ИД товара (StockItemID), наименование товара (StockItemName).
Таблицы: Warehouse.StockItems.
*/
select a.StockItemID, a.StockItemName from 
[Warehouse].[StockItems] a
where a.StockItemName like '%urgent%' or a.StockItemName like 'Animal%'

/*
2. Поставщиков (Suppliers), у которых не было сделано ни одного заказа (PurchaseOrders).
Сделать через JOIN, с подзапросом задание принято не будет.
Вывести: ИД поставщика (SupplierID), наименование поставщика (SupplierName).
Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders.
По каким колонкам делать JOIN подумайте самостоятельно.
*/

select a.SupplierName from 
[Purchasing].[Suppliers] a
left join [Purchasing].[PurchaseOrders] p on p.SupplierID=a.SupplierID
where p.SupplierID is null

/*
3. Заказы (Orders) с ценой товара (UnitPrice) более 100$ 
либо количеством единиц (Quantity) товара более 20 штук
и присутствующей датой комплектации всего заказа (PickingCompletedWhen).
Вывести:
* OrderID
* дату заказа (OrderDate) в формате ДД.ММ.ГГГГ
* название месяца, в котором был сделан заказ
* номер квартала, в котором был сделан заказ
* треть года, к которой относится дата заказа (каждая треть по 4 месяца)
* имя заказчика (Customer)
Добавьте вариант этого запроса с постраничной выборкой,
пропустив первую 1000 и отобразив следующие 100 записей.

Сортировка должна быть по номеру квартала, трети года, дате заказа (везде по возрастанию).

Таблицы: Sales.Orders, Sales.OrderLines, Sales.Customers.
*/
SET LANGUAGE Russian  
select o.OrderID
, Format(o.OrderDate, 'dd.MM.yyyy') OrderDate
, DATENAME(month, o.OrderDate) YearMonthOrderDate
, datepart(QUARTER, o.OrderDate) YearQuaterOrderDate
, case when datepart(month, o.OrderDate)<=4 then 1
		when datepart(month, o.OrderDate) between 5 and 8 then 2
		else 3 end YearThirdPart
, c.CustomerName

from 
[Sales].[Orders] o
join [Sales].[OrderLines] ol on ol.OrderID=o.OrderID
join Sales.Customers c on c.CustomerID=o.CustomerID
where o.PickingCompletedWhen is not null
and (ol.UnitPrice>100 or ol.Quantity>20)
order by
		 datepart(QUARTER, o.OrderDate) 
		, case when datepart(month, o.OrderDate)<=4 then 1
				when datepart(month, o.OrderDate) between 5 and 8 then 2
				else 3 end 
		, o.OrderDate
OFFSET 1000 ROWS
FETCH NEXT 100 ROWS ONLY

/*
4. Заказы поставщикам (Purchasing.Suppliers),
которые должны быть исполнены (ExpectedDeliveryDate) в январе 2013 года
с доставкой "Air Freight" или "Refrigerated Air Freight" (DeliveryMethodName)
и которые исполнены (IsOrderFinalized).
Вывести:
* способ доставки (DeliveryMethodName)
* дата доставки (ExpectedDeliveryDate)
* имя поставщика
* имя контактного лица принимавшего заказ (ContactPerson)

Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders, Application.DeliveryMethods, Application.People.
*/

select 
dm.DeliveryMethodName
, po.ExpectedDeliveryDate
, ps.SupplierName
, ap.FullName from 
Purchasing.Suppliers ps
join Purchasing.PurchaseOrders po on ps.SupplierID=po.SupplierID
join Application.DeliveryMethods dm on dm.DeliveryMethodID=po.DeliveryMethodID
join Application.People ap on ap.PersonID=po.ContactPersonID
where po.ExpectedDeliveryDate between '20130101' and '20130131'
and dm.DeliveryMethodName in ('Air Freight', 'Refrigerated Air Freight')
and po.IsOrderFinalized=1

/*
5. Десять последних продаж (по дате продажи) с именем клиента и именем сотрудника,
который оформил заказ (SalespersonPerson).
Сделать без подзапросов.
*/

select top 10 with ties s.OrderDate, c.CustomerName,  p.FullName  from 
[Sales].[Orders] s
join [Sales].[Customers] c on s.CustomerID=c.CustomerID
join [Sales].[OrderLines] ol on ol.OrderID=s.OrderID
join [Application].[People] p on p.PersonID=s.SalespersonPersonID
order by s.OrderDate desc


/*
6. Все ид и имена клиентов и их контактные телефоны,
которые покупали товар "Chocolate frogs 250g".
Имя товара смотреть в таблице Warehouse.StockItems.
*/

select distinct c.CustomerID, c.CustomerName, c.PhoneNumber from 
[Sales].[Orders] s
join [Sales].[Customers] c on s.CustomerID=c.CustomerID
join [Sales].[OrderLines] ol on ol.OrderID=s.OrderID
join [Warehouse].[StockItems] si on si.StockItemID=ol.StockItemID
where si.StockItemName='Chocolate frogs 250g'
