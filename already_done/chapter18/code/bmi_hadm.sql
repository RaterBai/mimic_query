drop table if exists bmi_hadm;
create table bmi_hadm as  -- bmi by hospitalization, take average of height, weight in each hospitalization
with info as 
(
select adm.subject_id, 
	   adm.hadm_id, 
	   icu.icustay_id,
	   height.height,
	   weight.weight from admissions adm
inner join icustays icu
on icu.hadm_id = adm.hadm_id
inner join heightfirstday height
on icu.icustay_id = height.icustay_id
inner join weightfirstday weight
on icu.icustay_id = weight.icustay_id
), avg_info as 
(
	select subject_id, 
		   hadm_id, 
		   avg(height) as height, 
		   avg(weight) as weight from info group by subject_id, hadm_id
), bmi as 
(
	select subject_id, hadm_id, round(cast(weight/(height/100)^2 as numeric), 2) as bmi from avg_info where height is not null and weight is not null
) select * from bmi;
 
select count(distinct(hadm_id)) from bmi_hadm; 