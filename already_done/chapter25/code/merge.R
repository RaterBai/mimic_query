# merge all useful information together
# and get the final result

# import data
# 1. aki_info.csv, should be merged together with aki_area, and whether hypotension, defined as <= 60
aki_info_raw <- read.csv("./Desktop/MIMIC-III/already_done/chapter25/data/aki_info.csv")
aki_all <- merge(aki_info_raw, aki_area, by = 'subject_id')
aki_all <- merge(aki_all, aki_hypotension[-2], by = 'subject_id')
aki_all <- aki_all[c(-4, -5, -18)]
aki_all['aki'] = 1
View(aki_all)
head(aki_all)


#2. non_aki_info.csv, should be merged together with non_aki_area
non_aki_info_raw <- read.csv("./Desktop/MIMIC-III/already_done/chapter25/data/non_aki_info.csv")
non_aki_all <- merge(non_aki_info_raw, non_aki_area, by = 'subject_id')
non_aki_all <- merge(non_aki_all, non_aki_hypotension[-2], by = 'subject_id')
non_aki_all <- non_aki_all[c(-4, -5, -18)]
non_aki_all['aki'] = 0
head(non_aki_all)

final_result <- rbind(aki_all, non_aki_all)
View(final_result)

colnames(final_result)
# append bmi to the final result 
bmi <- read.csv("./Desktop/MIMIC-III/already_done/chapter25/data/bmi_icu.csv")
final_result <- merge(x = final_result, y = bmi, by = 'icustay_id', all.x = T)
final_result <- final_result[c(-18, -19)]

summary(final_result[final_result$aki == 1,])
summary(final_result[final_result$aki == 0,])
nrow(final_result[final_result$aki == 1,])
nrow(final_result[final_result$aki == 0,])
write.csv(final_result,"./Desktop/MIMIC-III/already_done/chapter25/data/final_result.csv", row.names = F, na = "")

summary(factor(final_result$severe_sepsis[final_result$aki == 0]))

head(arrange(final_result[final_result$aki == 1,], area))

t.test(final_result$area[final_result$aki == 1], final_result$area[final_result$aki == 0], var.equal = T)
