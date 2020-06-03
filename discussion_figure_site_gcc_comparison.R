library(tidyverse)

phenocam_data = read_csv('data/processed_phenocam_data.csv')

phenocam_sites = read_csv('site_list.csv') %>%
  filter(has_processed_data) %>%
  filter(roi_type=='GR')

hufkin_sites = read_csv('hufkins2016_sites.csv')

site_status = phenocam_sites %>%
  mutate(site_grouping = case_when(
    phenocam_name %in% hufkin_sites$phenocam_name ~ 'A. Hufkins et al. 2016 Sites',
    TRUE ~ 'B. Additional Grassland Sites in Current Study')) %>% 
  select(phenocam_name, site_grouping, ecoregion)

grassland_gcc = phenocam_data %>%
  filter(roi_type=='GR') %>%
  left_join(site_status, by='phenocam_name')

random_palette = sample(viridis::viridis(38))

discusion_figure = ggplot(grassland_gcc, aes(x=doy, y=gcc, color=as.factor(timeseries_id), group=as.factor(timeseries_id))) +
  geom_smooth(size=1.2, se=F) +
  #scale_color_manual(values=random_palette) +
  scale_color_viridis_d() + 
  scale_x_continuous(breaks=c(1,100,200,300), expand = c(0,0)) + 
  facet_wrap(~site_grouping,ncol=2) +
  theme_bw(25) +
  theme(legend.position = 'none',
        strip.background = element_blank(),
        strip.text = element_text(hjust = 0)) +
  labs(x='Day of Year', y='Avg. GCC')

ggsave('manuscript/figs/discussion_avg_site_gcc.png', plot=discusion_figure, height = 15, width=30, units = 'cm', dpi=200)  


  # Also while where here parse out what the original ecoregions were
ecoregion_info = read_csv('model_fitting_set_info/ecoregion_codes.csv')

site_status %>%
  left_join(ecoregion_info, by='ecoregion') %>%
  count(site_grouping, ecoregion_desc) %>%
  arrange(site_grouping,-n)
