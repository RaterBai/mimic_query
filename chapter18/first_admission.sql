-- Select the first hospital admission for each patients.
with mintime as 
(
	select subject_id, min(admittime) 
	from final_result_chapter18 
	group by subject_id
)
select count(distinct(hadm_id)) from final_result_chapter18 f
inner join mintime
on mintime.subject_id = f.subject_id and mintime.min = f.admittime;
order by f.subject_id, f.hadm_id;

with mintime as 
(
	select subject_id, min(admittime) 
	from avg_tidalvolume 
	group by subject_id
)
select * from avg_tidalvolume avg
inner join mintime
on mintime.subject_id = avg.subject_id and mintime.min = avg.admittime
order by avg.subject_id, avg.hadm_id;

with mintime as 
(
	select subject_id, min(admittime) 
	from first_record 
	group by subject_id
)
select * from first_record first
inner join mintime
on mintime.subject_id = first.subject_id and mintime.min = first.admittime
order by first.subject_id, first.hadm_id;
