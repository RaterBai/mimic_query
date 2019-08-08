-- first measurement of the last ICU stay
with last_icu_time as 
(
	select subject_id, max(intime) from icustays group by subject_id
), last_icu as 
(
	select icu.subject_id, 
		   icu.hadm_id,
		   icu.icustay_id,
		   intime, 
		   outtime
	from last_icu_time last
	inner join icustays icu
	on last.subject_id = icu.subject_id and last.max = icu.intime
), sysbp as 
(
	select distinct
		   ce.subject_id, 
		   ce.hadm_id, 
		   ce.icustay_id,
		   first_value(ce.valuenum) over (partition by ce.icustay_id order by ce.charttime) as valuenum
	from chartevents ce
	--inner join last_icu icu
	--on ce.icustay_id = icu.icustay_id
	where itemid in (
				 51, --	Arterial BP [Systolic]
  				 442, --	Manual BP [Systolic]
                 6701, --	Arterial BP #2 [Systolic]
                 220050, --	Arterial Blood Pressure systolic
                 455, --	NBP [Systolic]
				 220179 --	Non Invasive Blood Pressure systolic
                 ) and valuenum > 0 and valuenum < 400 and icustay_id is not null and hadm_id is not null
), diasbp as 
(
	select distinct
		   ce.subject_id, 
		   ce.hadm_id, 
		   ce.icustay_id,
		   first_value(ce.valuenum) over (partition by ce.subject_id, ce.hadm_id, ce.icustay_id order by ce.charttime) as valuenum
	from chartevents ce
	where itemid in (
				 8368, --	Arterial BP [Diastolic]
  				 8440, --	Manual BP [Diastolic]
  				 8555, --	Arterial BP #2 [Diastolic]
  				 220051, --	Arterial Blood Pressure diastolic
  				 8441, --	NBP [Diastolic]
				 220180 --	Non Invasive Blood Pressure diastolic
                 ) and valuenum > 0 and valuenum < 300 and icustay_id is not null and hadm_id is not null
), meanbp as 
(
	select distinct
		   ce.subject_id, 
		   ce.hadm_id, 
		   ce.icustay_id,
		   first_value(ce.valuenum) over (partition by ce.subject_id, ce.hadm_id, ce.icustay_id order by ce.charttime) as valuenum
	from chartevents ce
	where itemid in (
				 52, --"Arterial BP Mean"
 				 6702, --	Arterial BP Mean #2
 				 443, --	Manual BP Mean(calc)
 				 220052, --"Arterial Blood Pressure mean"
 				 225312, --"ART BP mean"
 				 456, --"NBP Mean"
  				 220181 --"Non Invasive Blood Pressure mean"
                 ) and valuenum > 0 and valuenum < 300 and icustay_id is not null and hadm_id is not null
), heartrate as 
(
	select distinct
		   ce.subject_id, 
		   ce.hadm_id, 
		   ce.icustay_id,
		   first_value(ce.valuenum) over (partition by ce.subject_id, ce.hadm_id, ce.icustay_id order by ce.charttime) as valuenum
	from chartevents ce
	where itemid in (
  				  	211, 22045 -- "Heartrate"
                 ) and valuenum > 0 and valuenum < 300 and icustay_id is not null and hadm_id is not null
), spo2 as 
(
	select distinct
		   ce.subject_id, 
		   ce.hadm_id, 
		   ce.icustay_id,
		   first_value(ce.valuenum) over (partition by ce.subject_id, ce.hadm_id, ce.icustay_id order by ce.charttime) as valuenum
	from chartevents ce
	where itemid in (
  				  	646,220277 -- "Spo2"
                 ) and valuenum > 0 and valuenum <= 100 and icustay_id is not null and hadm_id is not null
), resprate as 
(
	select distinct
		   ce.subject_id, 
		   ce.hadm_id, 
		   ce.icustay_id,
		   first_value(ce.valuenum) over (partition by ce.subject_id, ce.hadm_id, ce.icustay_id order by ce.charttime) as valuenum
	from chartevents ce
	where itemid in (
  				 618,--	Respiratory Rate
  				 615,--	Resp Rate (Total)
 				 220210,--	Respiratory Rate
 				 224690 --	Respiratory Rate (Total)
                 ) and valuenum > 0 and valuenum < 70 and icustay_id is not null and hadm_id is not null
), temperature_modify as 
(
	select ce.subject_id,
		   ce.hadm_id,
		   ce.icustay_id,
		   ce.charttime,
		   case 
		   		when itemid in (223761,678) and valuenum > 70 and valuenum < 120 then (valuenum-32)/1.8 
		   		when itemid in (223762,676) and valuenum > 10 and valuenum < 50 then valuenum 
		   		else null end as valuenum
		   from chartevents ce
		   where itemid in (
  				 223762, -- "Temperature Celsius"
 				 676,	-- "Temperature C"
 				 223761, -- "Temperature Fahrenheit"
 				 678 --	"Temperature F"
                 ) and icustay_id is not null and hadm_id is not null
), temperature as 
(
	select distinct
		   t.subject_id,
		   t.hadm_id,
		   t.icustay_id,
		   first_value(valuenum) over (partition by t.subject_id, t.hadm_id, t.icustay_id order by t.charttime) as valuenum
	from temperature_modify t
), consciousness as 
(
	select distinct
		   ce.subject_id, 
		   ce.hadm_id, 
		   ce.icustay_id,
		   first_value(ce.value) over (partition by ce.subject_id, ce.hadm_id, ce.icustay_id order by ce.charttime) as value
	from chartevents ce
	where itemid in (
  				  226104 -- "Consciousness"
                 ) and icustay_id is not null and hadm_id is not null
), sodium as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					50983, -- SODIUM | CHEMISTRY | BLOOD | 808489
     			 	50824 -- SODIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 71503
     			 	) and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and valuenum <= 200  and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), potassium as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					50971, -- POTASSIUM | CHEMISTRY | BLOOD | 845825
      			 	50822 -- POTASSIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 192946
     			 	) and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and valuenum <= 30  and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), bicarbonate as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					50882 -- BICARBONATE | CHEMISTRY | BLOOD | 780733
     			 	) and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and valuenum <= 10000  and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), aniongap as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					50868 -- ANION GAP | CHEMISTRY | BLOOD | 769895
     			 	) and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and valuenum <= 10000 and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), bun as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					51006 -- UREA NITROGEN | CHEMISTRY | BLOOD | 791925
     			 	) and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and valuenum <= 300 and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), creatinine as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					50912 -- CREATININE | CHEMISTRY | BLOOD | 797476
     			 	) and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and valuenum <= 150 and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), glucose as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					50931, -- GLUCOSE | CHEMISTRY | BLOOD | 748981
      				50809 -- GLUCOSE | BLOOD GAS | BLOOD | 196734
     			 	) and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), calcium as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					50893, -- | Calcium Total | Blood
					50808  -- | Free Calcisum | Blood
     			 	) and (labs.charttime between icu.intime and icu.outtime) and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), wbc as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					51301, -- WHITE BLOOD CELLS | HEMATOLOGY | BLOOD | 753301
					51300 -- WBC COUNT | HEMATOLOGY | BLOOD | 2371
     			 	) and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and valuenum <= 1000 and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), hemoglobin as
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid in (
					51222, -- HEMOGLOBIN | HEMATOLOGY | BLOOD | 752523
      				50811 -- HEMOGLOBIN | BLOOD GAS | BLOOD | 89712
     			 	) and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and valuenum <= 50 and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), pco2 as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid = 50818 and (labs.charttime between icu.intime and icu.outtime) and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), albumin as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid = 50862 -- ALBUMIN | CHEMISTRY | BLOOD | 146697 
		  and (labs.charttime between icu.intime and icu.outtime) and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), bilirubin as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid = 50885-- BILIRUBIN, TOTAL | CHEMISTRY | BLOOD | 238277
		  and (labs.charttime between icu.intime and icu.outtime) and valuenum > 0 and valuenum <= 150 and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), ast as
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid = 50878 -- AST (Asparate aminotransferase) | CHEMISTRY | BLOOD | 79
		  and (labs.charttime between icu.intime and icu.outtime) and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
), aterialph as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid = 50820 -- PH | BLOOD GAS | BLOOD | 21
		  and (labs.charttime between icu.intime and icu.outtime) and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
),
oxygen_saturation as 
(
	select distinct
		   icu.subject_id,
		   icu.hadm_id,
		   icu.icustay_id,
		   first_value(valuenum) over (partition by icu.icustay_id order by labs.charttime) as valuenum
	from labevents labs
	inner join last_icu icu 
	on labs.hadm_id = icu.hadm_id
	where labs.itemid = 50817 -- oxygen_saturation
		  and (labs.charttime between icu.intime and icu.outtime) and icustay_id is not null and labs.hadm_id is not null
    order by icu.subject_id, icu.hadm_id, icu.icustay_id
)
select pat.subject_id,
	   adm.hadm_id,
	   icu.icustay_id,
	   pat.gender,
	   case 
      		when round( ( cast(icu.intime as date) - cast(pat.dob as date) ) / 365.242 , 2 ) >= 150 then 91.4
      		else round( ( cast(icu.intime as date) - cast(pat.dob as date) ) / 365.242 , 2 )
       end as age,
       sysbp.valuenum as sysbp,
       diasbp.valuenum as diasbp,
       meanbp.valuenum as meanbp,
       heartrate.valuenum as heartrate,
       spo2.valuenum as spo2,
       resprate.valuenum as resprate,
       temp.valuenum as temperature,
       consciousness.value as consciousness,
       sodium.valuenum as sodium,
       potassium.valuenum as potassium,
       bicarbonate.valuenum as bicarbonate,
       aniongap.valuenum as aniongap,
       bun.valuenum as bun,
       creatinine.valuenum as creatinine,
       glucose.valuenum as glucose,
       calcium.valuenum as calcium,
       wbc.valuenum as wbc,
       hemoglobin.valuenum as hemoglobin,
       pco2.valuenum as pco2,
       albumin.valuenum as albumin,
       bilirubin.valuenum as bilirubin,
       ast.valuenum as ast,
       aterialph.valuenum as aterialph,
       oxygen_saturation.valuenum as oxygen_saturation,
       icu_death.expire_flag as icu_death,
       icu_death_within_24.expire_flag as icu_death_within_24
