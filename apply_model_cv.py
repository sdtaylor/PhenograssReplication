import pandas as pd
import numpy as np
import GrasslandModels
from glob import glob
import re
from ast import literal_eval

from tools.load_data import get_processed_phenocam_data, marry_array_with_metadata
from tools import load_models

"""
Do predictions to get out of sample error rates from the models fit in
fit_model_cv.py
"""

######################################################
phenocam_info = pd.read_csv('site_list.csv')
phenocam_info = phenocam_info[phenocam_info.has_processed_data]
######################################################
# fitted models to apply
model_set_id = '69f5e0932e7b4970'
model_set = load_models.load_model_set(model_set_id)

fitted_models = [{'model':m,'model_name':n,'fitting_years':'20012009'} for m,n in zip(model_set['models'],model_set['model_names'])]

######################################################
# For each model get the predictions for it's training set

all_predictions = pd.DataFrame()

for fit_model in fitted_models:
    
    m = fit_model['model']
    
    left_out_ts = m.metadata['left_out_timeseries']

    gcc_observed, predictor_data, site_cols, date_rows = get_processed_phenocam_data(timeseries_ids = [left_out_ts],
                                                                                     years='all',
                                                                                     predictor_lag=5)
    
    model_predictors = {p:predictor_data[p] for p in m.required_predictors()}
    model_output = m.predict(predictors = model_predictors, return_variables='all')
    
    # Each model outputs several state variabes, this creates a data.frame of the form
    # pixel_id, date, ndvi_predicted, ndvi_observed, state_var1, state_var2, ....
    predicted_df = marry_array_with_metadata(model_output.pop('V'), site_cols, date_rows, new_variable_colname='gcc_predicted')
    observed_df  = marry_array_with_metadata(gcc_observed, site_cols, date_rows, new_variable_colname='gcc_observed')
    all_variables = predicted_df.merge(observed_df, how='left', on=['date','timeseries_id'])
    
    for variable_name, variable_array in model_output.items():
        variable_df = marry_array_with_metadata(variable_array, site_cols, date_rows, new_variable_colname=variable_name)
        all_variables = all_variables.merge(variable_df, how='left', on=['date','timeseries_id'] )
    
    precip_df = marry_array_with_metadata(predictor_data['precip'], site_cols, date_rows, new_variable_colname='precip')
    et_df = marry_array_with_metadata(predictor_data['evap'], site_cols, date_rows, new_variable_colname='et')
    all_variables = all_variables.merge(precip_df, how='left', on=['date','timeseries_id']).merge(et_df, how='left', on=['date','timeseries_id'])

   # all_variables['fitting_years'] = m['fitting_years']
   # all_variables['years'] = year_set_label
    all_variables['model'] = fit_model['model_name']
    
    all_variables['fitting_set'] = m.metadata['fitting_set'].split('-')[0]
    all_variables['left_out_timeseries'] = left_out_ts
    
    all_predictions = all_predictions.append(all_variables)

all_predictions.to_csv('data/cv_model_predictions.csv', index=False)
