-- Generate final result for chapter18
truncate table combined_tbl;

select adult.subject_id, 
	   adult.gender,
	   adult.ethnicity, 
	   adult.admittime,
	   adult.hospital_expire_flag,
	   case 
	   	   when adult.age >= 300 then 91.4 -- median of age > 89
	   	   else adult.age
	   end as age,
	   f.first_careunit as location,
	   tbl.*,
	   bmi.bmi
	   from adult_info adult
inner join combined_tbl tbl
on adult.hadm_id = tbl.hadm_id
inner join first_careunit f
on adult.hadm_id = f.hadm_id
left join bmi_hadm bmi
on bmi.hadm_id = adult.hadm_id
order by adult.subject_id;
