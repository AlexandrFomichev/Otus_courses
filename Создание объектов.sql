USE my_store_test;
go
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
create schema Pers;
go


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
[item_cost] money not null,
[item_price_start] money
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
[store_id] int foreign key references [dict].[stores]([store_id]) not null,
[item_group_id] int foreign key references [dict].[item_groups]([item_group_id]) not null,
[Promotional_Campaign_name] nvarchar(50) not null,
[Campaign_description] nvarchar(200) not null,
[mark_down] numeric (4,3) not null,
[effective_from] date not null,
[effective_to] date not null
constraint [PK_Promotional_Campaign] PRIMARY KEY CLUSTERED 
	(
	[Promotional_Campaign_id] ASC
	)
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
[ank_no] int primary key not null,
[client_name] nvarchar(100),
[mobile_phone] nvarchar(20),
[e_mail] nvarchar(100),
[birthday] date
)


/*заполняется в конце дня из [fact].[Current_Cash_transactions] для чеков,
в которы была куплена карта магазина*/

create table [dict].[anket_discount_cards](
[discount_card_id] int primary key not null, --id дисконтной карты
[ank_no] int foreign key references [Pers].[anket_person]([ank_no]) not null, --id анкетных данных клиента
[discount_card_type_id] int foreign key references [dict].[discount_cards_types] ([discount_card_type_id]), --id типа карты (влияет на скидку)
[realize_date] date, --дата покупки карты
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
[Delivery_date] date foreign key references [dict].[Calendar]([Report_DT]) not null,
[supplier_id] int foreign key references [dict].[suppliers_brands]([supplier_id]) not null,
[store_id] int foreign key references [dict].[stores]([store_id])  NOT NULL, 
[item_id] int foreign key references [dict].[items]([item_id]) not null, 
[item_cost] int not null
constraint PK_delivery_store_item_id primary key
	([Delivery_id], [store_id], [item_id])
)



/*Текущие остатки в магазине
заполняются и апдейтятся дважды:
в начале дня после поставки и в конце дня при закрытии кассы*/
create table fact.Store_rests(
[store_id] int foreign key references dict.stores([store_id]) not null,
[delivery_id] int foreign key references [fact].[Deliveriy_to_store]([delivery_id]) not null,
[item_id] int foreign key references dict.items([item_id]) not null,
[rest_date] date not null,
[item_price] money not null
constraint PK_store_date_item_id primary key
	([store_id], [rest_date], [item_id])
)

/*Текущая наполненность магазинов
ежедневно транкейтится и перезаполняется на последнюю дату. 
испоьзуется в процедуре заполнения магазина при поставке, чтобы ограничить кол-во товаров, принимаемых магазином*/
create table fact.current_store_fullnest(
[store_id] int foreign key references dict.stores([store_id]) not null,
[Fullnest_area] numeric(10,2) null
constraint PK_store_fullnest_id primary key
	([store_id])
)


/*Создание календаря*/
CREATE TABLE dict.Calendar(
       [Report_DT] Date NOT NULL,
       [Week_Day_nm] char(10) NOT NULL,
       [DayOfWeek] tinyint NOT NULL,
       [DayOfMonth] tinyint NOT NULL,
       [DayOfYear] smallint NOT NULL,
       [PreviousDay] date NOT NULL,
       [NextDay] date NOT NULL,
       [WeekOfYear] tinyint NOT NULL,
       [Month] char(10) NOT NULL,
       [MonthOfYear] tinyint NOT NULL,
       [QuarterOfYear] tinyint NOT NULL,
       [Year] int NOT NULL,
       [IsWeekend] bit NOT NULL,
    )
 
ALTER TABLE  dict.Calendar
ADD CONSTRAINT PK_CalendarDate PRIMARY KEY ([Report_DT]); 

--создание индекса для дисконтных карт для быстрого поиска по дате открытия карты 
--+ создание FK к календарю
create nonclustered index [FK_dicound_card_realize_date] 
on [dict].[anket_discount_cards]
(
[discount_card_id]
)
include([realize_date])

ALTER TABLE [dict].[anket_discount_cards]
ADD FOREIGN KEY ([realize_date])
REFERENCES dict.Calendar([Report_DT])



--создание FK к календарю для кассовых транзакций 
ALTER TABLE [Fact].[Cash_transactions]
ADD FOREIGN KEY ([Operation_date])
REFERENCES dict.Calendar([Report_DT])



--создание FK к календарю для товарных остатков
ALTER TABLE [Fact].[Store_rests]
ADD FOREIGN KEY ([rest_date])
REFERENCES dict.Calendar([Report_DT])

--создание FK к календарю для поставок
ALTER TABLE [Fact].[Deliveriy_to_store]
ADD FOREIGN KEY ([Delivery_date])
REFERENCES dict.Calendar([Report_DT])

--Создание индекса для дат начала кампаний
create nonclustered index [Promotional_Campaign_effective_from] 
on [CRM].[Promotional_Campaign]
(
[Promotional_Campaign_id]
)
include([effective_from])


/*регристрация входов в магазин через рамки*/
create table fact.Current_Store_visitors(
[store_id] int not null,
[Report_DT] date not null,
[visit_fact] smallint not null
)


/*посетители в магазине
заполняются 1 раз в конце торгового дня*/
create table fact.Store_visitors(
[store_id] int foreign key references dict.stores([store_id]) not null,
[Report_DT] date foreign key references dict.calendar([Report_DT]) not null,
[visitors_count] int not null
constraint PK_store_visitors_id primary key
	([store_id], [Report_DT])
)


/*Таблица чеков - в ней инфа о примененных скнидках, товарах в 1 чеке, дисконтной карте
в факты кассовых транзакций итоговая цена попадает с участием этой curr-версии этой таблицы*/
create table fact.current_receipts(
[receipt_no] int not null,
[store_id] int not null,
[Report_DT] date not null,
[item_id] int not null,
[Transactions_type_id] int not null,
[discount_card_id] int null
)

create table fact.receipts(
[receipt_no] int not null,
[store_id] int foreign key references dict.stores([store_id]) not null,
[Report_DT] date foreign key references dict.calendar([Report_DT]) not null,
[item_id] int foreign key references dict.items([item_id]) not null,
[Transactions_type_id] int foreign key references [dict].[transaction_types]([Transactions_type_id]) not null,
[discount_card_id] int foreign key references [dict].[anket_discount_cards]([discount_card_id]) null
constraint PK_receipts_items_id primary key
	([receipt_no], [item_id])
)

select object_name(i.object_id), i.* from sys.indexes i
join  sys.objects o on o.object_id=i.object_id
where o.type_desc='USER_TABLE'
