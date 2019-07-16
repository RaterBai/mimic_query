/* create a table to record all the adult info */
drop table if exists adult_info;
create table adult_info as
	select p.subject_id,
		   a.hadm_id,
		   p.gender,
		   p.dob, 
		   a.admittime, 
		   a.ethnicity, 
		   a."language", 
		   a.marital_status, 
		   a.hospital_expire_flag,
		   round((cast(a.admittime as date) - cast(p.dob as date))/365.242, 2) as age
	from public.patients p
	inner join public.admissions a
	on p.subject_id = a.subject_id
	where round((cast(a.admittime as date) - cast(p.dob as date))/365.242, 2) >= 18;

select count(distinct(subject_id)) from adult_info;  /*38552*/
select count(distinct(hadm_id)) from adult_info;     /*50766*/

/* select those adult patients & admission that used Invasive Ventaliation */
drop table if exists pat_useiv;
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

select * from pat_useiv
order by subject_id, chartdate;

select count(distinct(subject_id)) from pat_useiv;  /* 17,325 adult patients used IMV */
select count(distinct(hadm_id)) from pat_useiv;		/* 19,576 admissions used IMV */

/* Create a table for the first careunit for each patient */
drop table if exists temp1
create table temp1 as 
	select hadm_id, min(intime) from icustays
	group by hadm_id;

drop table if exists temp1 
create table temp2 as 
	select i.hadm_id, t.min, i.first_careunit from icustays i
	inner join temp1 t
	on i.hadm_id = t.hadm_id and i.intime = t.min;
		
drop table if exists first_careunit;
create table first_careunit as 
	select adm.subject_id, tmp.hadm_id as hadm_id, tmp.min as intime, tmp.first_careunit as first_careunit
	from admissions adm
	inner join temp2 tmp
	on adm.hadm_id = tmp.hadm_id;

select * from first_careunit
order by subject_id;
/*********************************/
select count(distinct(subject_id)) from first_careunit;  /* 46476 */
select count(distinct(subject_id)) from first_careunit   /* 15379 */
where first_careunit = 'MICU';
select count(distinct(subject_id)) from first_careunit   /* 6593 */
where first_careunit = 'CCU';
/********/

/* Count how many adults' first careunit is MICU */ 
select count(distinct(adult_info.subject_id)) from adult_info
inner join first_careunit
on adult_info.hadm_id = first_careunit.hadm_id;   /* 38512 in total*/

select count(distinct(adult_info.subject_id)) from adult_info
inner join first_careunit
on adult_info.hadm_id = first_careunit.hadm_id
where first_careunit = 'MICU';  /* 15365 */

select count(distinct(adult_info.subject_id)) from adult_info
inner join first_careunit
on adult_info.hadm_id = first_careunit.hadm_id
where first_careunit = 'CCU';  /* 6592 */

/* adult & used IMV & first_careunit = MICU/CCU */

drop table if exists pat_useiv_micu_ccu;
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

drop table pat_tidal_volume;
create table pat_tidal_volume as 
	select pat.subject_id, 
	   pat.hadm_id,
	   pat.chartdate,
	   c.charttime, 
	   c.valuenum as tidal_volume,
	   c.valueuom,
	   pat.first_careunit,
	   case 
	   		when true then 'chart'
	   end as marker
	from pat_useiv_micu_ccu pat
	inner join chartevents c
	on pat.hadm_id = c.hadm_id   
	where c.itemid in (682, 224685) and pat."year" = extract(year from c.charttime) 
	  and pat."month" = extract(month from c.charttime) 
	  and pat."day" = extract(day from c.charttime) and c.valuenum is not null
	  
	  union 
	 
	select pat.subject_id, 
	   pat.hadm_id,
	   pat.chartdate,
	   lab.charttime, 
	   lab.valuenum as tidal_volume,
	   lab.valueuom,
	   pat.first_careunit,
	   case 
	   		when true then 'lab'
	   end as marker
	from pat_useiv_micu_ccu pat
	inner join labevents lab
	on pat.hadm_id = lab.hadm_id   
	where lab.itemid = 50826 and pat."year" = extract(year from lab.charttime) 
	  and pat."month" = extract(month from lab.charttime) 
	  and pat."day" = extract(day from lab.charttime) and lab.valuenum is not null;
	 
-- 682, 224685 TV observe   683,224684 TV set
select * from pat_tidal_volume order by subject_id, hadm_id, chartdate, charttime;

select count(distinct(subject_id)) from pat_tidal_volume
	where first_careunit = 'MICU';  /* 5120 */
select count(distinct(subject_id)) from pat_tidal_volume
	where first_careunit = 'CCU';   /* 1869 */
	
select count(distinct(hadm_id)) from pat_tidal_volume
	where first_careunit = 'MICU';  /* 5316 */

select count(distinct(hadm_id)) from pat_tidal_volume
	where first_careunit = 'CCU';   /* 1843 */
	
select count(distinct(hadm_id)) from pat_tidal_volume;

/* Identify surgical patients and then exclude them */
drop table if exists temp1;
create table temp1 as
select hadm_id, min(transfertime) from services
group by hadm_id;

drop table if exists pat_first_service;
create table pat_first_service as 
select s.subject_id, s.hadm_id, s.transfertime as intime, s.curr_service as services from temp1 t
inner join services s
on t.hadm_id = s.hadm_id and t.min = s.transfertime;
drop table temp1;

