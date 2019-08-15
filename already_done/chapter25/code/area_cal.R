library(dplyr)
library(plyr)

aki <- read.csv("./Desktop/MIMIC-III/already_done/chapter25/data/meanbp_aki.csv")
non_aki <- read.csv("./Desktop/MIMIC-III/already_done/chapter25/data/meanbp_non_aki.csv")

non_aki_info <- aggregate(mintolastmeasurement~subject_id, non_aki, max)
aki_info <- aggregate(mintoakionset~subject_id, aki, max)
colnames(non_aki_info) <- c("subject_id", "maxValue")
colnames(aki_info) <- c("subject_id", "maxValue")

aki_hypotension <- aggregate(valuenum ~ subject_id, aki, min)
aki_hypotension['hypotension'] <- aki_hypotension$valuenum <= 60
aki_hypotension

non_aki_hypotension <- aggregate(valuenum ~ subject_id, non_aki, min)
non_aki_hypotension['hypotension'] <- non_aki_hypotension$valuenum <= 60
non_aki_hypotension

# number of patients had AKI and had MAP measurements more than 48 hours
sum(tapply(aki$mintoakionset, aki$subject_id, max)/60 >= 48)   # 2364
sum(tapply(non_aki$mintolastmeasurement, non_aki$subject_id, max)/60 >= 48)   # 9786

sum(tapply(aki$valuenum, aki$subject_id, min) <= 60)

table(aki_info$whetherH)   
# FALSE   TRUE  (80)
#  172    6694 (97.5%)

# FALSE   TRUE (70)
# 583     6283 (91.5%)

# FALSE   TRUE (60)
#  1816   5050 (73.5)

sum(tapply(non_aki$valuenum, non_aki$subject_id, min) <= 60)
table(non_aki_info$whetherH) 
# FALSE   TRUE  (80)
# 808    22011 (96.4%)

# FALSE   TRUE
# 3148    19660 (86%)

# FALSE   TRUE
# 9379    13429 (0.58878)

# Filter patients had AKI and more than 48 hours measurements
subject_id_aki <- aki_info$subject_id[aki_info$maxValue/60 >= 48]
subject_id_non_aki <- non_aki_info$subject_id[non_aki_info$maxValue/60 >= 48]

aki_area <- data.frame(subject_id = numeric(), area = numeric(), interval = numeric())
non_aki_area <- data.frame(subject_id = numeric(), area = numeric(), interval = numeric())

# calculate the area under the curve during the last 48h from aki onset
for(i in 1:length(subject_id_aki)) {
  total_area <- 0
  total_time <- 0
  measurements <- aki %>% filter(subject_id == subject_id_aki[i] & mintoakionset <= 48*60)
  # start from 2880
  for(j in 1:(nrow(measurements)+1)) {
    # the very first value
    if(j == 1){
      interval <- 2880 - measurements$mintoakionset[j]
      area <- interval * measurements$valuenum[j]
    }else if(j == length(measurements$mintoakionset)+1) { # the very last value
     interval <- measurements$mintoakionset[j-1]
     area <- interval * measurements$valuenum[j-1]
    }else {
      interval <- measurements$mintoakionset[j-1] - measurements$mintoakionset[j]
      area <- (measurements$valuenum[j] + measurements$valuenum[j-1])/2*interval
    } 
    total_time <- total_time + interval
    total_area <- total_area + area
  }
  print(i)
  print(subject_id_aki[i])
  newRec <- data.frame(subject_id = subject_id_aki[i], area = total_area, interval = total_time)
  print("-----")
  aki_area <- rbind(aki_area, newRec)
}

aki_area
# null values: 128      subject_id = 2446       NA       NA
# null values: 134      subject_id = 2530       NA       NA
#

#> min(aki_area$area, na.rm = T)
#[1] 144519
#> max(aki_area$area, na.rm = T)
#[1] 390382.5
#> mean(aki_area$area, na.rm = T)
#[1] 226581.9




#> summary(aki_area$area, na.rm = T)
#Min. 1st Qu.  Median    Mean 3rd Qu.    Max.    NAs 
# 144519  203245  222630  226582  245025  390382       2 

# calculate the area under the curve during the last 48h from non-aki 

for(i in 1:length(subject_id_non_aki)) {
  total_area <- 0
  total_time <- 0
  measurements <- non_aki %>% filter(subject_id == subject_id_non_aki[i] & mintolastmeasurement <= 48*60)
  # start from 2880
  for(j in 1:(nrow(measurements)+1)) {
    # the very first value
    if(j == 1){
      interval <- 2880 - measurements$mintolastmeasurement[j]
      area <- interval * measurements$valuenum[j]
    }else if(j == length(measurements$mintolastmeasurement)+1) { # the very last value
      interval <- measurements$mintolastmeasurement[j-1]
      area <- interval * measurements$valuenum[j-1]
    }else {
      interval <- measurements$mintolastmeasurement[j-1] - measurements$mintolastmeasurement[j]
      area <- (measurements$valuenum[j] + measurements$valuenum[j-1])/2*interval
    } 
    total_time <- total_time + interval
    total_area <- total_area + area
  }
  print(i)
  print(subject_id_non_aki[i])
  newRec <- data.frame(subject_id = subject_id_non_aki[i], area = total_area, interval = total_time)
  print("-----")
  non_aki_area <- rbind(non_aki_area, newRec)
}

non_aki_area
t.test(aki_area$area, non_aki_area$area, var.equal = TRUE, paired = FALSE)


measurements <- aki %>% filter(subject_id == 49164 & mintoakionset <= 60 * 48)
plot(y = measurements$valuenum, x = 0-measurements$mintoakionset)
measurements
