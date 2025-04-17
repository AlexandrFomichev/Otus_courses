# -*- coding: utf-8 -*-
"""
Created on Sat Jan 18 14:47:30 2025

@author: alexa
"""

import numpy as np
import random as rnd
import matplotlib.pyplot as plt
import pyodbc 
import pandas as pd
import math as mt
from datetime import datetime as dt
from datetime import timedelta as td
import datetime as datetime

"""
  
"""
#%%
class store_database:
    def __init__(self):
        self.server='DESKTOP-UG0O99T\LEARNING'
        self.db_name='MyStore'
        self.connection_params='Trusted_Connection=Yes;DRIVER={ODBC Driver 17 for SQL Server}; server=DESKTOP-UG0O99T\LEARNING;DATABASE=MyStore'
        pass
    
    def insert_data(self,table_name, inserts):
        if len(inserts)!=0:
            connection=pyodbc.connect(self.connection_params)
            cur=connection.cursor()
            fields=cur.execute("""
                                      select name from sys.columns
                                      where object_id=OBJECT_ID('%s')
                                      and is_identity=0
                                      and generated_always_type=0
                                      """ % (table_name))
            fields=[element[0] for element in fields]
            query="""
                insert into %s (%s) values(%s) 
                """ %(table_name, '\n,'.join(fields), ','.join('?'*len(fields)))

            cur.executemany(query, inserts)

            cur.commit()
            connection.close()
            pass
        pass
    
 

                 

 
    
    def query_data(self, sql_query):
        connection=pyodbc.connect(self.connection_params)
        cur=connection.cursor()
        res=cur.execute(sql_query)
        return list(res)
    
    def exec_query(self, sql_query):
        connection=pyodbc.connect(self.connection_params)
        cur=connection.cursor()
        cur.execute(sql_query)
        cur.commit()
        connection.close()
        pass
    
    pass



#%%

dict_item_groups=pd.DataFrame(pd.read_excel("F:\Курсы\Аналитика\Таблицы БД.xlsx", "dict_item_groups"))


dict_categories={}
for i in range(20):
    dict_categories[dict_item_groups['item_group_name'][i]]=[dict_item_groups['Мат. ожиание цены'][i], 
                                                             dict_item_groups['Сигма цены'][i],
                                                             dict_item_groups['Потребность (техническое)'][i],
                                                             dict_item_groups['Вес товара'][i],
                                                             dict_item_groups['item_group_id'][i]]
    pass





#dict_categories={'outdoor': [1000, 300, 0.2, 0.1]
#             , 'indoor': [200, 20, 0.5, 0.04]
#             , 'accessory':[20, 50, 0.7, 0.01]} #матожидание, сигма, потребность, к-т объёма (для склада магазина)

dict_brands={'golden':2, 'silver': 1.4, 'noname': 1}
dict_suppliers={1: 'noname', 2: 'silver', 3: 'golden'}
dict_center_calss={'A':1.2, 'B':1.0, 'C': 0.8, 'D': 0.5}

"""
aa=dict_item_groups[['item_group_id',	'item_group_name',	'item_category_name']]

bb=[]
for io in range(20):
    bb.append([int(aa['item_group_id'][io]), aa['item_group_name'][io], aa['item_category_name'][io]])
    pass
print(bb)



db1=store_database()
print(bb)
db1.insert_data('[dict].[item_groups]', bb)
"""
#%%


#%%

