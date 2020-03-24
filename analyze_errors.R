library(tidyverse)



all_predictions = read_csv('data/full_model_precitions.csv', 
                           col_types = cols(W=col_number(),
                                            gcc_observed = col_number(),
                                            Dt=col_number()))




errors = all_predictions %>%
  group_by(fitting_set, model) %>%
  summarise(rmse = sqrt(mean( (gcc_observed - gcc_predicted)^2 ,na.rm=T)),
            r2   = 1  - sum((gcc_observed - gcc_predicted)^2,na.rm=T) / sum((gcc_observed - mean(gcc_observed,na.rm=T))^2,na.rm=T),
            #mae  = mean(abs(gcc_observed - gcc_predicted),na.rm=T),
            n=n(),
            n_timeseries = n_distinct(timeseries_id),
            percent_na=mean(is.na(gcc_observed))) %>%
  ungroup()


summary_table = errors %>%
  gather(error_metric, error_value, rmse, r2) %>%
  mutate(error_value = round(error_value, 3)) %>%
  spread(model, error_value) %>%
  mutate(scale = case_when(
    str_detect(fitting_set,'allsites') ~ 'All Sites',
    str_detect(fitting_set,'ecoregion-vegtype') ~ 'Within Ecoregion',
    str_detect(fitting_set,'ecoregion_') ~ 'Entire Ecoregion',
    str_detect(fitting_set,'vegtype_') ~ 'All Vegtype Sites',
    TRUE ~ 'unk scale'
  ))

summary_table$scale = fct_relevel(summary_table$scale, 'All Sites','All Vegtype Sites', 
                                  'Entire Ecoregion', 'Within Ecoregion')


summary_table %>%
  select(scale, everything()) %>%
  write_csv('error_table.csv')

######################################################################

select_timeseries = unique(all_predictions$timeseries_id)[45:55]
all_predictions %>%
  filter(model=='PhenoGrass') %>%
  filter(timeseries_id %in% select_timeseries) %>%
  ggplot(aes(x=gcc_predicted, y=gcc_observed)) + 
  geom_point() +
  geom_abline(slope=1, intercept=0, color='red') + 
  facet_wrap(timeseries_id~fitting_set)
