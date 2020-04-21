library(tidyverse)

all_predictions = read_csv('data/full_model_precitions.csv', 
                           col_types = cols(W=col_number(),
                                            gcc_observed = col_number(),
                                            Dt=col_number()))

# Setup a timeseries level climatology model as
# a naive model.
# # minimum 3 years for each day.
# phenocam_data = read_csv('data/processed_phenocam_data.csv') 
# 
# naive_model = phenocam_data %>%
#   group_by(timeseries_id, doy) %>%
#   summarise(gcc_predicted = mean(gcc, na.rm=T),
#             n=n()) %>%
#   ungroup() 
# 
# # Minimum 3 years of data
# # and only keep those timeseries which have actual phenograss predicitons
# naive_model = naive_model %>%
#   filter(n>=3) %>%
#   filter(timeseries_id %in% unique(all_predictions$timeseries_id))
# 
# naive_model %>%
#   count(timeseries_id) %>%
#   View()

errors = all_predictions %>%
  group_by(fitting_set, model, timeseries_id) %>%
  summarise(rmse = sqrt(mean( (gcc_observed - gcc_predicted)^2 ,na.rm=T)),
            r2   = 1  - sum((gcc_observed - gcc_predicted)^2,na.rm=T) / sum((gcc_observed - mean(gcc_observed,na.rm=T))^2,na.rm=T),
            #mae  = mean(abs(gcc_observed - gcc_predicted),na.rm=T),
            n=n(),
            n_timeseries = n_distinct(timeseries_id),
            percent_na=mean(is.na(gcc_observed))) %>%
  ungroup()

fitting_sets = read_csv('model_fitting_set_info/fitting_sets.csv')
fitting_set_assignments = read_csv('model_fitting_set_info/fitting_set_assignments.csv')

#######################################
# Calculate summary errors at the landcover/ecoregion scale for the main result table
# calculate site level errors for every tower/roi for a supplement table
site_level_errors = FALSE
if(site_level_errors){
  error_grouping = c('fitting_set', 'model', 'timeseries_id')
} else {
  error_grouping = c('fitting_set', 'model')
}

summarised_errors = tibble()


# Iterate thru all fitting sets and apply different predictions
# to them.
for(fitting_set_i in 1:nrow(fitting_sets)){
  prediction_scale = fitting_sets$model_fitting_sets[fitting_set_i]
  set_scale   = fitting_sets$model_fitting_scale[fitting_set_i]
  
  set_sites = fitting_set_assignments %>%
    filter(model_fitting_sets == prediction_scale) %>%
    pull(timeseries_id)
  
  if(set_scale == 'ecoregion-vegtype'){
    get_ecoregion_errors         = TRUE
    get_vegtype_errors           = TRUE
    get_ecoregion_vegtype_errors = TRUE
    get_allsite_errors           = TRUE
    
    ecoregion = str_split(prediction_scale, '_')[[1]][2]
    vegtype = str_split(prediction_scale, '_')[[1]][3]
    
  } else if(set_scale == 'ecoregion'){
    get_ecoregion_errors         = TRUE
    get_vegtype_errors           = FALSE
    get_ecoregion_vegtype_errors = FALSE
    get_allsite_errors           = TRUE
    
    ecoregion = str_split(prediction_scale, '_')[[1]][2]
  } else if(set_scale == 'vegtype'){
    get_ecoregion_errors         = FALSE
    get_vegtype_errors           = TRUE
    get_ecoregion_vegtype_errors = FALSE
    get_allsite_errors           = TRUE
    
    vegtype = str_split(prediction_scale, '_')[[1]][2]
  } else if(set_scale == 'allsites'){
    get_ecoregion_errors         = FALSE
    get_vegtype_errors           = FALSE
    get_ecoregion_vegtype_errors = FALSE
    get_allsite_errors           = TRUE
    
    vegtype = str_split(prediction_scale, '_')[[1]][2]
  } else{
    stop(paste0('unknown fitting set scale - ',set_scale))
  }
  
  # Errors from the ecoregion level model
  if(get_ecoregion_errors){
    ecoregion_set = paste0('ecoregion_',ecoregion)
    summarised_errors = errors %>%
      filter(fitting_set == ecoregion_set, timeseries_id %in% set_sites) %>%
      group_by(!!!rlang::syms(error_grouping)) %>%
      summarise(mean_r2 = mean(r2), prediction_n=n()) %>%
      ungroup() %>%
      mutate(prediction_set = prediction_scale) %>%
      mutate(fitting_scale = 'ecoregion') %>%
      bind_rows(summarised_errors)
  }
  
  # Errors from the vegtype level model
  if(get_vegtype_errors){
    vegype_set = paste0('vegtype_',vegtype)
    summarised_errors = errors %>%
      filter(fitting_set == vegype_set, timeseries_id %in% set_sites) %>%
      group_by(!!!rlang::syms(error_grouping)) %>%
      summarise(mean_r2 = mean(r2), prediction_n=n()) %>%
      ungroup() %>%
      mutate(prediction_set = prediction_scale) %>%
      mutate(fitting_scale = 'vegtype') %>%
      bind_rows(summarised_errors)
  }
  
  # Errors from the ecoregion+vegtype level model
  if(get_ecoregion_vegtype_errors){
    ecorgion_vegtype_set = prediction_scale # These are the same in this case
    summarised_errors = errors %>%
      filter(fitting_set == ecorgion_vegtype_set, timeseries_id %in% set_sites) %>%
      group_by(!!!rlang::syms(error_grouping)) %>%
      summarise(mean_r2 = mean(r2), prediction_n=n()) %>%
      ungroup() %>%
      mutate(prediction_set = prediction_scale) %>%
      mutate(fitting_scale = 'ecoregion-vegtype') %>%
      bind_rows(summarised_errors)
  }
  
  # Errors from the allsite model
  if(get_allsite_errors){
    summarised_errors = errors %>%
      filter(fitting_set == 'allsites', timeseries_id %in% set_sites) %>%
      group_by(!!!rlang::syms(error_grouping)) %>%
      summarise(mean_r2 = mean(r2), prediction_n=n()) %>%
      ungroup() %>%
      mutate(prediction_set = prediction_scale) %>%
      mutate(fitting_scale = 'allsites') %>%
      bind_rows(summarised_errors)
  }
}



#########################################
summarised_errors %>%
  filter(model=='PhenoGrass') %>%
  select(-fitting_set,-prediction_n) %>%
  spread(fitting_scale, mean_r2) %>%
  write_csv('error_table.csv')

##########################################


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