Alter Table userbehavior
ADD date VARCHAR(20),
ADD hour VARCHAR(20);

UPDATE userbehavior SET date = FROM_UNIXTIME(time,"%Y-%m-%d");
UPDATE userbehavior SET hour = FROM_UNIXTIME(time,"%H");
UPDATE usebehavior SET time = FROM_UNIXTIME(time);


Update userbehavior set time = substring_index(time,'.',1);

#filter
delete from userbehavior
where date<'2017-11-25' or date> '2017-12-03';


#common metrics
select count(distinct user_id) as UV, 
			 sum(case when behavior='pv' then 1 else 0 end) as PV,
			 sum(case when behavior='buy' then 1 else 0 end) as Buy,
			 sum(case when behavior='cart' then 1 else 0 end) as Cart,
			 sum(case when behavior='fav' then 1 else 0 end) as Fav,
			 sum(case when behavior='pv' then 1 else 0 end)/count(distinct user_id) as 'PV/UV'
from userbehavior;


# repurchase rate
select sum(case when buy_amount>1 then 1 else 0 end) as "number of user repurchase",
				count(user_id) as "total number of user",
				sum(case when buy_amount>1 then 1 else 0 end)/count(user_id) as "repurchase rate"
				
				from (select *, count(behavior) as buy_amount from userbehavior 			  		 
							where behavior = 'buy' group by user_id)a;


#bounce rate
select count(*) as "number of user who only visit page one time"
from 
(select user_id
from userbehavior
group by user_id
having count(behavior)=1)a;



#Conversion funnel in total
select behavior, count(*)
from userbehavior
group by behavior
order by behavior desc;


#conversion funnel of unique visitor
select behavior, count(distinct user_id)
from userbehavior
group by behavior
order by behavior desc;

#from the demension of time
select date,
				count(distinct user_id) as dau,
				sum(case when behavior ='pv' then 1 else 0 end) as 'page_view',
				sum(case when behavior ='cart' then 1 else 0 end) as 'add_to_cart',
				sum(case when behavior ='fav' then 1 else 0 end) as 'add_to_favorite',
				sum(case when behavior ='buy' then 1 else 0 end) as 'purchase'
from userbehavior
group by date;

#from the demension of hour
select hour,
				count(distinct user_id) as user_per_hour,
				sum(case when behavior ='pv' then 1 else 0 end) as 'page_view',
				sum(case when behavior ='cart' then 1 else 0 end) as 'add_to_cart',
				sum(case when behavior ='fav' then 1 else 0 end) as 'add_to_favorite',
				sum(case when behavior ='buy' then 1 else 0 end) as 'purchase'
from userbehavior
where date!='2017-12-03'
group by hour;
				
				
#check
select hour, count(*) as num
from userbehavior
group by hour
order by hour desc;

#top ten items
select item, count(behavior) as "purchase_times"
from userbehavior
where behavior ='buy'
group by item
order by count(behavior) desc
limit 10;

select item, count(behavior) as 'views'
from userbehavior
where behavior = 'pv'
group by item
order by count(behavior)
limit 10;
				
#product
select a.item, a.purchase_time, b.view
from 
(select item, count(behavior) as 'purchase_time'
from userbehavior
where behavior ='buy'
group by item
)a
left join
(select item, count(behavior) as 'view'
from userbehavior
where behavior = 'pv'
group by item
)b
on a.item =b.item;

#time
select a.purchase_time, count(a.item) as num_items
from
(select item, count(behavior) as 'purchase_time'
from userbehavior
where behavior ='buy'
group by item)a
group by a.purchase_time
order by count(a.item) desc;

#R dimension
Create View r_value as 
select user_id, min(time_difference) as R
from (
select user_id, DATEDIFF('2017-12-03', DATE) AS time_difference
from userbehavior
where behavior ='buy')a
group by user_id;

select user_id, R, case when R between 0 and 2 then 4
												when R between 3 and 4 then 3
												when R between 5 and 7 then 2
												else 1 end  as R_Score
from r_value;


#F dimension
Create View f_value as 
select user_id, count(behavior) as F
from userbehavior
where behavior ='buy'
group by user_id;

select user_id, F, case when F between 1 and 10 then 1
												when F between 10 and 20 then 2
												when F between 20 and 30 then 3
												else 4 end  as F_Score
from f_value;



create view r_score as 
select user_id, R,      case when R between 0 and 2 then 4
												when R between 3 and 4 then 3
												when R between 5 and 7 then 2
												else 1 end  as R_Score
from r_value;

create view f_score as 
select user_id, F,      case when F between 1 and 10 then 1
												when F between 10 and 20 then 2
												when F between 20 and 30 then 3
												else 4 end  as F_Score
from f_value;

Create View rf_score as
select a.user_id, a.R_score,b.F_score, a.R_Score+b.F_Score as RF_Score
from r_score a join f_score b on a.user_id = b.user_id;

####
select *, case when RF_Score between 2 and 3 then 'lost user'
							 when RF_Score between 4 and 5 then ' retaining user'
							 when RF_Score between 6 and 7 then 'promising user' 
							 else 'loyal user' end as 'user group'
from rf_score;


## user_group_count 
select user_group, count(*) as user_amount
 from (select *, case when RF_Score between 2 and 3 then 'lost user'
							 when RF_Score between 4 and 5 then ' retaining user'
							 when RF_Score between 6 and 7 then 'promising user' 
							 else 'loyal user' end as 'user_group'
from rf_score)a
 group by user_group;
		

#high user
select date,
sum(case when behavior='pv' then 1 else 0 end) as 'view',
sum(case when behavior='cart' then 1 else 0 end) as 'add_to_cart',
sum(case when behavior='fav' then 1 else 0 end) as 'add_to_favorite',
sum(case when behavior='buy' then 1 else 0 end) as 'purchase',
sum(case when behavior='buy' then 1 else 0 end)/sum(case when behavior='pv' then 1 else 0 end) as 'ourchase conversion'

from userbehavior
where user_id =107932
group by date;
