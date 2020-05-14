import pandas as pd
import numpy as np
import GrasslandModels

from tools.load_data import get_processed_phenocam_data, marry_array_with_metadata
from tools import load_models
from tools.dask_tools import ClusterWrapper, dask_fit

from scipy import optimize
from time import sleep
import toolz
from copy import copy

#from dask_jobqueue import SLURMCluster
from dask.distributed import Client, as_completed
from dask import delayed
import dask


"""
This does leave 1-out cross validation for a small subset
of the models.

"""

###############################################

models_to_validate = {'NWForests_GR'    : "ecoregion-vegtype_NWForests_GR_PhenoGrass_3dbda2708f4f44f2.json",
                      'ETempForests_GR' : "ecoregion-vegtype_ETempForests_GR_PhenoGrass_3dbda2708f4f44f2.json",
                      'GrPlains_GR'     : "ecoregion-vegtype_GrPlains_GR_PhenoGrass_3dbda2708f4f44f2.json",
                      'NADeserts_GR'    : "ecoregion-vegtype_NADeserts_GR_PhenoGrass_3dbda2708f4f44f2.json"}
model_folder = 'fitted_models/2020-04-12_3dbda2708f4f44f2/'

model_fitting_note = 'first go at leave 1 out CV with the 4 GR models'


###############################################3
# Fitting stuff
loss_function = 'mean_cvmae'
de_popsize     = 400
de_maxiter     = 10000

# Dask/ceres stuff
chunks_per_job = 20
parameters_count = 7 # phenograss parameters since its the most intensive. 

use_default_workers = False
default_workers = 100

# While fitting scipy.differential_evolution will generate popsize*params
# jobs. These are chunked together by dask_scipy_mapper to be more efficient.
# the best number of workers is the amount that can run all those in one go. 
# Note the number of workers is the number of slurm jobs that will be spun up
if use_default_workers:
    print('Using default number of workers: ', str(default_workers))
    ceres_workers = default_workers
else:
    ceres_workers = int(np.ceil(de_popsize * parameters_count / chunks_per_job))
    eq = '{pop}*{param}/{c} = {w}'.format(pop=de_popsize, param=parameters_count, c=chunks_per_job, w=ceres_workers)
    print('Calculating optimal number of workers: ' + eq)

ceres_cores_per_worker = 1 # number of cores per job
ceres_mem_per_worker   = '2GB' # memory for each job
ceres_worker_walltime  = '48:00:00' # the walltime for each worker, HH:MM:SS
ceres_partition        = 'short'    # short: 48 hours, 55 nodes
                                    # medium: 7 days, 25 nodes
                                    # long:  21 days, 15 nodes



######################################################
# Setup fitting/testing clusters
phenocam_info = pd.read_csv('site_list.csv')
phenocam_info = phenocam_info[phenocam_info.has_processed_data]


######################################################
# Setup dask cluster
######################################################
cluster = ClusterWrapper(n_workers = ceres_workers,
                         cores_per_worker = ceres_cores_per_worker,
                         mem_per_worker = ceres_mem_per_worker, 
                         worker_walltime = ceres_worker_walltime,
                         partition_name = ceres_partition)
cluster.start()
dask_client = cluster.get_client()
#dask_client = Client()

######################################################
# model fitting delayed(func)(x)
######################################################

de_fitting_params = {
                     'maxiter':de_maxiter,
                     'popsize':de_popsize,
                     'mutation':(0.5,1),
                     'recombination':0.25,
                     'polish': False,
		            #'workers':2,
                     'disp':True}

# the search ranges for the model parameters
parameter_ranges = {'PhenoGrass':{'b1': -1, # b1 is a not actually used in phenograss at the moment, 
                                                # see https://github.com/sdtaylor/GrasslandModels/issues/2
                                                # Setting to -1 makes it so the optimization doesn't waste time on b1
                                  'b2': (0,0.5), 
                                  'b3': (0,5),
                                  'b4': (0,10),
                                  'Phmax': (1,50),
                                  'Phmin': (1,50),
                                  'Topt': (0,45), 
                                  'h': (1,1000), 
                                  #'h': (1,1000),
                                  'L': (0,30)}}


if __name__=='__main__':
    all_fitted_models = []
    fitting_model_i = 0 
    for fitting_set, model_file in models_to_validate.items():
        old_fit_model = GrasslandModels.utils.load_saved_model(model_folder+model_file)
        
        # Fix the h value to the original one estimated
        # The rest of the parameters will be estimated.
        initial_params_to_use = copy(parameter_ranges['PhenoGrass'])
        initial_params_to_use['h'] = old_fit_model.get_params()['h']
        
        
        model_timeseries = old_fit_model.metadata['timeseries_used']
        model_timeseries = [int(t) for t in model_timeseries.split(',')] # from a comma delimated str to a list
        
        for left_out_ts in model_timeseries:
            fitting_ts = [ts for ts in model_timeseries if ts is not left_out_ts]
            #print(fitting_ts,left_out_ts)
            
            fitted_model = dask_fit(client=dask_client, 
                                    model_name='PhenoGrass', 
                                    model_params = initial_params_to_use,
                                    timeseries_ids=fitting_ts, 
                                    years='all',
                                    loss_function = loss_function,
                                    fitting_params=de_fitting_params, 
                                    chunks_per_job=chunks_per_job)
            
          
            # A unique  identifier for this model within the cross-validation.
            # The fitting set appended with the timeseries used to fit
            fitting_set_id = fitting_set + '-' + '_'.join([str(t) for t in fitting_ts])
            
            fitted_model.update_metadata(model_evaluated = model_file)
            fitted_model.update_metadata(timeseries_used = ','.join([str(t) for t in fitting_ts]))
            fitted_model.update_metadata(fitting_set =  fitting_set_id)
            fitted_model.update_metadata(left_out_timeseries = left_out_ts)

            all_fitted_models.append(fitted_model)

            # Get around the 2 day limit on the short partition by just restarting the workers every now and then
            fitting_model_i += 1
            if fitting_model_i % 5 ==0:
                print('restarting cluster workers')
                cluster.restart_workers()
        
    # compile all the models into a set and save
    model_set = load_models.make_model_set(all_fitted_models,  note=model_fitting_note)
    load_models.save_model_set(model_set)