class item:
    def __init__(self, group, supplier):
        self.category=dict_categories[group]
        self.brand=dict_suppliers[supplier]
        self.cost=abs(np.random.normal(self.category[0], self.category[1]))*dict_brands[self.brand]
        self.price=round(2*dict_brands[self.brand]*self.cost/10)*10+9
        self.weight=self.category[3]
        self.item_buy_probability=self.category[2]/self.price #вероятность продажи
        self.item_id=0
        self.item_group_id=int(self.category[4])
        self.supplier_id=int(supplier)
        self.part_name=str(group)+' '+str(self.brand)+' '+str(np.random.randint(1,100))
        pass
    
    
    def mark_down(self, mark_down_value):   #Снизить цену, увеличить вероятность продажи
        self.price=round(self.price*mark_down_value/10)*10+9
        self.item_buy_probability=self.category[2]/self.price
        pass
    
    
    def genereate_id(self):
        db=store_database()
        self.item_id=int(db.query_data("""select isnull(max(item_id),0) from [dict].[items]""")[0][0])+1
        
        db.insert_data("[dict].[items]", [[self.item_id
                                           , self.part_name
                                           , self.item_group_id
                                           , self.supplier_id
                                           , self.cost
                                           , self.weight
                                           , self.price]])
        pass
    
    pass


#%%

class anket:
    def __init__(self, realize_date, ank_store_id):
        self.conn=store_database() 
        self.realize_date=realize_date
        self.ank_store_id=ank_store_id
        self.discount_card_type_id=self.dc_type_define()
        self.discount_card_type=self.conn.query_data("""select 'Дисконтные карты '+discount_card_type_name from [dict].[discount_cards_types] where discount_card_type_id=(%d)""" %(self.discount_card_type_id))[0][0]
        self.price=5
        self.sale_price=self.conn.query_data("select discount_card_price from [dict].[discount_cards_types] where discount_card_type_id=(%d)" %(self.discount_card_type_id))[0][0]
        pass
    
    def generane_person(self):
        name=rnd.choice(['Попов', 'Иванов', 'Петров', 'Дирк', 'Никитин'])
        brthd='1990-01-01'
        phone='+7'+str(np.random.randint(1000000, 9999999))
        email='email'
        dict_person={'pers_name': name,
                     'birthday': brthd,
                     'mob_phone': phone,
                     'email': email}
        return dict_person
        
    
    def dc_type_define(self):
        a=np.random.randint(100)
        if a>90:
            return 3
        elif a>50:
            return 2
        else:
            return 1
        pass
    
    def generate_anket(self):
        item3=item(self.discount_card_type,1)
        item3.genereate_id()
        pers=self.generane_person()
        self.item_id=item3.item_id
        self.ank_no=int(self.conn.query_data("""SELECT isnull(max(discount_card_id),0) FROM MyStore.dict.anket_discount_cards""")[0][0])+1
        self.conn.insert_data("[MyStore].[Pers].[anket_person]", [[ self.ank_no
                                                                  ,pers['pers_name'] 
                                                                  ,pers['mob_phone']
                                                                  ,pers['email']
                                                                  ,pers['birthday']
                                                                  ]])
        self.conn.insert_data('[MyStore].[dict].[anket_discount_cards]',  [[self.item_id
                                                                              ,self.ank_no
                                                                              ,self.discount_card_type_id
                                                                              ,self.realize_date]])
        pass
    pass

    
    

    
        
    

#%%

