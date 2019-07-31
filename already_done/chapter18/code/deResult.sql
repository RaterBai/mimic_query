-- Generate final result for chapter18
select adult.subject_id, 
	   adult.hadm_id,
	   adult.gender,
	   adult.ethnicity, 
	   adult.admittime,
	   case 
	   	   when adult.age >= 300 then 91.4 -- median of age > 89
	   	   else adult.age
	   end as age,
	   f.first_careunit as location,
	   tbl.*
	   from adult_info adult
inner join combined_tbl tbl
on adult.hadm_id = tbl.hadm_id
inner join first_careunit f
on adult.hadm_id = f.hadm_id;