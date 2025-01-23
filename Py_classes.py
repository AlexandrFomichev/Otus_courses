# -*- coding: utf-8 -*-
"""
Created on Sat Jan 18 14:47:30 2025

@author: alexa
"""

import numpy as np
import matplotlib.pyplot as plt
import pyodbc as db
import pandas as pd
import math as mt
from datetime import datetime as dt
from datetime import timedelta as td


#%%
class store_database:
    def __init__(self):
        self.server='DESKTOP-UG0O99T\LEARNING'
        self.db_name='MyStore'
        self.connection_params='Trusted_Connection=Yes;DRIVER={ODBC Driver 17 for SQL Server}; server=DESKTOP-UG0O99T\LEARNING;DATABASE=MyStore'
        pass
    
    def insert_data(self,table_name, inserts):
        if len(inserts)!=0:
            connection=db.connect(self.connection_params)
            cur=connection.cursor()
            fields=cur.execute("""
                                      select name from sys.columns
                                      where object_id=OBJECT_ID('%s')
                                      and is_identity=0
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
        connection=db.connect(self.connection_params)
        cur=connection.cursor()
        res=cur.execute(sql_query)
        return list(res)
    
    def exec_query(self, sql_query):
        connection=db.connect(self.connection_params)
        cur=connection.cursor()
        cur.execute(sql_query)
        cur.commit()
        connection.close()
        pass
    
    pass
myDB=store_database()
#%%

dict_item_groups=pd.DataFrame(pd.read_excel("D:\Курсы\Аналитика\Таблицы БД.xlsx", "dict_item_groups"))

dict_categories={}
for i in range(10):
    dict_categories[dict_item_groups['item_group_name'][i]]=[dict_item_groups['Мат. ожиание цены'][i], 
                                                             dict_item_groups['Сигма цены'][i],
                                                             dict_item_groups['Потребность (техническое)'][i],
                                                             dict_item_groups['Вес товара'][i]]
    pass





#dict_categories={'outdoor': [1000, 300, 0.2, 0.1]
#             , 'indoor': [200, 20, 0.5, 0.04]
#             , 'accessory':[20, 50, 0.7, 0.01]} #матожидание, сигма, потребность, к-т объёма (для склада магазина)

dict_brands={'golden':2, 'silver': 1.4, 'noname': 1}
dict_suppliers={1: 'noname', 2: 'silver', 3: 'golden'}
dict_center_calss={'A':1.2, 'B':1.0, 'C': 0.8, 'D': 0.5}


class item:
    def __init__(self, group, supplier):
        self.category=dict_categories[group]
        self.brand=dict_suppliers[supplier]
        self.cost=abs(np.random.normal(self.category[0], self.category[1]))*dict_brands[self.brand]
        self.price=round(2*dict_brands[self.brand]*self.cost/10)*10+9
        self.weight=self.category[3]
        self.item_buy_probability=self.category[2]/self.price #вероятность продажи
        pass
    def mark_down(self, mark_down_value):   #Снизить цену, увеличить вероятность продажи
        self.price=round(self.price*mark_down_value/10)*10+9
        self.item_buy_probability=self.category[2]/self.price
        pass
    
    pass
item1=item('Зонты', 1)

print(item1.cost, item1.price, item1.weight, item1.item_buy_probability)
item1.mark_down(0.7)
print(item1.cost, item1.price, item1.weight, item1.item_buy_probability)
#%%
st=myDB.query_data("""SELECT [store_id]
      ,[store_name]
      ,[trade_area]
      ,[trade_center_calss]
      ,[store_floor]
      ,[open_date]
      ,[city]
      ,[copmetitors_cnt]
      ,[city_center_distance (m)]
  FROM [MyStore].[dict].[stores]
""")[0]
print(st)

class store:
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
    
    def attract_visitors(self):
        increase=self.trade_area*12
        decrease=mt.sqrt(self.store_floor)*self.competitors_cnt*(mt.log(self.city_center_dist*pow(10,-3))+1)
        return round(increase/decrease)
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
        pass
    
    def sails_rests(self):
        return {'sails': [[self.store_id, l.category, l.brand, l.cost, l.price] for l in self.item_sold],
                'rests': [[self.store_id, l.category, l.brand, l.cost, l.price] for l in self.item_list]}
    pass



store1=store(st, [])

#%%

store1.get_item(item1)
print(store1.attract_visitors())
print(store1.sails_rests())

#%%
class store:
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
        lux_coef=0.5*dict_store_clusters[self.cluster]/dict_brands[item.brand]
        need_coef=dict_groups[item.group][2]
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