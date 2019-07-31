/* create a table for height */
drop table if exists pat_height;
create table pat_height as 
	select subject_id, hadm_id,
	   case 
	   	   when itemid = 226730 then round(valuenum * 0.394) -- cm
	   	   when itemid in (920, 1394, 226707) then valuenum  -- inches
	   end as height, itemid from chartevents where itemid in (920, 226730, 1394, 226707) and valuenum is not null and valuenum != 0
	  order by subject_id, hadm_id;

select count(distinct(subject_id)) from pat_height;   /* 21152 patients in total have the record for height */
select count(distinct(hadm_id)) from pat_height;      /* 24294 admissions in total have the record for height */

/* remove duplicate*/
alter table pat_height add column row_id serial;
delete from
	   pat_height a using 
	   pat_height b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id;
alter table pat_height drop column row_id;

drop table if exists pat_weight;
create table pat_weight as 
	select subject_id, hadm_id, charttime,
	   case 
	   	   when itemid in (762, 763, 226512, 224639) then round(valuenum * 2.2046) -- kg (226512 - Admit Wt, 224639 - Daily Wt)
	   	   when itemid = 226531 then valuenum  -- lbs (762, 226531) -- Admit Wt, 763 - daily weight 
	   end as weight, itemid from chartevents where itemid in (762, 763, 226531, 226512, 224639) and valuenum is not null
	  order by subject_id, hadm_id, charttime;
	  
select * from pat_weight;
select count(distinct(subject_id)) from pat_weight;   /* 36239 patients in total have the record for height */
select count(distinct(hadm_id)) from pat_weight;      /* 45749 admissions in total have the record for height */

drop table if exists pat_bmi;
create table pat_bmi as
	select w.subject_id, 
		   w.hadm_id, 
		   w.weight, 
		   h.height,
		   w.charttime,
		   round((w.weight/h.height^2)*703) as BMI from pat_weight w
	inner join pat_height h
	on w.hadm_id = h.hadm_id
	where height != 0 and weight is not null
	order by subject_id, hadm_id, charttime;
	
select count(distinct(subject_id)) from pat_bmi;  /* 21138 */
select count(distinct(hadm_id)) from pat_bmi;     /* 24278 */