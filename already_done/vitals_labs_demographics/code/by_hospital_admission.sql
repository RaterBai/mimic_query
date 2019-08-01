with first_adm_time as 
(
	select subject_id, min(admittime) from admissions group by subject_id
), first_adm as 
(
	select adm.subject_id, 
		   adm.hadm_id 
	from first_adm_time first
	inner join admissions adm
	on first.subject_id = adm.subject_id and first.min = adm.admittime
), last_adm_time as 
(
	select subject_id, max(admittime) from admissions group by subject_id
), last_adm as 
(
	select adm.subject_id, 
		   adm.hadm_id 
	from last_adm_time last
	inner join admissions adm
	on last.subject_id = adm.subject_id and last.max = adm.admittime
), vitals as 
(
	select subject_id, hadm_id, charttime, itemid, value, valuenum from chartevents 
	where itemid in (
				 51, --	Arterial BP [Systolic]
  				 442, --	Manual BP [Systolic]
                 455, --	NBP [Systolic]
                 6701, --	Arterial BP #2 [Systolic]
                 220179, --	Non Invasive Blood Pressure systolic
                 220050, --	Arterial Blood Pressure systolic
                 
                 8368, --	Arterial BP [Diastolic]
  				 8440, --	Manual BP [Diastolic]
  			 	 8441, --	NBP [Diastolic]
  				 8555, --	Arterial BP #2 [Diastolic]
  				 220180, --	Non Invasive Blood Pressure diastolic
  				 220051, --	Arterial Blood Pressure diastolic
  				 
  				 456, --"NBP Mean"
  				 52, --"Arterial BP Mean"
 				 6702, --	Arterial BP Mean #2
 				 443, --	Manual BP Mean(calc)
 				 220052, --"Arterial Blood Pressure mean"
 				 220181, --"Non Invasive Blood Pressure mean"
 				 225312, --"ART BP mean"
 				 
  				 618,--	Respiratory Rate
  				 615,--	Resp Rate (Total)
 				 220210,--	Respiratory Rate
 				 224690, --	Respiratory Rate (Total)
 				 
 				 223762, -- "Temperature Celsius"
 				 676,	-- "Temperature C"
 				 223761, -- "Temperature Fahrenheit"
 				 678, --	"Temperature F"
 				 
 				 211, 22045, -- "Heartrate"
 				 
 				 226104, -- "Consciousness"
 				 
 				 646,220277, -- "Spo2"
				 807,811,1529,3745,3744,225664,220621,226537 -- "Glucose"
)
	
	union 
	select subject_id, hadm_id, charttime, itemid, value, valuenum from labevents 
	where itemid = 50817 -- oxygen_saturation
), tagged_vitals as (
	select subject_id, hadm_id, charttime, 
		case when itemid in (223761,678) then (valuenum-32)/1.8 else valuenum end as valuenum,
		case when itemid in (223761,678) then to_char((valuenum-32)/1.8, '9999999') else value end as value,
		case 
			when itemid in (211,220045) and valuenum > 0 and valuenum < 300 then 'HR' -- HeartRate
			when itemid in (51,442,455,6701,220179,220050) and valuenum > 0 and valuenum < 400 then 'SysBP' -- SysBP
			when itemid in (8368,8440,8441,8555,220180,220051) and valuenum > 0 and valuenum < 300 then 'DiasBP' -- DiasBP
			when itemid in (456,52,6702,443,220052,220181,225312) and valuenum > 0 and valuenum < 300 then 'MeanBP' -- MeanBP
			when itemid in (615,618,220210,224690) and valuenum > 0 and valuenum < 70 then 'RR' -- RespRate
			when itemid in (223761,678) and valuenum > 70 and valuenum < 120  then 'Temp' -- TempF, converted to degC in valuenum call
			when itemid in (223762,676) and valuenum > 10 and valuenum < 50  then 'Temp' -- TempC
			when itemid in (646,220277) and valuenum > 0 and valuenum <= 100 then 'SpO2' -- SpO2
			when itemid in (807,811,1529,3745,3744,225664,220621,226537) and valuenum > 0 then 'Glucose' -- Glucose
			when itemid = 226104 then 'Consciousness'
			when itemid = 50817 then 'Oxygen Saturation'
		else null end as tag 
		from vitals
) select tag.* from tagged_vitals tag
inner join last_adm adm
on tag.hadm_id = adm.hadm_id
where tag is not null
order by subject_id, hadm_id, tag, charttime


