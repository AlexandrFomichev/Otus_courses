# -*- coding: utf-8 -*-
"""
Created on Sat Feb 15 14:36:42 2025

@author: alexa
"""
import Py_classes as pc
from datetime import datetime as dt
import numpy as np




db1=pc.store_database()

#%%



for j in range(1,4):
   print(j)
   st1=db1.query_data("""SELECT [store_id]
         ,[store_name]
         ,[trade_area]
         ,[trade_center_calss]
         ,[store_floor]
         ,[open_date]
         ,[close_date]
         ,[city]
         ,[copmetitors_cnt]
         ,[city_center_distance (m)]
         ,[ValidFrom]
         ,[ValidTo]
     FROM [MyStore].[dict].[stores]
     where [store_id]=(%s)
   """ %(j))[0]
   
   
   store1=pc.store(st1)
   
   
   dd=np.array(db1.query_data("""select cast(Report_DT as varchar(10)) from [dict].[Calendar] r
                              where r.Report_DT between '2023-02-21' and '2023-02-28'
							  order by Report_DT'""")).T[0]
   


   
   for i in dd:
       ff=db1.query_data( """select isnull(max(f.Fullnest_area/st.trade_area),0) from [fact].[current_store_fullnest] f
                            join dict.stores st on st.store_id=f.store_id
                            where st.store_id=(%s)""" %(j))[0][0]
       print(ff)
       if ff<0.7:
           store1.get_item(i)
           pass
       store1.sail_items(i)
       pass
   pass

   

    

    

