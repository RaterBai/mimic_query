-- Generate some measurements and observations for chapter18
-- hr, rr, diasbp, meanbp, spo2, sysbp, temp

drop table if exists all_hr;   -- contains subjects from carevue and metavision
create table all_hr as( 
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join adult_info pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where chart.itemid in (211, 220045)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

alter table all_hr add column row_id serial;
delete from
	   all_hr a using 
	   all_hr b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table all_hr drop column row_id;

select count(distinct(hadm_id)) from all_hr;   /*37990*/

/* Resp Rate  within the 24 hours after taking into icu*/
drop table if exists all_rr;
create table all_rr as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join adult_info pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where chart.itemid in (615,618,220210,224690)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table all_rr add column row_id serial;
delete from
	   all_rr a using 
	   all_rr b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table all_rr drop column row_id;
 
select count(distinct(subject_id)) from all_rr;   /* 37973 */

/* SysBP within the 24 hours after taking into icu*/
drop table if exists all_sysbp;
create table all_sysbp as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join adult_info pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where chart.itemid in (51,442,455,6701,220179,220050)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table all_sysbp add column row_id serial;
delete from
	   all_sysbp a using 
	   all_sysbp b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table all_sysbp drop column row_id;
 
select count(distinct(subject_id)) from all_sysbp;   /* 37987 */


/* DiasBP within the 24 hours after taking into icu*/
drop table if exists all_diasbp;
create table all_diasbp as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join adult_info pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where chart.itemid in (8368,8440,8441,8555,220180,220051)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table all_diasbp add column row_id serial;
delete from
	   all_diasbp a using 
	   all_diasbp b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table all_diasbp drop column row_id;
 
select count(distinct(subject_id)) from all_diasbp;   /* 37986 */

/* MeanBP within the 24 hours after taking into icu*/
drop table if exists all_meanbp;
create table all_meanbp as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join adult_info pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where chart.itemid in (456,52,6702,443,220052,220181,225312)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table all_meanbp add column row_id serial;
delete from
	   all_meanbp a using 
	   all_meanbp b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table all_meanbp drop column row_id;
 
select count(distinct(subject_id)) from all_meanbp;   /* 37987 */


/* Temperature within the 24 hours after taking into icu*/
drop table if exists all_temp;
create table all_temp as (
select pat.*, f.intime, chart.charttime, 
	   case when chart.itemid in (223761, 678) then (valuenum-32)/1.8 else valuenum end as valuenum,
	   chart.error from chartevents chart
inner join adult_info pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where chart.itemid in (223761, 678, 223762, 676)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table all_temp add column row_id serial;
delete from
	   all_temp a using 
	   all_temp b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table all_temp drop column row_id;
 
select count(distinct(subject_id)) from all_temp;   /* 37143 */


/* SpO2 within the 24 hours after taking into icu*/
drop table if exists all_spo2;
create table all_spo2 as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join adult_info pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where chart.itemid in (646,220277)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table all_spo2 add column row_id serial;
delete from
	   all_spo2 a using 
	   all_spo2 b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table all_spo2 drop column row_id;
 
select count(distinct(subject_id)) from all_spo2;   /* 37804 */

/* Glucose within the 24 hours after taking into icu*/
drop table if exists all_glucose;
create table all_glucose as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join adult_info pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where chart.itemid in (807,811,1529,3745,3744,225664,220621,226537)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table all_glucose add column row_id serial;
delete from
	   all_glucose a using 
	   all_glucose b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table all_glucose drop column row_id;
 
select count(distinct(subject_id)) from all_glucose;   /* 37588 */

