library(tidyverse)

###########
#Get average errors for the leave 1 out CV
###########

cv_predictions = read_csv('data/cv_model_predictions.csv',
                          col_types = cols(W=col_number(),
                                           gcc_observed = col_number(),
                                           Dt=col_number()))

site_level_errors = cv_predictions %>%
  group_by(fitting_set, model, left_out_timeseries) %>%
  summarise(cvmae = mean(abs(gcc_observed - gcc_predicted), na.rm=T)/mean(gcc_observed, na.rm=T) ,
            nse   = 1  - sum((gcc_observed - gcc_predicted)^2,na.rm=T) / sum((gcc_observed - mean(gcc_observed,na.rm=T))^2,na.rm=T),
            n=n(),
            n_timeseries = n_distinct(timeseries_id),
            percent_na=mean(is.na(gcc_observed))) %>%
  ungroup()

# Each site level error should only have 1 site in its calculation
assertthat::assert_that(all(site_level_errors$n_timeseries==1), msg='>1 timeseries found in leave 1 out CV predictions')

site_level_errors %>%
  group_by(fitting_set, model) %>%
  summarise(avg_nse = mean(nse),
            mean_cvmae = mean(cvmae),
            n_sites = n()) %>%
  ungroup()
  