class store:
    def __init__(self, st):
        self.store_id=st[0]
        self.trade_area=float(st[2])
        self.cluster=st[3]
        #self.item_list=item_list
        self.store_floor=st[4]
        self.competitors_cnt=st[7]
        self.city_center_dist=float(st[8])
        self.item_sold=[]
        self.conn=store_database()
        self.curent_fullness=float(self.conn.query_data("""select isnull(sum(i.item_weight),0) from [MyStore].[fact].[Store_rests]  ss
                                                      join [MyStore].[dict].[items] i on i.item_id=ss.item_id
                                                      where ss.store_id=(%s)
													  and ss.rest_date=(select max(s.rest_date) from [MyStore].[fact].[Store_rests]  s)""" %(self.store_id))[0][0])

        pass
    
    def get_item(self, get_date): 
            delivery_id=self.conn.query_data("select isnull(max(Delivery_id),0) from fact.Deliveriy_to_store")[0][0]+1 #нумеруем поставку
            aa = list(dict_categories.keys())[3:20] #[3:20]
            bb=0
            self.curent_fullness=float(self.conn.query_data("""select isnull(max(f.Fullnest_area/st.trade_area),0) from [fact].[current_store_fullnest] f
                        join dict.stores st on st.store_id=f.store_id
                        where st.store_id=(%s)""" %(self.store_id))[0][0])
            while bb<50: #bb<20
                
                for i in aa:
                    for j in range(1,4): #1,4
                        item1=item(i, j)
                        if self.trade_area>=item1.weight+self.curent_fullness:
                            item1.genereate_id()
                            self.conn.insert_data("""fact.Current_Deliveriy_to_store""", [[delivery_id
                                                                                       , get_date #'2022-01-15'
                                                                                       , item1.supplier_id
                                                                                       , self.store_id
                                                                                       , item1.item_id
                                                                                       , item1.cost]])
                            self.curent_fullness=item1.weight+self.curent_fullness
                        else:
                             break   
                        pass
                    pass
                bb=bb+1
                pass
            self.conn.exec_query("exec [fact].[delivery_to_store_insert]")
            pass
        
            
    
    def attract_visitors(self, dt):
        deb=dt
        isw=int(self.conn.query_data("""select IsWeekend from [dict].[Calendar]
                                 where Report_DT=cast(%r as date)""" %dt)[0][0]) #%(dt)
        if isw==1:
            increase=self.trade_area*360
        else :
            increase=self.trade_area*120
            pass
               
        decrease=mt.sqrt(self.store_floor+1)*self.competitors_cnt*(mt.sqrt(self.city_center_dist*pow(10,-2))+1)
        visitors=increase/decrease*(1+np.random.random())
        
        return round(visitors)
    
    def tt_type_define(self):
        a=np.random.randint(100)
        if a>80:
            return 1
        else:
            return 2
        pass

    
    
    
    
    def dc_sail(self, dt):
        card1=anket(dt, self.store_id)
        card1.generate_anket()
        self.conn.insert_data('[MyStore].[fact].[Current_Cash_transactions]',  [[self.store_id
                                                                          ,self.tt_type_define()
                                                                          ,1 #Operator_id
                                                                          ,dt
                                                                          ,dt
                                                                          , None #discount_card_id
                                                                          ,card1.item_id
                                                                          ,card1.price
                                                                          ,None #Promotional_Campaign_id
                                                                          ,card1.sale_price]])
        return [self.store_id, dt, card1.item_id]
    
        
    
    
    
    def create_receipt(self, dt, cur_j, basket):
        receipt_no=int(self.conn.query_data("""
                                            select coalesce(max(receipt_no),0)
                                            from(
                                            select max(receipt_no) receipt_no from  [fact].[receipts] r
                                            union 
                                            select max(receipt_no) receipt_no from [fact].[current_receipts]) aa""")[0][0])+1
        
        
        #задать вероятность применения дисконтной карты, базирующуюся на объёме уже выпущенных дисконтных карт
        cur_dc_cnt=int(self.conn.query_data("""select isnull(count(discount_card_id),0) from [dict].[anket_discount_cards]""")[0][0])
        pos=cur_dc_cnt*np.random.random(1)[0]/(cur_dc_cnt+1)
        if pos>0.95:
            cards=np.array(self.conn.query_data("select discount_card_id from [dict].[anket_discount_cards]"))
            cards=cards.T[0]
            discount_card_id=rnd.choice(cards) #из всех существующих карт выбираем случайную
            for i in basket:
                i.append(1) #[Transactions_type_id]
                i.append(int(discount_card_id))
                i.insert(0, receipt_no)
                pass        
        else:
            #пробуем продать клиенту ДК
            if np.random.random(1)[0]>0.8:
                basket.append(self.dc_sail(dt)) #в этой строке и добавляется покупка карты в чек, и создаётся новая карта  
            for i in basket:
                i.append(1)  #[Transactions_type_id]
                i.append(None)
                i.insert(0, receipt_no)
                pass 
            pass
        pass
    
                    
             #конец If-else внешнего
        for i in basket:
            self.conn.insert_data('fact.current_receipts', [i]) 
            pass
        
            
                
        
        pass
    
        
    
    def sail_items(self, dt):
        vs=self.attract_visitors(dt)
        res=(self.conn.query_data("""select * from [fact].[Store_rests]
                           where rest_date=(%r)
						   and store_id=(%r)""" %(dt, self.store_id)))
        for j in range(vs):
            self.conn.insert_data('fact.Current_Store_visitors', [[self.store_id, #[store_id]
                                                                    dt, # ,[Report_DT]
                                                                    1  #,[visit_fact]
                                                                    ]])
            item_counter=0    
            basket=[]
            for i in res:
                posible=1/i[4] #вероятность покупки товара зависит от цены товара
                stoch=np.random.exponential(1)
                if posible>=stoch:
                    transaction_type_id=1
                    Operator_id=1
                    #discount_card_id=0 #сначала 0, но после цикла по товарам для j клиента предусмотреть вероятность быть клиентом с картой
                    item_id=i[2]
                    item_price=i[4]
                    #Promotional_Campaign_id=0
                    sale_price=i[4]
                    self.conn.insert_data('[MyStore].[fact].[Current_Cash_transactions]',  [[self.store_id
                                                                                      ,transaction_type_id
                                                                                      ,Operator_id
                                                                                      ,dt
                                                                                      ,dt
                                                                                      , None #discount_card_id
                                                                                      ,item_id
                                                                                      ,item_price
                                                                                      ,None #Promotional_Campaign_id
                                                                                      ,sale_price]])
                                
                    item_counter=item_counter+1
                    basket.append([self.store_id
                                    ,dt
                                    ,item_id])
                    res.remove(i)
                    pass #конец IF
                pass #конец цикла для 1 покупателя
            if item_counter>0:
                self.create_receipt(dt,j,basket)
                pass
            
            pass
        #конец цикла по всем покупателям
        self.conn.exec_query("""exec [fact].[Cash_transactions_insert] """)
        #влияющие величины: результат attract_visitors(), характеристики товара
        pass
    

    pass






