/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "10 - Операторы изменения данных".

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
1. Довставлять в базу пять записей используя insert в таблицу Customers или Suppliers 
*/
drop table if exists  [Purchasing].[Suppliers_test] 
create table [Purchasing].[Suppliers_test] 
(
[SupplierID] int primary key not null
,[SupplierName] nvarchar(100)
,[PrimaryContactPersonID] int
,[AlternateContactPersonID] int
,[DeliveryMethodID] int
,[DeliveryCityID] int
)

drop table if exists  [Purchasing].[Suppliers_test_2] 
create table [Purchasing].[Suppliers_test_2] 
(
[SupplierID] int primary key not null
,[SupplierName] nvarchar(100)
,[PrimaryContactPersonID] int
,[AlternateContactPersonID] int
,[DeliveryMethodID] int
,[DeliveryCityID] int
)

insert into [Purchasing].[Suppliers_test]
select  [SupplierID]
      ,'TEST: '+[SupplierName]
,[PrimaryContactPersonID] 
,[AlternateContactPersonID] 
,[DeliveryMethodID] 
,[DeliveryCityID] 
	  from [Purchasing].[Suppliers]
	  where 1=1	  
	  and SupplierID between 1 and 4

insert into  [Purchasing].[Suppliers_test] ([SupplierID],[SupplierName],[PrimaryContactPersonID]
	,[AlternateContactPersonID],[DeliveryMethodID],[DeliveryCityID] )
	values (17, 'NewAge', 21, 22, 7, 38171)
/*
2. Удалите одну запись из Customers, которая была вами добавлена
*/

delete from [Purchasing].[Suppliers_test]
where [SupplierID]=2


/*
3. Изменить одну запись, из добавленных через UPDATE
*/

update [Purchasing].[Suppliers_test] set [SupplierName]=UPPER([SupplierName])
where [SupplierID]=17

select *from [Purchasing].[Suppliers_test]

/*
4. Написать MERGE, который вставит  запись в клиенты, если ее там нет, и изменит если она уже есть
*/

merge  [Purchasing].[Suppliers_test] a using  
	(select  [SupplierID],[SupplierName],[PrimaryContactPersonID]
	,[AlternateContactPersonID],[DeliveryMethodID],[DeliveryCityID] from [Purchasing].[Suppliers] where [SupplierID] between 1 and 4) b
on a.[SupplierID]=b.[SupplierID]
when matched then update set a.[SupplierName]=b.[SupplierName]
when NOT MATCHED BY TARGET then
	insert([SupplierID],[SupplierName],[PrimaryContactPersonID]	,[AlternateContactPersonID],[DeliveryMethodID],[DeliveryCityID])
	values(b.[SupplierID],b.[SupplierName],b.[PrimaryContactPersonID],b.[AlternateContactPersonID],b.[DeliveryMethodID],b.[DeliveryCityID]);

/*
5. Напишите запрос, который выгрузит данные через bcp out и загрузить через bulk insert
*/

EXEC sp_configure 'show advanced options', '1'
RECONFIGURE
-- this enables xp_cmdshell
EXEC sp_configure 'xp_cmdshell', '1' 
RECONFIGURE

DECLARE @out varchar(250);
set @out = 'bcp WideWorldImporters.Purchasing.Suppliers_test OUT "D:\demo.txt" -T -c -S ' + @@SERVERNAME;
PRINT @out;
EXEC master..xp_cmdshell @out

DECLARE @in varchar(250);
set @in = 'bcp WideWorldImporters.Purchasing.Suppliers_test_2 IN "D:\demo.txt" -T -c -S ' + @@SERVERNAME;

EXEC master..xp_cmdshell @in;


select * from Purchasing.Suppliers_test_2