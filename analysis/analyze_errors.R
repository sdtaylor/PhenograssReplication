library(tidyverse)

all_predictions = read_csv('data/full_model_predictions.csv', 
                           col_types = cols(W=col_number(),
                                            gcc_observed = col_number(),
                                            fCover_observed = col_number(),
                                            Dt=col_number()))

all_predictions = all_predictions %>%
  filter(model %in% c('PhenoGrass','NaiveMAPCorrected'))

site_errors = all_predictions %>%
  group_by(fitting_set, model, timeseries_id) %>%
  summarise(daily_rmse = sqrt(mean( (fCover_observed - fCover_predicted)^2 ,na.rm=T)),
            daily_r2   = 1  - sum((fCover_observed - fCover_predicted)^2,na.rm=T) / sum((fCover_observed - mean(fCover_observed,na.rm=T))^2,na.rm=T),
            n=n(),
            percent_na=mean(is.na(fCover_observed))) %>%
  ungroup() 

primary_errors = site_errors %>%
  filter(model == 'PhenoGrass') %>% # just the phenograss model in the primary things. naive errors will be in supplement
  group_by(fitting_set, model) %>%
  summarise(daily_rmse = round(mean(daily_rmse),2),
            daily_r2 =   round(mean(daily_r2),2),
            n_timeseries = n_distinct(timeseries_id)) %>%
  ungroup()

# add in site years
fitting_set_info = read_csv('model_fitting_set_info/fitting_sets.csv') %>%
  select(model_fitting_sets, site_years = total_site_years)

primary_errors = primary_errors %>%
  left_join(fitting_set_info, by=c('fitting_set'='model_fitting_sets'))

write_csv(primary_errors,'results/primary_error_table.csv')
write_csv(site_errors, 'results/site_level_error_table.csv')
