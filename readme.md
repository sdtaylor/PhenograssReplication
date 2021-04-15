This is the repository for the study:

Taylor, S.D. and Browning, D.M., 2021. Multi-scale assessment of a grassland productivity model. Biogeosciences, 18(6), pp.2213-2220. https://doi.org/10.5194/bg-18-2213-2021

## Contents

### Data Preparation

The following R scripts, run in order, will generate all the appropriate data used in this analysis.   

`data_prep/generate_site_list.R` - make `site_list.csv` file from the critera specified.  
`data_prep/generate_model_fitting_sets.R` - populate the `model_fitting_set_info` folder with information on the different model fitting scales.  
`data_prep/download_phenocam_data.R` - download the raw phenocam data to `data/phenocam/`  
`data_prep/download_daymet_values.R` - download daymet climate data for each site to `daymet_data.csv`  
`data_prep/process_phenocam_data.R ` - preprocess the downloaded phenocam data to the file `data/processed_phenocam_data.csv`  
`data_prep/process_soil_values.R`   - extract the soil variables from the  rasters in `data/soil_rasters`, with results going in to `site_list.csv`  

### Data

`data/` - This holds the model input data (phenocam, daymet, soil data). The two model output files (`full_model_predictions.csv`, and `cv_model_predictions.csv`) are available in the zenodo repo. [https://doi.org/10.5281/zenodo.3897319](https://doi.org/10.5281/zenodo.3897319)

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

The `fitted_models` folder contains saved model parameterizations from all model fits described in the paper. The first set of models are in `2020-07-29_0a82f11673e54a9c`, while the leave 1-out cross validation models are in `2020-08-23_69f5e0932e7b4970`. These are described with metadata in `fitted_models/model_sets.json`, and are designed to be accessed and iterated thru with the functions in `tools/load_models.py`.

### Model analysis. 

`analysis/analyze_errors.R`  - This generates the primary error table in the manuscript, as well as a site level error table in `results`  
`analysis/analyze_cv_errors.R` - This genates the CV errors  
`analysis/discussion_figure_site_gcc_comparison.R` - This generates the discussion figure of smoothed Grassland GCC  
`analysis/make_error_tables.R` - Make latex error tables for the manuscript  
`analysis/error_figures.R` - Make Figures 3 and 4  showing 1:1 comparisons of the 11 model iterations  
`analysis/NA_desert_grassland_fig.R` - Figure S1 highlighting predicted values in desert grasslands.  
`analysis/site_level_model_output_figure.R` - Make a large figure showing predictions and actuall GCC for every site  
`analysis/site_map.R` - create the map in the manuscript  
`analysis/site_table.R` - create the site table in the manuscript appendix  
