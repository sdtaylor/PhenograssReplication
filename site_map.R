library(sf)
library(tidyverse)
library(rnaturalearth)

# From the full level 1 shapefile downloaded at ftp://newftp.epa.gov/EPADataCommons/ORD/Ecoregions/cec_na/na_cec_eco_l1.zip
# Subset to ecoregions used here (6 - NW Forests, 8 - E. Temp Forests, 9 - Great Plains, 10 - NA Deserts)
# Simplify to make for quicker rendering, convert to lat/lon coordinates, and save to geojson.
# all_ecoregions = sf::st_read('data/ecoregions/NA_CEC_Eco_Level1.shp')
# my_ecoregion_codes = c(6,8,9,10)
# my_ecoregions = all_ecoregions[all_ecoregions$NA_L1CODE %in% my_ecoregion_codes,]
# my_ecoregions = st_simplify(my_ecoregions, dTolerance = 1000)
# my_ecoregions = st_transform(my_ecoregions, 4326)
# my_ecoregions = rename(my_ecoregions, l1_code = NA_L1CODE, ecoregion_name = NA_L1NAME)
# st_write(my_ecoregions, 'data/ecoregions/study_ecoregions.geojson')

country_outlines = ne_countries(scale = 'small', returnclass = 'sf') %>%
  filter(name %in% c('United States','Mexico','Canada'))

my_ecoregions = st_read('data/ecoregions/study_ecoregions.geojson')
phenocam_sites = read_csv('site_list.csv') %>%
  st_as_sf(coords = c('lon','lat'), crs=4326)


map_bounds = st_bbox(c(xmin = -135, xmax = -60, ymax = 58, ymin = 25), crs = st_crs(4326))

my_ecoregions = st_crop(my_ecoregions, map_bounds)
country_outlines = st_crop(country_outlines, map_bounds)

ecoregion_labels = tribble(
  ~ecoregion_name,                   ~pretty_name,                  ~lat, ~lon,
  'EASTERN TEMPERATE FORESTS',       'Eastern\nTemperate Forests',    32, -90,
  'GREAT PLAINS',                    'Great Plains',                  42.5, -101,
  'NORTH AMERICAN DESERTS',          'North American\nDeserts',       41, -118,
  'NORTHWESTERN FORESTED MOUNTAINS', 'Northwest\nForested Mountains', 56, -117
)

ggplot() + 
  geom_sf(data = country_outlines, color='black', fill='grey98') + # country outlines once to make a slightly darker background
  geom_sf(data = my_ecoregions, aes(fill=ecoregion_name)) +
  scale_fill_manual(values = c('grey30','grey60','grey40','grey70')) +
  geom_sf(data = country_outlines, color='grey20', fill='transparent') + # country outlines again to make  the  actual lines
  geom_sf(data = phenocam_sites, aes(color=roi_type, shape=roi_type), size=3) +
  scale_color_manual(values = c('#E69F00','#009E73','#0072B2')) +
  scale_shape_manual(values = c(16,17,15)) + 
  geom_label(data=ecoregion_labels, aes(x=lon,y=lat,label=pretty_name,fill=ecoregion_name),alpha=0.7, size=4) + 
  theme_minimal() +
  theme(axis.text = element_blank(),
        axis.title = element_blank(),
        panel.grid = element_blank(),
        legend.position = c(0.85,0.3),
        legend.box = 'vertical',
        legend.direction = 'vertical',
        legend.box.background = element_rect(color='black',fill='white')) + 
  guides(fill = 'none',
         color = guide_legend())
