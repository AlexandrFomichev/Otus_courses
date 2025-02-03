
--СХЕМЫ:
--dict - таблицы-справочники, есть доступ на SELECT у всех подразделений
--Fact - таблицы операций с бэк-систем (кассы, терминалы приёма поставок и т.д.). Есnm доступ на SELECT у владельца БД, системного администратора и аналитиков данных.
--CRM - таблицы с описанием и историей CRM-кампаний (акции, маркейтинговые кампании),  есть доступ на SELECT у всех подразделений
--Pers - таблицы с персданными анкет клиентов (клиентов с картами) и сотрудников. есть доступ на SELECT у владельца БД
 --, системного администратора, разработчиков, у аналитиков данных - индивидуально по согласованию.

--доступы на изменение объектов: владельца БД, системного администратора, разработчиков

create schema dict;
go
create schema Fact;
go
create schema CRM;
go
create schema Pers

/*Таблица-справочник магазинов сети с текущим состояние магазинов
заполняется вручную операционистами в случае открытия нового магазина или изменения характеристик текущего
при внесении изменений (количество конкурентов, переименование, класс торговой локации...), хранит предыдущие версии строки (системно-версионированная таблица)
используется аналитиками для создания отчётности*/

CREATE TABLE [dict].[stores](
	[store_id] int primary key clustered NOT NULL , --уникальный идентификатор магазина
	[store_name] [varchar](100) NOT NULL, --Наименование магазина
	[trade_area] [numeric](10, 2) NULL, --Торговая площадь с точносью до 0,01 кв. метра
	[trade_center_calss] [char](1) NULL, --класс тргового цента или локации расположения магазина 
	[store_floor] [int] NULL, --этаж расположения магазина
	[open_date] [date] not NULL, --дата открытия
	[close_date] [date] NULL, --дата закрытия
	[city] [int] NOT NULL, --код города
	[copmetitors_cnt] [int] NULL, --текущее количество конкурентов рядом
	[city_center_distance (m)] [numeric](12, 2) NULL, --расстояние до условного центра города
	ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL, --время начала актуальности строки
    ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL, --время окончания актуальности строки
PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON)


/*Справочник городов, может быть изменен только в случае изменения кода или наименования города или появления
нового города, ранее неизвестного Сети
используется аналитиками для  создания отчётности*/

CREATE TABLE [dict].[cities](
	[city_code]  int primary key clustered NOT NULL , --код города 
	[city_name] varchar(50) NOT NULL, --наименование города
	[region] varchar(20) NULL, --Регион, в котором расположен город
	[cost_class] int NULL, --техническое поле, не используется аналитиками
) 

/*Классификатор товаров
заполняется вручную c ведением истории изменений наименований*/

create table [dict].[item_groups](
item_group_id int primary key not null, 
item_group_name nvarchar(50) not null,
item_category_name nvarchar(50) not null,
ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL, --время начала актуальности строки
ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL, --время окончания актуальности строки
PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON)


create table dict.suppliers_brands(
[supplier_id] int primary key not null,
[supplier_name] nvarchar(100) not null,
[brand] nvarchar(10) not null,
ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL, --время начала актуальности строки
ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL, --время окончания актуальности строки
PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON)

create table [dict].[items](
[item_id] int primary key not null,
[item_name] nvarchar(100) null,
[item_group_id] int foreign key references [dict].[item_groups]([item_group_id]) not null,
[item_supplier_id] int foreign key references dict.suppliers_brands([supplier_id]) not null,
[item_cost] money not null
)


create table dict.transaction_types (
[Transactions_type_id] int primary key not null,
[Transactions_type_name] nvarchar(20) not null
)


/*текущие (сегодняшние) клиентские транзакции на кассе (куча)
заполняется автоматически при оплате клиентом покупок*/
CREATE TABLE [fact].[Current_Cash_transactions](
	[cash_transaction_id]  int  NOT NULL , --код города 
	[store_id] int NOT NULL, --id магазина
	[transaction_type_id] varchar(20) not NULL, --id типа операции: покупка картой, наличными, QR, возврат товара
	[Operator_id] int not NULL, --id сотрудника, проводившего операцию
	[Operation_date_time] datetime2 not null, --время операции
	[Operation_date] date not null, --дата операции
	[discount_card_id] int null, --id примененённой клиентом дисконтной карты (если есть)
	[item_id] int not null, --складской идентификатор товара (присваивается товару в момент приёмки поставки)
	[item_price] money not null, --цена товара с ценника 
	[Promotional_Campaign_id] int null, --id промо-акции на товар (если есть)
	[sale_price] money not null -- итоговая цена, которую платит клиент
) 

