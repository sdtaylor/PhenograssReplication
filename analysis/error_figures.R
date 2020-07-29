library(tidyverse)

all_predictions = read_csv('data/full_model_predictions.csv', 
                           col_types = cols(W=col_number(),
                                            gcc_observed = col_number(),
                                            fCover_observed = col_number(),
                                            Dt=col_number()))  %>%
  filter(model=='PhenoGrass')

ecoregion_info = read_csv('model_fitting_set_info/ecoregion_codes.csv')

phenocam_site_info = read_csv('site_list.csv') %>%
  select(phenocam_name, timeseries_id, roi_type, ecoregion, MAP = MAP_daymet) %>%
  left_join(ecoregion_info, by='ecoregion') %>%
  as_tibble()

get_label_stats = function(df){
  # This needs to accept a group_by() output
  df %>%
  summarise(rmse = sqrt(mean( (fCover_observed - fCover_predicted)^2 ,na.rm=T)),
            r2   = 1  - sum((fCover_observed - fCover_predicted)^2,na.rm=T) / sum((fCover_observed - mean(fCover_observed,na.rm=T))^2,na.rm=T),
            #mae  = mean(abs(gcc_observed - gcc_predicted),na.rm=T),
            n=n(),
            n_timeseries = n_distinct(timeseries_id)) %>%
    ungroup() %>%
    mutate(label_text = paste0('R2: ',round(r2,2),'\n','RMSE: ',round(rmse,2),'\n',n_timeseries,' sites'))
}

#######################################################
# 1:1 plots of all site model and all vegtype models
#######################################################
fitting_levels = c('allsites','vegtype_GR','vegtype_AG','vegtype_SH')
nice_labels    = c('All Sites', 'All Grasslands','All Agriculture', 'All Shrubland')

allsite_veg_predictions = all_predictions %>%
  filter(fitting_set %in% c('allsites','vegtype_GR','vegtype_AG','vegtype_SH')) %>%
  filter(!is.na(fCover_observed)) %>%
  left_join(phenocam_site_info, by='timeseries_id')

allsite_veg_predictions$fitting_set = factor(allsite_veg_predictions$fitting_set, levels = fitting_levels, labels = nice_labels)

allsite_veg_predictions_error_text = allsite_veg_predictions %>%
  group_by(fitting_set) %>%
  get_label_stats()

# Allsite model correlation at ecoregion level
allsite_veg_error_fig = ggplot(allsite_veg_predictions, aes(x=fCover_observed, y=fCover_predicted)) + 
  geom_point(alpha=0.05, shape=1, size=1) + 
  geom_line(data=tibble(fCover_observed=seq(0,1,0.1), fCover_predicted=seq(0,1,0.1)),size=1, aes(color='a')) + # a 1:1 line so that a legend can be hacked in without
  geom_smooth(method='lm', se=FALSE, aes(color='b'), size=1) +                                                  # specifying a color columns
  scale_color_manual(labels=c('1:1 Line','Correlation'), values=c('#D55E00','#0072B2')) + 
  geom_label(data=allsite_veg_predictions_error_text, aes(x=0.01,y=0.88,label=label_text), size=2, hjust=0) + 
  facet_wrap(~fitting_set, ncol=2) +
  theme_bw(10) +
  theme(legend.position = c(0.895,0.08),
        legend.background = element_rect(color='black'),
        legend.margin = margin(2,2,2,2),
        legend.title = element_blank(),
        legend.text = element_text(size=7),
        strip.background = element_blank(),
        strip.text = element_text(hjust = 0, size=10)) +
  labs(x='Observed fCover', y='Predicted fCover') 

ggsave('manuscript/figs/allsite_veg_errors.png',plot=allsite_veg_error_fig, height=12, width = 12, units='cm', dpi=200)


#######################################################
# 1:1 plots of ecoregion + vegtype models
#######################################################
ecoregion_vegtype_predictions = all_predictions %>%
  filter(str_detect(fitting_set, 'ecoregion-vegtype')) %>%
  left_join(phenocam_site_info, by='timeseries_id') %>%
  filter(ecoregion %in% c(6, 8, 9, 10)) # NWForests, ETempforests, GrPlains, NADeserts

ecoregion_vegtype_predictions = ecoregion_vegtype_predictions %>%
  mutate(vegtype = case_when(
    roi_type=='GR' ~ 'Grasslands',
    roi_type=='AG' ~ 'Agriculture',
    roi_type=='SH' ~ 'Shrubland'
  )) %>%
  mutate(facet_label = paste(ecoregion_desc,vegtype,sep=' - '))

ecoregion_vegtype_predictions_error_text = ecoregion_vegtype_predictions %>%
  group_by(facet_label) %>%
  get_label_stats()



ecoregion_vegtype_error_figure = ggplot(ecoregion_vegtype_predictions, aes(x=fCover_observed, y=fCover_predicted)) + 
  geom_point(alpha=0.2, shape=1, size=1) + 
  geom_line(data=tibble(fCover_observed=seq(0,1,0.1), fCover_predicted=seq(0,1,0.1)),size=1, aes(color='a')) + # a 1:1 line so that a legend can be hacked in without
  geom_smooth(method='lm', se=FALSE, aes(color='b'), size=1) +                                                  # specifying a color columns
  scale_color_manual(labels=c('1:1 Line','Correlation'), values=c('#D55E00','#0072B2')) + 
  #geom_abline(aes(slope=1, intercept = 0,color='#D55E00')) +
  geom_label(data=ecoregion_vegtype_predictions_error_text, aes(x=0.01,y=0.88,label=label_text), size=2.5, hjust=0) + 
  facet_wrap(~facet_label, ncol=2) +
  theme_bw(12) +
  theme(legend.position = c(0.75,0.1),
        legend.background = element_rect(color='black'),
        legend.title = element_blank(),
        strip.background = element_blank(),
        strip.text = element_text(hjust = 0, size=8)) +
  labs(x='Observed fCover', y='Predicted fCover') 

ggsave('manuscript/figs/ecoregion_errors.png',plot=ecoregion_vegtype_error_figure, height=20, width = 15, units='cm', dpi=200)
