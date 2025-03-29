/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "08 - Выборки из XML и JSON полей".

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
Примечания к заданиям 1, 2:
* Если с выгрузкой в файл будут проблемы, то можно сделать просто SELECT c результатом в виде XML. 
* Если у вас в проекте предусмотрен экспорт/импорт в XML, то можете взять свой XML и свои таблицы.
* Если с этим XML вам будет скучно, то можете взять любые открытые данные и импортировать их в таблицы (например, с https://data.gov.ru).
* Пример экспорта/импорта в файл https://docs.microsoft.com/en-us/sql/relational-databases/import-export/examples-of-bulk-import-and-export-of-xml-documents-sql-server
*/


/*
1. В личном кабинете есть файл StockItems.xml.
Это данные из таблицы Warehouse.StockItems.
Преобразовать эти данные в плоскую таблицу с полями, аналогичными Warehouse.StockItems.
Поля: StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice 

Загрузить эти данные в таблицу Warehouse.StockItems: 
существующие записи в таблице обновить, отсутствующие добавить (сопоставлять записи по полю StockItemName). 

Сделать два варианта: с помощью OPENXML и через XQuery.
*/
DECLARE @xmlDocument XML;
SELECT @xmlDocument = BulkColumn
FROM OPENROWSET
(BULK 'D:\Курсы\Аналитика\Rep\Otus_courses\StockItems-188-1fb5df.xml', 
 SINGLE_CLOB)
AS data;

-- Проверяем, что в @xmlDocument
--SELECT @xmlDocument AS [@xmlDocument];

DECLARE @docHandle INT;
EXEC sp_xml_preparedocument @docHandle OUTPUT, @xmlDocument;

drop table if exists Warehouse.del_Warehouse_StockItems;
create table Warehouse.del_Warehouse_StockItems( 
	[StockItemName] nvarchar(100) 
	, [SupplierID] INT 
	, [UnitPackageID] int 
	, [OuterPackageID] int 
	, [QuantityPerOuter] int 
	, [TypicalWeightPerUnit] numeric(5,2)  
	, [LeadTimeDays] int 
	, [IsChillerStock] int 
	, [TaxRate] numeric(10,3) 
	, [UnitPrice] numeric(20,6) 
	);

insert into Warehouse.del_Warehouse_StockItems
SELECT *
FROM OPENXML(@docHandle, N'/StockItems/Item')
WITH ( 
	[StockItemName] nvarchar(100) '@Name' 
	, [SupplierID] INT  'SupplierID'
	, [UnitPackageID] int 'Package/UnitPackageID'
	, [OuterPackageID] int 'Package/OuterPackageID'
	, [QuantityPerOuter] int 'Package/QuantityPerOuter'
	, [TypicalWeightPerUnit] numeric(5,2)  'Package/TypicalWeightPerUnit'
	, [LeadTimeDays] int 'LeadTimeDays'
	, [IsChillerStock] int 'IsChillerStock'
	, [TaxRate] numeric(10,3) 'TaxRate'
	, [UnitPrice] numeric(20,6) 'UnitPrice'
	);

EXEC sp_xml_removedocument @docHandle;


merge  Warehouse.StockItems a using  
	(select  
	[StockItemName] 
	, [SupplierID]  
	, [UnitPackageID]  
	, [OuterPackageID]  
	, [QuantityPerOuter]  
	, [TypicalWeightPerUnit] 
	, [LeadTimeDays]  
	, [IsChillerStock]  
	, [TaxRate] 
	, [UnitPrice]  
	from Warehouse.del_Warehouse_StockItems 
	) b
on a.[StockItemName]=b.[StockItemName]
when matched then update set 

a.[StockItemName]=b.[StockItemName]
, a.[SupplierID]=b.[SupplierID]
, a.[UnitPackageID] = b.[UnitPackageID]
	, a.[OuterPackageID]  =b.[UnitPackageID]
	, a.[QuantityPerOuter]  =b.[UnitPackageID]
	, a.[TypicalWeightPerUnit] =b.[UnitPackageID]
	, a.[LeadTimeDays]  =b.[UnitPackageID]
	, a.[IsChillerStock]  =b.[IsChillerStock]
	, a.[TaxRate] =b.[TaxRate]
	, a.[UnitPrice]  =b.[UnitPrice]
	, a.[lastEditedBy]=2
when NOT MATCHED BY TARGET then
	insert(	[StockItemName] 
	, [SupplierID]  
	, [UnitPackageID]  
	, [OuterPackageID]  
	, [QuantityPerOuter]  
	, [TypicalWeightPerUnit] 
	, [LeadTimeDays]  
	, [IsChillerStock]  
	, [TaxRate] 
	, [UnitPrice]
	, [validFrom]
	, validTo
	, [lastEditedBy])
	values(b.[StockItemName],b.[SupplierID],b.[UnitPackageID],b.[OuterPackageID],b.[QuantityPerOuter],b.[TypicalWeightPerUnit]
	, b.[LeadTimeDays], b.[IsChillerStock], b.[TaxRate], b.[UnitPrice], default, default, 2);

drop table if exists Warehouse.del_Warehouse_StockItems;


/*
2. Выгрузить данные из таблицы StockItems в такой же xml-файл, как StockItems.xml
*/

SELECT TOP 3 [StockItemName] as [@Name] 
	, [SupplierID] as [SupplierID]
	, [UnitPackageID] as [Package/UnitPackageID]
	, [OuterPackageID] as [Package/OuterPackageID]
	, [QuantityPerOuter] as [Package/QuantityPerOuter]
	, [TypicalWeightPerUnit] as  [Package/TypicalWeightPerUnit]
	, [LeadTimeDays] as [LeadTimeDays]
	, [IsChillerStock] as [IsChillerStock]
	, [TaxRate] as [TaxRate]
	, [UnitPrice] as [UnitPrice]
FROM [Warehouse].[StockItems]
FOR XML PATH('Item'), ROOT('StockItems');


/*
3. В таблице Warehouse.StockItems в колонке CustomFields есть данные в JSON.
Написать SELECT для вывода:
- StockItemID
- StockItemName
- CountryOfManufacture (из CustomFields)
- FirstTag (из поля CustomFields, первое значение из массива Tags)
*/


select s.StockItemID, s.StockItemName
,(SELECT *
		FROM OPENJSON (s.CustomFields, '$')
		WITH (CountryOfManufacture     NVARCHAR(MAX)   '$.CountryOfManufacture')
 )
,(SELECT *
		FROM OPENJSON (s.CustomFields, '$')
		WITH ( FirstTag        NVARCHAR(100)   '$.Tags[0]')
 )
--, CustomFields
from Warehouse.StockItems s






/*
4. Найти в StockItems строки, где есть тэг "Vintage".
Вывести: 
- StockItemID
- StockItemName
- (опционально) все теги (из CustomFields) через запятую в одном поле

Тэги искать в поле CustomFields, а не в Tags.
Запрос написать через функции работы с JSON.
Для поиска использовать равенство, использовать LIKE запрещено.

Должно быть в таком виде:
... where ... = 'Vintage'

Так принято не будет:
... where ... Tags like '%Vintage%'
... where ... CustomFields like '%Vintage%' 
*/


	select s.StockItemID, s.StockItemName
	,Replace(REPLACE(REPLACE(JSON_QUERY(s.CustomFields, '$.Tags'), '[', ''), ']',''), '"','') tags

	, CustomFields
	, value
	from Warehouse.StockItems s
	cross apply STRING_SPLIT(Replace(REPLACE(REPLACE(JSON_QUERY(s.CustomFields, '$.Tags'), '[', ''), ']',''), '"',''), ',') 
	where value='Vintage'