/*исторические клиентские транзакции на кассе: покупки, возвраты 
заполняется автоматически бэк-системой при наступлении события "закрытие кассы" в конце дня путём инсерта строк из [fact].[Current_Cash_transactions]
используется в ежедневных etl-процессах для формирования пользовательских витрин данных по продажам*/
--drop table [fact].[Cash_transactions]
CREATE TABLE [fact].[Cash_transactions](
	[cash_transaction_id]  int  NOT NULL , --код города 
	[store_id] int foreign key references [dict].[stores]([store_id])  NOT NULL, --id магазина
	[transaction_type_id] int foreign key references [dict].[transaction_types]([Transactions_type_id])  not NULL, --id типа операции: покупка картой, наличными, QR, возврат товара
	[Operator_id] int not NULL, --id сотрудника, проводившего операцию
	[Operation_date_time] datetime2 not null, --время операции
	[Operation_date] date not null, --дата операции
	[discount_card_id] int null, --id типа примененённой клиентом дисконтной карты (если есть)
	[item_id] int foreign key references [dict].[items]([item_id]) not null, --складской идентификатор товара (присваивается товару в момент приёмки поставки)
	[item_price] money not null, --цена товара с ценника 
	[Promotional_Campaign_id] int null, --id промо-акции на товар (если есть)
	[sale_price] money not null -- итоговая цена, которую платит клиент
constraint [PK_cash_transaction] PRIMARY KEY CLUSTERED 
(
	[Operation_date] ASC,
	[cash_transaction_id] ASC
)
) 



/*Таблица с историей кампаний (периоды скидок на определенные группы товаров)
заполняется вручную при планировании новых кампаний
используется для дашбордов и в etl-процессах для расчета*/
create table [CRM].[Promotional_Campaign](
[Promotional_Campaign_id] int not null,
[store_id] int not null,
[item_group] int not null,
[Promotional_Campaign_name] nvarchar(50) not null,
[Campaign_description] nvarchar(200) not null,
[mark_down] numeric (4,3) not null,
[effective_from] date not null,
[effective_to] date not null
constraint [PK_Promotional_Campaign] PRIMARY KEY CLUSTERED 
	(
	[Promotional_Campaign_id] ASC, 
	[store_id] ASC, 
	[effective_from] ASC,
	[effective_to] ASC
	)
)




/*заполняется в конце дня из [fact].[Current_Cash_transactions] для чеков,
в которы была куплена карта магазина*/
create table fact.[anket_discount_cards](
[ank_no] int primary key not null, --id анкетных данных клиента
[discount_card_type_id] nvarchar(20), --id типа карты (влияет на скидку)
[realize_date] date, --дата покупки карты
)



/*типы дисконтных карт с значением скидки для каждой карты*/
create table [dict].[discount_cards_types](
[discount_card_type_id] int primary key not null, 
[discount_card_type_name]  nvarchar(20) not null,
[discount_value] numeric(3,2) not null --величина скидки в долях
)




/*заполняется в конце дня из [fact].[Current_Cash_transactions] для чеков,
в которы была куплена карта магазина*/
create table [pers].[anket_person](
[ank_no] int primary key not null foreign key references fact.[anket_discount_cards]([ank_no]),
[client_name] nvarchar(100),
[mobile_phone] nvarchar(20),
[e_mail] nvarchar(100),
[birthday] date
)





/*куча, в которую записываются текущие принимаемые товары при их сканировании*/
create table fact.Current_Deliveriy_to_store(
[Delivery_id] int not null,
[Delivery_date_time] datetime2,
[supplier_id] int not null,
[store_id] int not null,
[item_id] int not null,
[item_cost] int not null
)
/*история поставок - заполняется раз в день после окончания поставки на основании данных 
fact.Current_Deliveriy_to_store*/
create table fact.Deliveriy_to_store(
[Delivery_id] int not null,
[Delivery_date_time] datetime2,
[Delivery_date] date not null,
[supplier_id] int not null,
[store_id] int foreign key references [dict].[stores]([store_id])  NOT NULL, 
[item_id] int foreign key references [dict].[items]([item_id]) not null, 
[item_cost] int not null
constraint [PK_Deliveriy] primary key 
	(
	[Delivery_id] asc,
	[Delivery_date] asc
	)
)



/*Текущие остатки в магазине
заполняются и апдейтятся дважды:
в начале дня после поставки и в конце дня при закрытии кассы*/
create table fact.Store_rests(
[store_id] int foreign key references dict.stores([store_id]) not null,
[delivery_id] int  not null,
[item_id] int foreign key references dict.items([item_id]) not null,
[rest_date] date not null,
[item_price] money not null
constraint PK_store_date_id primary key
	([store_id], [rest_date], [delivery_id])
)