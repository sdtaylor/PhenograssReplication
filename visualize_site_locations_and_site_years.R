library(tidyverse)
library(phenocamr)
library(ggrepel)


phenocam_sites = read_csv('site_list.csv')

basemap = map_data('state')

ggplot() + 
  geom_polygon(data = basemap, aes(x=long, y = lat, group = group), fill=NA, color='black', size=1.5) +
  geom_point(data=phenocam_sites, aes(x=lon, y=lat, color=roitype), size=4.5) + 
  #geom_label_repel(data=phenocam_veg_types, aes(x=lon, y=lat,label=phenocam_name), size=2.5) + 
  theme_bw(20) +
  scale_color_manual(values=c('brown','green','blue')) + 
  #coord_fixed(1.3, xlim=c(-125,-70), ylim=c(25,55)) +  
  theme(panel.background = element_rect(fill='white'),
        axis.text = element_text(size=25),
        axis.title = element_text(size=30),
        legend.background = element_rect(color='black'),
        legend.position = c(0.9,0.8)) +
  labs(x='Longitude',y='Latitude')


ggplot(phenocam_sites,aes(x=phenocam_name, color=roitype)) + 
  geom_linerange(aes(ymin=first_date, ymax=last_date)) +
  scale_y_date(breaks=as.Date(paste0(seq(2001,2020,2), '-01-01'))) +
  coord_flip() +
  theme(axis.text.y = element_text(size=10),
        axis.text.x = element_text(size=8))

