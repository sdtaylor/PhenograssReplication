import pandas as pd
import numpy as np
import GrasslandModels

from tools.load_data import get_processed_phenocam_data
from tools import load_models

from scipy import optimize
from time import sleep
import toolz

from dask_jobqueue import SLURMCluster
from dask.distributed import Client, as_completed
from dask import delayed
import dask

###############################################

#models_to_fit = ['Naive','CholerPR1','CholerPR2','CholerPR3','PhenoGrassNDVI']
models_to_fit = ['Naive','NaiveMAPCorrected']

model_fitting_note = 'test run'

fitting_sets = pd.read_csv('model_fitting_set_info/fitting_sets.csv')
fitting_set_assignments = pd.read_csv('model_fitting_set_info/fitting_set_assignments.csv')

###############################################3
# Dask/ceres stuff
chunks_per_job = 20
parameters_count = 8 # phenograss parameters since its the most intensive. 
de_popsize     = 4
de_maxiter     = 2

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
cluster = SLURMCluster(processes=1,queue=ceres_partition, cores=ceres_cores_per_worker, memory=ceres_mem_per_worker, walltime=ceres_worker_walltime,
                        job_extra=[],
                        death_timeout=600, local_directory='/tmp/')

print('Starting up workers')
workers = cluster.scale(n=ceres_workers)
dask_client = Client(cluster)

active_workers =  len(dask_client.scheduler_info()['workers'])
while active_workers < (ceres_workers-1):
    print('waiting on workers: {a}/{b}'.format(a=active_workers, b=ceres_workers))
    sleep(5)
    active_workers =  len(dask_client.scheduler_info()['workers'])
print('all workers online')
#dask_client = Client()


# This is the callable sent to scipy.
def dask_scipy_mapper(func, iterable, c=dask_client):
    chunked_iterable = toolz.partition_all(chunks_per_job, iterable)
    results = [func(x) for x in chunked_iterable]
    futures =  dask_client.compute(results)
    return list(toolz.concat([f.result() for f in futures]))

######################################################
# model fitting delayed(func)(x)
######################################################
loss_function = 'mean_cvmae'

de_fitting_params = {
                     'maxiter':de_maxiter,
                     'popsize':de_popsize,
                     'mutation':(0.5,1),
                     'recombination':0.25,
                     'workers': dask_scipy_mapper,
                     'polish': False,
		     #'workers':2,
                     'disp':True}

# the search ranges for the model parameters
parameter_ranges = {'CholerPR1':{'b1':(0,200),
                                 'b2':(0,10),
                                 'b3':(0,10),
                                 'L' : 2},
                    'CholerPR2':{'b1':(0,200),
                                 'b2':(0,10),
                                 'b3':(0,10),
                                 'b4':(0,200),
                                 'L' : 2},
                    'CholerPR3':{'b1':(0,200),
                                 'b2':(0,10),
                                 'b3':(0,10),
                                 'b4':(0,200),
                                 'L' : 2},
                    'CholerMPR2':{'b2':(0,10),
                                  'b3':(0,10),
                                  'b4':(0,200),
                                  'L' :2},
                    'CholerMPR3':{'b2':(0,10),
                                  'b3':(0,10),
                                  'b4':(0,200),
                                  'L' :2},
                    'CholerM1A':{'L' :2},
                    'CholerM1B':{'L' :2},
                    'CholerM2A':{},
                    'CholerM2B':{},
                    'PhenoGrass':{'b1': -1, # b1 is a not actually used in phenograss at the moment, 
                                                # see https://github.com/sdtaylor/GrasslandModels/issues/2
                                                # Setting to -1 makes it so the optimization doesn't waste time on b1
                                  'b2': (0,0.5), 
                                  'b3': (0,5),
                                  'b4': (0,10),
                                  'Phmax': (1,50),
                                  'Phmin': (1,50),
                                  'Topt': (0,45), 
                                  'h': (1,1000), # TODO: let this vary when fitting > 1 site
                                  #'h': (1,1000),
                                  'L': (0,30)},
                    'Naive' : {'b1':(0,100),
                               'b2':(0,100),
                               'L': (0,60)},
                    'NaiveMAPCorrected' : {'b1':(0,100),
                               'b2':(0,100),
                               'h':(1,1000),
                               'L': (0,60)}
                    }


def load_model_and_data(model_name,timeseries_ids, years):
    gcc, predictor_vars, _, _ = get_processed_phenocam_data(years = years, timeseries_ids = timeseries_ids)
    
    m = GrasslandModels.utils.load_model(model_name)(parameters = parameter_ranges[model_name])
    this_model_predictors = {p:predictor_vars[p] for p in m.required_predictors()}

    m.fit_load(gcc, this_model_predictors, loss_function = loss_function)

    return m

if __name__=='__main__':
    fit_models = []
    
    total_sets = len(fitting_sets)
    
    for fitting_set_i, this_fitting_set in enumerate(fitting_sets.model_fitting_sets):
        this_set_timeseries = fitting_set_assignments[fitting_set_assignments.model_fitting_sets==this_fitting_set].timeseries_id
        
        for model_name in models_to_fit:
            print('scheduler address: '+dask_client.scheduler_info()['address'])
            print('set {s} - {n}/{t} - {m}'.format(s=this_fitting_set,n=fitting_set_i, t=total_sets,m=model_name))
            # This future is the model, with fitting data, being loaded on all
            # the nodes by replicate()
            model_future = dask_client.submit(load_model_and_data, model_name = model_name, 
                                              timeseries_ids = this_set_timeseries, years = 'all')
            dask_client.replicate(model_future)
            
            # Keep a local model for some scipy fitting stuff
            local_model = model_future.result()
            scipy_bounds = local_model._scipy_bounds()
            
            # A wrapper to put into the scipy optimizer, it accepts a list of candidate
            # parameter sets to evaluate, and returns a list of scores.
            # The delayed wrapper and the use of the model future lets it be run across all the dask distributed nodes. 
            @delayed
            def minimize_me(scipy_parameter_sets):
                return [model_future.result()._scipy_error(param_set) for param_set in scipy_parameter_sets]

            # This kicks off all the parallel work
            scipy_output =  optimize.differential_evolution(minimize_me, bounds=scipy_bounds, **de_fitting_params)
            
            # Map the scipy results output back to model parameters and save results
            local_model._fitted_params = local_model._translate_scipy_parameters(scipy_output['x'])
            local_model._fitted_params.update(local_model._fixed_parameters)
            
            # And save model input and optimize output inside the model metdata
            _ = scipy_output.pop('x')
            fitting_info = {'method'           : 'DE',
                            #'input_parameters' : de_fitting_params, # dont use this if there is a function for the workers arg
                            'loss_function'    : loss_function,
                            'optimize_output'  : dict(scipy_output)}
            local_model.update_metadata(fitting_info = fitting_info)
            local_model.update_metadata(fitting_set =  this_fitting_set)
            local_model.update_metadata(timeseries_used = ','.join([str(t) for t in this_set_timeseries]))

            fit_models.append(local_model)
    
    
    # compile all the models into a set and save
    model_set = load_models.make_model_set(fit_models,  note=model_fitting_note)
    load_models.save_model_set(model_set)
