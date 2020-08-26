library(tidyverse)

#####################################################
# This produces the supplementary figure S1, which shows the predicted and observed
# timeseries of the 5 sites used in North American Desert grasslands model. 
######################################################

all_predictions = read_csv('data/full_model_predictions.csv', 
                           col_types = cols(W=col_number(),
                                            gcc_observed = col_number(),
                                            fCover_observed = col_number(),
                                            Dt=col_number()))  %>%
  filter(model=='PhenoGrass') %>%
  filter(fitting_set %in% c('ecoregion-vegtype_NADeserts_GR'))


ecoregion_info = read_csv('model_fitting_set_info/ecoregion_codes.csv')
phenocam_site_info = read_csv('site_list.csv') %>%
  select(phenocam_name, timeseries_id, roi_type, ecoregion, MAP = MAP_daymet) %>%
  left_join(ecoregion_info, by='ecoregion') %>%
  as_tibble()

all_predictions = all_predictions %>%
  left_join(phenocam_site_info, by='timeseries_id')


desert_grassland_fig = all_predictions %>%
  filter(date >= '2015-01-01') %>%
ggplot(aes(x=date)) + 
  geom_point(aes(y=fCover_predicted), color='#D55E00') +
  geom_point(aes(y=fCover_observed), color='black') +
  geom_col(aes(y=precip/100), color='#0072B2') + 
  facet_wrap(~paste(phenocam_name,roi_type,sep='-')) +
  theme_bw(15) +
  theme(axis.text = element_text(color='black')) + 
  labs(x='Date',y='fCover (unitless) and precipitation (decimeters)')

ggsave('manuscript/figs/figS1_desert_grasslands.png',desert_grassland_fig, height = 20, width=30, units='cm', dpi=100)
             