#%%
class store1:
    def __init__(self, st, item_list):
        self.store_id=st[0]
        self.trade_area=float(st[2])
        self.cluster=st[3]
        self.item_list=item_list
        self.store_floor=st[4]
        self.competitors_cnt=st[7]
        self.city_center_dist=float(st[8])
        self.item_sold=[]

        pass
    
    def get_item(self, item):
        self.item_list.append(item)
        pass
    
    def get_employee(self, emp_cnt):
        if self.employee_cnt+emp_cnt>self.employee_max:
            self.employee_cnt=self.employee_max
            pass
        else:
            self.employee_cnt=self.employee_cnt+emp_cnt
            pass
        pass
    
    
    def attract_visitors(self):
        increase=self.trade_area*12
        decrease=mt.sqrt(self.store_floor)*self.competitors_cnt*(mt.log(self.city_center_dist*pow(10,-3))+1)
        return increase/decrease
    
    def sail_possible(self, item):
        lux_coef=0.5*dict_center_calss[self.cluster]/dict_brands[item.brand]
        need_coef=dict_categories[item.group][2]
        return lux_coef*need_coef*self.attract_visitors()/10000
    
    def sail_items(self):
        self.item_sold=[]
        revenue=0
        for i in self.item_list:
            if self.sail_possible(i)>=abs(np.random.random()):
                self.item_sold.append(i)
                self.item_list.remove(i)
                revenue=revenue+i.price
                pass
            pass
        return revenue
        
    def sails_rests(self):
        return {'sails': [[self.store_id, l.group, l.brand, l.cost, l.price] for l in self.item_sold], 
                'rests': [[self.store_id, l.group, l.brand, l.cost, l.price] for l in self.item_list]}
    
    pass