library(tidyverse)


fitting_set_assignments = read_csv('model_fitting_set_info/fitting_set_assignments.csv') %>%
  mutate(fitting_set_ts_interaction = interaction(model_fitting_sets,timeseries_id))

ecoregion_codes = read_csv('model_fitting_set_info/ecoregion_codes.csv')
site_info = read_csv('site_list.csv') %>%
  left_join(ecoregion_codes, by='ecoregion') %>%
  select(timeseries_id, phenocam_name, roi_type, ecoregion_desc)

all_predictions = read_csv('data/full_model_precitions.csv', 
                           col_types = cols(W=col_number(),
                                            gcc_observed = col_number(),
                                            Dt=col_number()))

# The model predictions file contains *every* model applied to *every* timeseries, because
# that was easiest to do in the python  code. Here we need to drop the unneeded ones. For 
# example the northwest forest model applied to sites in other ecoregions is not valid.
# Easily done by filtering the assignments already defined in the fitting_set_assignments file
all_predictions = all_predictions %>%
  filter(interaction(fitting_set,timeseries_id) %in% fitting_set_assignments$fitting_set_ts_interaction)

all_predictions = all_predictions %>%
  left_join(site_info, by='timeseries_id')

figure_start_date = '2015-01-01'
figure_end_date   = '2020-01-01'

select_sites = c('ibp','ahwahnee','kansas','NEON.D15.ONAQ.DP1.00033','lethbridge','mead1','butte','cperagm','tonzi')

site_level_model_predictions_figure = all_predictions %>%
  filter(model == 'PhenoGrass') %>%
  filter(date >= lubridate::ymd(figure_start_date), date<=lubridate::ymd(figure_end_date)) %>%
  #filter(phenocam_name %in% select_sites) %>%
  mutate(precip = precip/100) %>%
  mutate(facet_label = paste0(phenocam_name,' - ',roi_type)) %>%
ggplot(aes(x=date)) +
  #geom_col(aes(y=precip), color='blue', alpha=0.4) + 
  geom_line(aes(y=gcc_predicted, color=fitting_set)) +
  geom_line(aes(y=gcc_observed), color='black') + 
  coord_cartesian(ylim=c(0,1)) + 
  theme_bw(20) + 
  facet_wrap(~facet_label, ncol=5)

ggsave(plot = site_level_model_predictions_figure, filename = 'results/site_level_predictions.png', 
       width = 45, height = 90, units = 'cm',dpi=100)
