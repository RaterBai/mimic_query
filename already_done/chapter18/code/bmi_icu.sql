drop table if exists bmi_icu;
create table bmi_icu as
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
)select subject_id, 
	    hadm_id, 
	    icustay_id, 
	    round(cast(weight/(height/100)^2 as numeric), 2) as bmi 
	    from info where height is not null and weight is not null;

select count(distinct(hadm_id)) from bmi_icu;