with first_adm_time as 
(
	select subject_id, min(admittime) from admissions group by subject_id
), first_adm as 
(
	select adm.subject_id, 
		   adm.hadm_id 
	from first_adm_time first
	inner join admissions adm
	on first.subject_id = adm.subject_id and first.min = adm.admittime
), last_adm_time as 
(
	select subject_id, max(admittime) from admissions group by subject_id
), last_adm as 
(
	select adm.subject_id, 
		   adm.hadm_id 
	from last_adm_time last
	inner join admissions adm
	on last.subject_id = adm.subject_id and last.max = adm.admittime
),
labevents as 
(
	select subject_id, hadm_id, charttime, itemid, value, valuenum from labevents 
	where itemid in (
					50818, -- pCO2 | BLOOD GAS | BLOOD | 19
					50820, -- PH | BLOOD GAS | BLOOD | 21
					50878, -- AST (Asparate aminotransferase) | CHEMISTRY | BLOOD | 79
					50868, -- ANION GAP | CHEMISTRY | BLOOD | 769895
      				50862, -- ALBUMIN | CHEMISTRY | BLOOD | 146697
					50882, -- BICARBONATE | CHEMISTRY | BLOOD | 780733 
					50885,-- BILIRUBIN, TOTAL | CHEMISTRY | BLOOD | 238277
					50912, -- CREATININE | CHEMISTRY | BLOOD | 797476
					50902, -- CHLORIDE | CHEMISTRY | BLOOD | 795568
      			 	50806, -- CHLORIDE, WHOLE BLOOD | BLOOD GAS | BLOOD | 48187
					51221, -- HEMATOCRIT | HEMATOLOGY | BLOOD | 881846
      			 	50810, -- HEMATOCRIT, CALCULATED | BLOOD GAS | BLOOD | 89715
      			 	51222, -- HEMOGLOBIN | HEMATOLOGY | BLOOD | 752523
      				50811, -- HEMOGLOBIN | BLOOD GAS | BLOOD | 89712
      			 	50813, -- LACTATE | BLOOD GAS | BLOOD | 187124
      			 	51265, -- PLATELET COUNT | HEMATOLOGY | BLOOD | 778444
      			 	50971, -- POTASSIUM | CHEMISTRY | BLOOD | 845825
      			 	50822, -- POTASSIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 192946
      			 	50983, -- SODIUM | CHEMISTRY | BLOOD | 808489
     			 	50824, -- SODIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 71503
      			 	51006, -- UREA NITROGEN | CHEMISTRY | BLOOD | 791925
      			 	51301, -- WHITE BLOOD CELLS | HEMATOLOGY | BLOOD | 753301
     			 	51300, -- WBC COUNT | HEMATOLOGY | BLOOD | 2371
     			 	50960  -- MAGNESIUM
      			 	)
), tagged_labevents as (
	select subject_id, hadm_id, charttime, valuenum,
		case 
			when itemid = 50862 and valuenum <= 10 then 'Albumin' -- g/dL 'ALBUMIN'
			when itemid = 50868 and valuenum <= 10000 then 'Anion Gap' -- mEq/L 'ANION GAP'
			when itemid = 50882 and valuenum <= 10000 then 'Bicarbonate' -- mEq/L 'BICARBONATE'
			when itemid = 50885 and valuenum <= 150 then 'Bilirubin' -- mg/dL 'BILIRUBIN'
			when itemid in (50806, 50902) and valuenum <= 10000 then 'Chloride' -- mEq/L 'CHLORIDE'
			when itemid = 50912 and valuenum <= 150 then 'Creatinine' -- mg/dL 'CREATININE'
			when itemid in (50810, 51221) and valuenum <= 100 then 'Hematocrit' -- % 'HEMATOCRIT'
			when itemid = 50811 and valuenum <= 50 then 'Hemoglobin' -- g/dL 'HEMOGLOBIN'
      		when itemid = 51222 and valuenum <= 50 then 'Hemoglobin' -- g/dL 'HEMOGLOBIN'
     		when itemid = 50813 and valuenum <= 50 then 'Lactate' -- mmol/L 'LACTATE'
      		when itemid = 51265 and valuenum <= 10000 then 'Platelet' -- K/uL 'PLATELET'
      		when itemid = 50822 and valuenum <= 30 then 'Potassium' -- mEq/L 'POTASSIUM'
      		when itemid = 50971 and valuenum <= 30 then 'Potassium'-- mEq/L 'POTASSIUM'
      		when itemid = 50824 and valuenum <= 200 then 'Sodium'-- mEq/L == mmol/L 'SODIUM'
      		when itemid = 50983 and valuenum <= 200 then 'Sodium'-- mEq/L == mmol/L 'SODIUM'
      		when itemid = 51006 and valuenum <= 300 then 'BUN'-- 'BUN'
      		when itemid = 51300 and valuenum <= 1000 then 'WBC'-- 'WBC'
      		when itemid = 51301 and valuenum <= 1000 then 'WBC'-- 'WBC'
			else null end as tag 
		from labevents
) select tag.* from tagged_labevents tag
inner join last_adm adm
on tag.hadm_id = adm.hadm_id
where tag is not null
order by subject_id, hadm_id, tag, charttime