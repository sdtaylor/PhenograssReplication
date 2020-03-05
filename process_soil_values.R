library(raster)
library(rgdal)

# Extract wilting point and water holding capactiy from the 
# Global Gridded Surfaces of Selected Soil Characteristics (IGBP-DIS)
#
# Uses the site_list.csv file made by generate_site_list.R


Wp_raster = raster('./data/soil_rasters/wiltpont.dat')
Wcap_raster = raster('./data/soil_rasters/fieldcap.dat')

phenocam_sites = readr::read_csv('site_list.csv')

phenocam_sites_spatial = SpatialPointsDataFrame(phenocam_sites[,c('lon','lat')],
                                                data = phenocam_sites,
                                                proj4string = crs("+init=epsg:4326"))

phenocam_sites$Wp = raster::extract(Wp_raster, phenocam_sites_spatial)
phenocam_sites$Wcap = raster::extract(Wcap_raster, phenocam_sites_spatial)

phenocam_sites$Wp = round(phenocam_sites$Wp, 2)
phenocam_sites$Wcap = round(phenocam_sites$Wcap, 2)

readr::write_csv(phenocam_sites, 'site_list.csv')
