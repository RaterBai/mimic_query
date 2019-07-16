/* create a table to record all the adult info */
create table adult_info as
	select p.subject_id,
		   a.hadm_id,
		   p.gender,
		   p.dob, 
		   a.admittime, 
		   a.ethnicity, 
		   a."language", 
		   a.marital_status, 
		   round((cast(a.admittime as date) - cast(p.dob as date))/365.242, 2) as age
	from public.patients p
	inner join public.admissions a
	on p.subject_id = a.subject_id
	where round((cast(a.admittime as date) - cast(p.dob as date))/365.242, 2) >= 18;

/* select those patients & admission that used Invasive Ventaliation */
drop table pat_useiv;
create table pat_useIV as 
select adult.hadm_id, 
	   adult.subject_id, 
	   cpt.chartdate, 
	   extract(year from chartdate) as year, 
	   extract(month from chartdate) as month,
	   extract(day from chartdate) as day
from  adult_info adult
inner join cptevents cpt
on adult.hadm_id = cpt.hadm_id
where cpt.costcenter = 'Resp' and cpt.description like '%INVASIVE%'
order by adult.subject_id;  /* total distinct subject number: 17325 */

create table pat_iv_info as 
(select adult.subject_id, adult.hadm_id, cpt.chartdate, cpt.description
from adult_info adult
inner join cptevents cpt
on adult.hadm_id = cpt.hadm_id
where cpt.costcenter = 'Resp' and cpt.description like '%INVASIVE%'
order by subject_id);
/* Identify patients who received invasive ventilation */

/* Count how many different patients received IMV */
select count(distinct(subject_id)) from cptevents
where costcenter = 'Resp' and description like '%INVASIVE%';
select count(distinct(hadm_id)) from cptevents
where costcenter = 'Resp' and description like '%INVASIVE%';
/*******/


select count(distinct(subject_id)) from pat_useiv;  /* 17,325 adult patients used IMV */
select count(distinct(hadm_id)) from pat_useiv;		/* 19,576 admissions used IMV */

select count(distinct(subject_id)) from pat_iv_info; /*17,325 adult patients used IMV */
select count(distinct(hadm_id)) from pat_iv_info;     /* 19,576 admissions used IMV */

/* Create a table for the first careunit for each patient */
create table temp1 as 
	select hadm_id, min(intime) from icustays
			/*where first_careunit = 'MICU' or first_careunit = 'CCU'*/
			group by hadm_id;

create table temp2 as 
	select i.hadm_id, t.min, i.first_careunit from icustays i
	inner join temp1 t
	on i.hadm_id = t.hadm_id
	where i.intime = t.min;
		
create table first_careunit as 
	select adm.subject_id, tmp.hadm_id as hadm_id, tmp.min as intime, tmp.first_careunit as first_careunit
	from admissions adm
	inner join temp2 tmp
	on adm.hadm_id = tmp.hadm_id;

drop table temp1;
drop table first_careunit;
/*********************************/
select count(distinct(subject_id)) from first_careunit;  /* 46476 */
select count(distinct(subject_id)) from first_careunit   /* 15636 */
where first_careunit = 'MICU';
select count(distinct(subject_id)) from first_careunit   /* 6802 */
where first_careunit = 'CCU';
/********/

/* Count how many adults' first careunit is MICU */ 
select count(distinct(adult_info.subject_id)) from adult_info
inner join first_careunit
on adult_info.hadm_id = first_careunit.hadm_id;   /* 38512 in total*/

select count(distinct(adult_info.subject_id)) from adult_info
inner join first_careunit
on adult_info.hadm_id = first_careunit.hadm_id
where first_careunit = 'MICU';  /* 15622 */

select count(distinct(adult_info.subject_id)) from adult_info
inner join first_careunit
on adult_info.hadm_id = first_careunit.hadm_id
where first_careunit = 'CCU';

/* adult & used IMV & first_careunit = MICU/CCU */
drop table pat_useiv_micu_ccu;

create table pat_useiv_micu_ccu as 
select pat.*, unit.first_careunit
from pat_useiv pat
inner join first_careunit unit
on pat.hadm_id = unit.hadm_id
where unit.first_careunit = 'MICU' or unit.first_careunit = 'CCU';

select count(distinct(hadm_id)) from pat_useiv_micu_ccu;   /* 8275*/
select count(distinct(subject_id)) from pat_useiv_micu_ccu; /* 7346 */

select count(distinct(subject_id)) from pat_useiv_micu_ccu  
where first_careunit = 'MICU';      /*5533*/