from last_icu icu
inner join patients pat
on icu.subject_id = pat.subject_id
inner join admissions adm
on icu.hadm_id = adm.hadm_id
left join sysbp
on sysbp.icustay_id = icu.icustay_id and sysbp.hadm_id = icu.hadm_id
left join diasbp
on diasbp.icustay_id = icu.icustay_id and diasbp.hadm_id = icu.hadm_id
left join meanbp 
on meanbp.icustay_id = icu.icustay_id and meanbp.hadm_id = icu.hadm_id
left join heartrate
on heartrate.icustay_id = icu.icustay_id and heartrate.hadm_id = icu.hadm_id
left join spo2
on spo2.icustay_id = icu.icustay_id and spo2.hadm_id = icu.hadm_id
left join resprate
on resprate.icustay_id = icu.icustay_id and resprate.hadm_id = icu.hadm_id
left join temperature temp
on temp.icustay_id = icu.icustay_id and temp.hadm_id = icu.hadm_id
left join consciousness
on consciousness.icustay_id = icu.icustay_id and consciousness.hadm_id = icu.hadm_id
left join sodium
on sodium.hadm_id = icu.hadm_id and sodium.icustay_id = icu.icustay_id
left join potassium
on potassium.hadm_id = icu.hadm_id and potassium.icustay_id = icu.icustay_id
left join bicarbonate
on bicarbonate.hadm_id = icu.hadm_id and bicarbonate.icustay_id = icu.icustay_id
left join aniongap
on aniongap.hadm_id = icu.hadm_id and aniongap.icustay_id = icu.icustay_id
left join bun
on bun.hadm_id = icu.hadm_id and bun.icustay_id = icu.icustay_id
left join creatinine 
on creatinine.icustay_id = icu.icustay_id and creatinine.hadm_id = icu.hadm_id
left join glucose 
on glucose.icustay_id = icu.icustay_id and glucose.hadm_id = icu.hadm_id
left join calcium
on calcium.icustay_id = icu.icustay_id and calcium.hadm_id = icu.hadm_id
left join wbc
on wbc.icustay_id = icu.icustay_id and wbc.hadm_id = icu.hadm_id
left join hemoglobin
on hemoglobin.icustay_id = icu.icustay_id and hemoglobin.hadm_id = icu.hadm_id
left join pco2
on pco2.icustay_id = icu.icustay_id and pco2.hadm_id = icu.hadm_id
left join albumin
on albumin.icustay_id = icu.icustay_id and albumin.hadm_id = icu.hadm_id
left join bilirubin
on bilirubin.icustay_id = icu.icustay_id and bilirubin.hadm_id = icu.hadm_id
left join ast
on ast.icustay_id = icu.icustay_id and ast.hadm_id = icu.hadm_id
left join aterialph
on aterialph.icustay_id = icu.icustay_id and aterialph.hadm_id = icu.hadm_id
left join oxygen_saturation
on oxygen_saturation.icustay_id = icu.icustay_id and oxygen_saturation.hadm_id = icu.hadm_id
left join icu_death
on icu_death.icustay_id = icu.icustay_id
left join icu_death_within_24
on icu_death_within_24.icustay_id = icu.icustay_id;


