This is the repository for the study:

**Multi-scale assessment of a grassland productivity model**  
Shawn Taylor & Dawn Browning

## Contents

### Data Preparation

The following R scripts, run in order, will generate all the appropriate data used in this analysis.   

`data_prep/generate_site_list.R` - make `site_list.csv` file from the critera specified.  
`data_prep/generate_model_fitting_sets.R` - populate the `model_fitting_set_info` folder with information on the different model fitting scales.  
`data_prep/download_phenocam_data.R` - download the raw phenocam data to `data/phenocam/`  
`data_prep/download_daymet_values.R` - download daymet climate data for each site to `daymet_data.csv`  
`data_prep/process_phenocam_data.R ` - preprocess the downloaded phenocam data to the file `data/processed_phenocam_data.csv`  
`data_prep/process_soil_values.R`   - extract the soil variables from the  rasters in `data/soil_rasters`, with results going in to `site_list.csv`  


### Model fitting and predictions

The following python scripts fit all iterations of the models. The _cv version fit and predict a small subset of the models in a leave 1 out cross validation scheme. See the paper section 2.4 Model Evaluation.  
The files populate the `results` folder from which the analysis scripts read from.  
Note the fitting procedures are designed to run on an HPC using the python library dask.  
The actual PhenoGrass code is in the python package GrasslandModels located at https://github.com/sdtaylor/GrasslandModels

`fit_model.py`  
`fit_model_cv.py`  
`apply_models.py`  
`apply_model_cv.py`  

The following files are used by the above script to fascilitate data loading, saving/loading fitted models, and fitting models on a dask.distributed cluster.

`tools/dask_tools.py`  
`tools/load_data.py`  
`tools/load_models.py`

### Model analysis. 

`analysis/analyze_errors.R`  - This generates the primary error table in the manuscript, as well as a site level error table in `results`  
`analysis/analyze_cv_errors.R` - This genates the CV errors  
`analysis/discussion_figure_site_gcc_comparison.R` - This generates the discussion figure of smoothed Grassland GCC  
`analysis/make_error_tables.R` - Make latex error tables for the manuscript  
`analysis/site_level_model_output_figure.R` - Make a large figure showing predictions and actuall GCC for every site  
`analysis/site_map.R` - create the map in the manuscript  
`analysis/site_table.R` - create the site table in the manuscript appendix  
