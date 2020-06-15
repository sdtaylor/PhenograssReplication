import pandas as pd
import numpy as np
import GrasslandModels

from dask_jobqueue import SLURMCluster

from tools.load_data import get_processed_phenocam_data

from scipy import optimize
from time import sleep
import toolz

#from dask_jobqueue import SLURMCluster
from dask.distributed import Client, as_completed
from dask import delayed
import dask


#######################################################################
# Firing up a cluster on ceres
#
#######################################################################


class ClusterWrapper():
    def __init__(self,
                 n_workers,
                 cores_per_worker,
                 mem_per_worker, 
                 worker_walltime,
                 partition_name,
                 job_extra = []):
        """
        A quick wrapper for starting a cluster on ceres
        """
        self.n_workers = n_workers
        self.cores_per_worker = cores_per_worker
        self.mem_per_worker = mem_per_worker
        self.worker_walltime = worker_walltime
        self.partition_name = partition_name
        self.job_extra = []
    
    def start(self):
        self.cluster = SLURMCluster(processes=1,
                                    queue=self.partition_name, 
                                    cores=self.cores_per_worker, 
                                    memory=self.mem_per_worker, 
                                    walltime=self.worker_walltime,
                                    job_extra=[],
                                    death_timeout=600, 
                                    local_directory='/tmp/')
        
        self.client = Client(self.cluster)
        self.workers = self.cluster.scale(self.n_workers)
        self.wait_for_workers()

    def restart_workers(self):
        self.cluster.scale(n=0)
        sleep(30)
        self.workers = self.cluster.scale(self.n_workers)
        self.wait_for_workers()

    def get_client(self):
        return self.client
    
    def close(self):
        self.cluster.close()
    
    def wait_for_workers(self):
        active_workers =  len(self.client.scheduler_info()['workers'])
        while active_workers < (self.n_workers-1):
            print('waiting on workers: {a}/{b}'.format(a=active_workers, b=self.n_workers))
            sleep(5)
            active_workers =  len(self.client.scheduler_info()['workers'])
        print('all workers online')
    
    def calculate_optimal_workers(self, fitting_population_size, parameter_count, chunks_per_job):
        """ 
        The optimal number of workers when using scipy.optimize.differential_evolution
        
        Ideally each worker evalutes one chunk in each fitting iteration.
        """
        return int(np.ceil(fitting_population_size * parameter_count / chunks_per_job))


#######################################################################
# Fitting tools for GrasslandModels
#
#######################################################################
#    Some stuff to get the fitting procedure in GrasslandModels to
#    work on a dask cluster. A bit convoluted, sorry.
#
#    The default opimizer, scipy.optimize.differential_evolution, can be done in parallel.
#    Either by passing the number of processes, or map function to the 'workers' arg.
#    Here I pass a map function which then passes on the jobs to dask workers. Each job
#    is a set of parameters to test on the data, thus each worker needs a persistant copy
#    of the data to be efficient.
#
#    Three main things need to happen.
#
#    1. The workers each load their own copy of the same dataset to fit on. This
#       is then accessed via a dask.future object
#    2. A minimization function is setup which incorporates the dask.future object. The
#       minimization function is passed as the func arg to optimize.differential_evolution
#    3. A a worker map function is setup which is passed to optimize.differential_evolution
#       and accepts a list of parameter sets to evaluate. The map function submits
#       this to the dask scheduler, and on completion, returns a list of loss
#       values to optimize.differential_evolution.
#
#   The only thing that should be called directly here is dask_fit(), which 
#   returns a fitted model object with some included metadata
def load_model_on_worker(model_name, param_ranges, loss_function, timeseries_ids, years):
    """
    This is designed to be passed as a future using dask.client.submit
    """
    gcc, predictor_vars, _, _ = get_processed_phenocam_data(years = years, timeseries_ids = timeseries_ids)

    m = GrasslandModels.utils.load_model(model_name)(parameters = param_ranges)
    this_model_predictors = {p:predictor_vars[p] for p in m.required_predictors()}

    m.fit_load(gcc, this_model_predictors, loss_function = loss_function)

    return m

def setup_workers(client, model_name, model_params, loss_function, timeseries_ids, years='all'):
    #do the replicate thing
    model_future = client.submit(load_model_on_worker,
                                 model_name = model_name, 
                                 param_ranges = model_params,
                                 loss_function = loss_function,
                                 timeseries_ids = timeseries_ids,
                                 years=years)
    # Have the model and data loaded on all workers
    # Note this will not be done automatically for any new workers.
    client.replicate(model_future)
    
    # # Keep a local model object for some fitting post-processing stuff
    # local_model = model_future.result()
    # scipy_bounds = local_model._scipy_bounds()
    
    return model_future


def scipy_fit(future, fitting_params):
    # The minimization function for scipy.optimize.de to optimize
    @delayed
    def minimize_me(scipy_parameter_sets):
        return [future.result()._scipy_error(param_set) for param_set in scipy_parameter_sets]
    
    # The parameter bounds formatted for scipy.optimize input
    scipy_bounds = future.result()._scipy_bounds()
    
    scipy_output =  optimize.differential_evolution(minimize_me, bounds=scipy_bounds, **fitting_params)
    return scipy_output

def dask_fit(client, 
             model_name,
             timeseries_ids, 
             years,
             fitting_params,
             model_params,
             loss_function,
             chunks_per_job):
    """
    client - a dask client
    model_name - str - GrasslandModels name to fit ot
    timeseries_ids - list of ints, timeseries ids from site_list.csv to fit on
    years          - list of ints or 'all', which years to fit on
    fitting_params - scipy.optimize.differential_evolution arguments
    model_params   - GrasslandModels parameter ranges
    loss_function  - str specififying loss func to use ('rmse','mean_cvmae')
    chunks_per_job - each differential_evolution iteration issues X sets of parameters to test,
                     which will be broken into a chunk_size specified here before sending to 
                     workers to evaluate. This is more efficient than each worker getting 1 job
                     at a time.

    """
    def scipy_map(func, iterable):
        # map function to pass into differential evolution as 'workers' arg
        # The func arg here is actually self.minimize_me being passed by scipy.optimize =D
        # its wrapped in @delayed so the results object is not actually 
        # calculated until dask_client.compute()
        chunked_iterable = toolz.partition_all(chunks_per_job, iterable)
        results = [func(x) for x in chunked_iterable] # func is a d
        futures =  client.compute(results)
        return list(toolz.concat([f.result() for f in futures]))

    # mapping function passed to the differential evolution 'workers' argument
    fitting_params['workers'] = scipy_map
    
    model_future = setup_workers(client=client, 
                                 model_name=model_name, model_params = model_params, loss_function = loss_function,
                                 timeseries_ids = timeseries_ids, years=years)
    
    local_model = model_future.result()
    
    scipy_output = scipy_fit(future = model_future, fitting_params=fitting_params)
    
    # Map the scipy results output back to model parameters
    local_model._fitted_params = local_model._translate_scipy_parameters(scipy_output['x'])
    local_model._fitted_params.update(local_model._fixed_parameters)
    
    # And save model input and optimize output inside the model metdata
    _ = scipy_output.pop('x')
    fitting_info = {'method'           : 'DE',
                    #'input_parameters' : de_fitting_params, # dont use this if there is a function for the workers arg
                    'loss_function'    : loss_function,
                    'optimize_output'  : dict(scipy_output)}
    local_model.update_metadata(fitting_info = fitting_info)

    return local_model