select count(distinct(subject_id)) from pat_useiv_micu_ccu
where first_careunit = 'CCU';       /*1985*/

select count(distinct(hadm_id)) from pat_useiv_micu_ccu
where first_careunit = 'MICU';  /* 6232 */
select count(distinct(hadm_id)) from pat_useiv_micu_ccu
where first_careunit = 'CCU';   /* 2043 */

create table pat_tidal_volume as 
	select pat.subject_id, 
	   pat.hadm_id,
	   pat.chartdate,
	   lab.charttime, 
	   lab.valuenum as tidal_volume,
	   pat.first_careunit from pat_useiv_micu_ccu pat
	inner join labevents lab
	on pat.hadm_id = lab.hadm_id   
	where lab.itemid = 50826 and pat."year" = extract(year from lab.charttime) 
	  and pat."month" = extract(month from lab.charttime) 
	  and pat."day" = extract(day from lab.charttime);

select count(distinct(subject_id)) from pat_tidal_volume
	where first_careunit = 'MICU';  /* 3779 */
select count(distinct(subject_id)) from pat_tidal_volume
	where first_careunit = 'CCU';   /* 1143 */
	
select count(distinct(hadm_id)) from pat_tidal_volume
	where first_careunit = 'MICU';  /* 4098 */

select count(distinct(hadm_id)) from pat_tidal_volume
	where first_careunit = 'CCU';   /* 1163 */
	
/* calculate BMI for each admission */
select * from d_items where category = 'General';   
-- itemid = 226707 for Height (Inch)
-- itemid = 226531 for Admission Wieght (lbs)
-- BMI = weight(lbs) / [height(inch)]^2 * 703
select subject_id, hadm_id, value from chartevents;


create table temp1 as 
select * from chartevents where itemid = 226707;

alter table temp1
alter column charttime type timestamp
using to_timestamp(charttime, 'YYYY-MM-DD HH24:MI:SS');

create table temp2 as 
select * from chartevents where itemid = 226531;
alter table temp2 
alter column charttime type timestamp
using to_timestamp(charttime, 'YYYY-MM-DD HH24:MI:SS');

/* create a table for height */
create table temp3 as 
	select t.hadm_id, t.charttime, temp1.valuenum from temp1
	inner join (select hadm_id, min(charttime) as charttime from temp1
	group by hadm_id) as t
	on temp1.hadm_id = t.hadm_id
	where extract(month from temp1.charttime) = extract(month from t.charttime) and 
		  extract(day from temp1.charttime) = extract(day from t.charttime) and temp1.valuenum != 0;

create table pat_height as 
	select adm.subject_id, temp3.* from admissions adm
	inner join temp3
	on adm.hadm_id = temp3.hadm_id;

select count(distinct(subject_id)) from pat_height;   /* 10380 patients in total have the record for height */
select count(distinct(hadm_id)) from pat_height;      /* 11811 admissions in total have the record for height */
select count(hadm_id) from pat_height;      	      /* verify that the height value is matched with each admission */

drop table temp1;
drop table temp2;
drop table temp3;

create table temp2 as 
select * from chartevents where itemid = 226531;

alter table temp2
alter column charttime type timestamp
using to_timestamp(charttime, 'YYYY-MM-DD HH24:MI:SS');

/* create a table for weight */
create table temp3 as 
	select t.hadm_id, t.charttime, temp2.valuenum from temp2
	inner join (select hadm_id, min(charttime) as charttime from temp2
	group by hadm_id) as t
	on temp2.hadm_id = t.hadm_id
	where extract(month from temp2.charttime) = extract(month from t.charttime) and 
		  extract(day from temp2.charttime) = extract(day from t.charttime);

create table pat_weight as 
	select adm.subject_id, temp3.* from admissions adm
	inner join temp3
	on adm.hadm_id = temp3.hadm_id;

create table pat_bmi as
	select w.subject_id, 
		   w.hadm_id, 
		   w.weight, 
		   h.height,
		   (w.weight/h.height^2)*703 as BMI from pat_weight w
	inner join pat_height h
	on w.hadm_id = h.hadm_id
	order by subject_id;
alter table pat_bmi add column row_id serial;

select * from pat_bmi;
select * from pat_weight;

/* remove duplicate rows */
select * from (select hadm_id, count(hadm_id) as num from pat_bmi
group by hadm_id) as t
where t.num > 1;
select count(*) from pat_bmi;
select count(subject_id) from pat_bmi; 
/* issue: weights maybe different even in a day's measurement at different time point. admission day */
/* 讲道理，subject_id count != hadm_id count */