select count(distinct(v.subject_id)) from pat_tidal_volume v inner join pat_first_service s on v.hadm_id = s.hadm_id and s.services not in ('CSURG', 'NSURG', 'PSURG', 'SURG', 'TSURG', 'VSURG') where v.first_careunit = 'MICU';
/* 4816 (MICU) */
select count(distinct(v.hadm_id)) from pat_tidal_volume v inner join pat_first_service s on v.hadm_id = s.hadm_id and s.services not in ('CSURG', 'NSURG', 'PSURG', 'SURG', 'TSURG', 'VSURG') where v.first_careunit = 'MICU';
/* 5383 (MICU) */
select count(distinct(v.subject_id)) from pat_tidal_volume v inner join pat_first_service s on v.hadm_id = s.hadm_id and s.services not in ('CSURG', 'NSURG', 'PSURG', 'SURG', 'TSURG', 'VSURG') where v.first_careunit = 'CCU';
/* 1779 (CCU) */
select count(distinct(v.hadm_id)) from pat_tidal_volume v inner join pat_first_service s on v.hadm_id = s.hadm_id and s.services not in ('CSURG', 'NSURG', 'PSURG', 'SURG', 'TSURG', 'VSURG') where v.first_careunit = 'CCU';
/* 1822 (CCU) */

/* calculate BMI for each admission */
select distinct(label) from d_items where category = 'General';   
-- itemid =920, 1394, 226707 for Height (Inch)  226730 (cm)
-- itemid = 762, 226531 for Admission Weight (lbs)
-- BMI = weight(lbs) / [height(inch)]^2 * 703
drop table if exists temp1;
drop table if exists temp2;
drop table if exists temp3;
create table temp1 as 
select * from chartevents where itemid in (920, 1394, 226707, 226730);

create table temp2 as 
select subject_id, hadm_id, charttime, 
	   case 
	  	   when itemid = 762 then round(cast(valuenum * 2.2046 as numeric), 1)
	  	   when itemid = 226531 then valuenum
	   end as weight, itemid from chartevents where itemid in (762, 226531) and valuenum is not null;
select * from temp2 order by subject_id;	
/* create a table for height */

drop table if exists pat_height;
create table pat_height as 
	select subject_id, hadm_id,
	   case 
	   	   when itemid = 226730 then round(valuenum * 0.394) -- cm
	   	   when itemid in (920, 1394, 226707) then valuenum  -- inches
	   end as height, itemid from chartevents where itemid in (920, 226730, 1394, 226707) and valuenum is not null
	  order by subject_id, hadm_id;

select count(distinct(subject_id)) from pat_height;   /* 21170 patients in total have the record for height */
select count(distinct(hadm_id)) from pat_height;      /* 24319 admissions in total have the record for height */
select * from pat_height;

/* remove duplicate*/
alter table pat_height add column row_id serial;
delete from
	   pat_height a using 
	   pat_height b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id;
alter table pat_height drop column row_id;

/* create a table for weight */
drop table if exists temp3;
create table temp3 as 
	select t.hadm_id, t.charttime, temp2.weight from temp2
	inner join (select hadm_id, min(charttime) as charttime from temp2
	group by hadm_id) as t
	on temp2.hadm_id = t.hadm_id
	where extract(month from temp2.charttime) = extract(month from t.charttime) and 
		  extract(day from temp2.charttime) = extract(day from t.charttime);

drop table if exists pat_weight;
create table pat_weight as 
	select adm.subject_id, temp3.* from admissions adm
	inner join temp3
	on adm.hadm_id = temp3.hadm_id;

select count(distinct(subject_id)) from pat_weight;   /* 31728 */
select count(distinct(hadm_id)) from pat_weight;      /* 38636 */
select count(*) from pat_weight;   /* 46927 exists duplicates */

/* remove duplicate*/
alter table pat_weight add column row_id serial;
delete from
	   pat_weight a using 
	   pat_weight b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id;
alter table pat_weight drop column row_id;

drop table if exists pat_bmi;
create table pat_bmi as
	select w.subject_id, 
		   w.hadm_id, 
		   w.weight, 
		   h.height,
		   round((w.weight/h.height^2)*703) as BMI from pat_weight w
	inner join pat_height h
	on w.hadm_id = h.hadm_id
	where height != 0 and weight is not null
	order by subject_id;
/* remove duplicate rows */
alter table pat_bmi add column row_id serial;
delete from 
	   pat_bmi a using 
	   pat_bmi b where a.row_id > b.row_id and a.hadm_id = b.hadm_id;

alter table pat_bmi drop column row_id;

select * from pat_bmi;
select count(distinct(subject_id)) from pat_bmi;   /* 20697 */
select count(distinct(hadm_id)) from pat_bmi;      /* 23660 */

/* issue: weights maybe different even in a day's measurement at different time point. admission day */
with demographics as 
(
select adult.subject_id, 
	   adult.hadm_id,
	   adult.age,
	   adult.gender,
	   adult.hospital_expire_flag,
	   td.first_careunit as location,
	   td.tidal_volume
	   from pat_tidal_volume td
inner join adult_info adult
on td.hadm_id = adult.hadm_id
)
select * from demographics;

with avgTidalVolume as 
(
	select hadm_id, avg(tidal_volume) from pat_tidal_volume
	group by hadm_id;
),
avgWBC as 
(
	select hadm_id, avg(valuenum) from m_wbc
	group by hadm_id;
),
avgBUN as    		   -- BUN
(
	select hadm_id, avg(valuenum) from m_bun
	group by hadm_id;
),
avgRR as 				-- Respiratory Rate
(
	select hadm_id, avg(valuenum) from m_rr   -- should I remove flag = abnormal?
	group by hadm_id;
),
avgBilirubin as 
(
	select hadm_id, avg(valuenum) from m_bilirubin
	group by hadm_id;
)