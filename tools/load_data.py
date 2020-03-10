import pandas as pd
import numpy as np
from GrasslandModels import et_utils


#############################

def filter_data(df, y, t):
    """
    year and phenocam_name  filter
    """
    return df[(df.year.isin(y)) & (df.timeseries_id.isin(t))]

def long_to_wide(df, index_column, value_column):
    """Long to wide in the shape of (timestep, phenocam_name)"""
    return df[['timeseries_id',index_column,value_column]].pivot_table(index = index_column, columns='timeseries_id', 
                                                                  values=value_column, dropna=False)

def marry_array_with_metadata(a, timeseries_id_columns, date_rows, new_variable_colname):
    """
    Take the basic numpy array output from GrasslandModels and combine it with dates
    and phenocam_names. Designed to work with output from get_pixel_modis_data()
    """
    assert a.shape == (len(date_rows), len(timeseries_id_columns)), 'array shape does not match new row/col shapes'
    df = pd.DataFrame(a,index = date_rows, columns=timeseries_id_columns).reset_index()
    return df.melt(id_vars='date', value_name = new_variable_colname)

def get_processed_phenocam_data(years = range(2010,2019), timeseries_ids = 'all', predictor_lag = 5):
    """
    Load Phenocam GCC and associated predictor data (daymet precip & temp, 
    ET, daylength, soil)
    
    Parameters
    ----------
    years : array of years or 'all', optional
        whichs years of Phenocam and associated predictor 
        data to return. The default is 'all'.
    pixel_name : array of phenocam_names or 'all', optional
        which phenocams to return. The default is 'all'.
    predictor_lag : int, optional
        how many years of predictor variables (ie. precip, temp,
        evap) prior to the start of NDVI values to keep.
        This allows spin up of state variables leading up to actual NDVI values 
        to fit. The default is 5.
        NDVI for these preceding years will be NA. The array shape will be
        consistant throughout all timeseries variables.

    Returns
    -------
    Tuple of GCC , {'precip': (timestep, phenocam_name), # precipitation summed over the 16 day period
                    'evap'  : (timestep, phenocam_name), # ET summed over the 16 day period
                    'Tm'    : (timestep, phenocam_name), # Daily mean temp averaged over the 16 day period
                    'Ra'    : (timestep, phenocam_name), # Daily TOA radiation averaged over the 16 day period
                    'Wcap'  : (phenocam_name),           # timeseries_id specific water holding capacity
                    'Wp'    : (phenocam_name)}           # timeseries_id specific Wilting point
    a (timestep,phenocam_name) array. 

    """
    phenocam_info = pd.read_csv('site_list.csv')    
    phenocam_data = pd.read_csv('data/processed_phenocam_data.csv').drop('date', axis=1)
    
    # Drop leap year values to simplify things
    phenocam_data = phenocam_data[phenocam_data.doy!=366]
    
    daymet_data = pd.read_csv('data/daymet_data.csv')
    
    if years == 'all':
        years = phenocam_data.year.unique()
    else:
        years = np.array(years)
    years.sort()
    
    available_timeseries_ids = phenocam_data.timeseries_id.unique()
    if isinstance(timeseries_ids, str) and timeseries_ids=='all':
        timeseries_ids = available_timeseries_ids
    else:
        # Make sure selected timeseries_ids are actually available in the NDVI dataset
        timeseries_ids = np.array(timeseries_ids)
        timeseries_ids = timeseries_ids[[p in available_timeseries_ids for p in timeseries_ids]]
    
    phenocam_data = phenocam_data[(phenocam_data.year.isin(years)) & (phenocam_data.timeseries_id.isin(timeseries_ids))]
    
    predictor_years = np.append(list(range(min(years) - predictor_lag, min(years))),years)
    selected_phenocam_names = phenocam_info[phenocam_info.timeseries_id.isin(timeseries_ids)].phenocam_name.values
    daymet_data = daymet_data[(daymet_data.year.isin(predictor_years)) & (daymet_data.phenocam_name.isin(selected_phenocam_names))]
    
    unique_timeseries = phenocam_data[['timeseries_id','phenocam_name','roi_type','roi_id']].drop_duplicates()
    
    # Make sure everything is accounted for
    assert set(daymet_data.groupby(['phenocam_name','year','doy']).count().tmin.unique()) == set([1]), 'daymet days has some dates/phenocam names with > 1 entry'
    assert daymet_data.groupby(['year','phenocam_name']).count().doy.unique()[0] == 365, 'daymet data has some years with < 365 days'
    assert np.isin(daymet_data.year.unique(), predictor_years).all(), 'extra years in daymet data'
    assert np.isin(predictor_years,daymet_data.year.unique()).all(), 'not all predictor years in daymet data'
    assert np.all(phenocam_data.groupby(['phenocam_name','roi_type','roi_id']).count().doy.unique() >= 365), 'phenocam data has some timeseries_ids with < 365 daily entries'
    assert np.isin(phenocam_data.year.unique(), years).all(), 'extra years in phenocam data'
    assert phenocam_data.groupby('timeseries_id').year.nunique().unique().min() >= 3, 'some phenocam timeseries with < 3 years'
    assert phenocam_data.groupby('timeseries_id').year.nunique().unique().max() < 8, 'some phenocam timeseries with >=8 years'
     
    assert np.isin(daymet_data.phenocam_name.unique(), selected_phenocam_names).all(), 'daymet data has some missing phenocams'
    assert np.isin(selected_phenocam_names,daymet_data.phenocam_name.unique()).all(), 'daymet data has some extra phenocams'
    assert np.isin(phenocam_data.timeseries_id.unique(), timeseries_ids).all(), 'phenocam data has some missing timeseries_ids'
       
    # daily mean temperature in a 15 day moving window
    # slightly different from Hufkens '16, which used prior 15 days
    daymet_data['date'] = pd.to_datetime(daymet_data.year.astype(str) + '-' + daymet_data.doy.astype(str), format='%Y-%j')
    daymet_data['tmean'] = (daymet_data.tmin + daymet_data.tmax) / 2

    running_avg = daymet_data.groupby('phenocam_name').rolling(window=15,min_periods=15, on='date').tmean.mean().reset_index().rename(columns={'tmean':'tmean_running_avg'})
    daymet_data = daymet_data.merge(running_avg, how='left', on=['phenocam_name','date'])
    
    daymet_data = daymet_data.drop(columns='tmean').rename(columns={'tmean_running_avg':'tmean'})
    
    # pull in latitude for ET calculation
    tower_latitude = phenocam_info[['phenocam_name','lat']].drop_duplicates()
    daymet_data = daymet_data.merge(tower_latitude, how='left', on='phenocam_name')
    
    # Estimate ET from tmin, tmax and latitude
    latitude_radians = et_utils.deg2rad(daymet_data.lat.values)
    solar_dec = et_utils.sol_dec(daymet_data.doy.values)
    sha = et_utils.sunset_hour_angle(latitude_radians, solar_dec)
    ird = et_utils.inv_rel_dist_earth_sun(daymet_data.doy.values)
    daymet_data['radiation'] = et_utils.et_rad(latitude_radians, solar_dec, sha, ird)
    daymet_data['et'] = et_utils.hargreaves(tmin = daymet_data.tmin.values, tmax = daymet_data.tmax.values,
                                         et_rad = daymet_data.radiation.values)

    
    # Repeat the daymet data for when there is > 1 timeseries at 1 tower
    daymet_data=unique_timeseries.merge(daymet_data, how='left', on='phenocam_name')
    
    assert set(daymet_data.groupby(['timeseries_id','phenocam_name','year','doy']).count().tmin.unique()) == set([1]), 'daymet data, after processing, has some timeseries/dates names with > 1 entry'
    assert set(daymet_data.groupby(['timeseries_id','year','doy']).count().tmin.unique()) == set([1]), 'daymet data, after processing, has some timeseries/dates names with > 1 entry'
    assert set(daymet_data.groupby(['phenocam_name','roi_type','roi_id']).timeseries_id.nunique().unique()) == set([1]), 'daymet data, after procesing, has >1 timeseries id per name/roi/roi_id'
    assert set(daymet_data.groupby('timeseries_id').roi_type.nunique().unique()) == set([1]), 'daymet data, after processing, has >1 phenocam_name per timeseries_id'
    assert daymet_data.groupby(['year','timeseries_id']).count().doy.unique()[0] == 365, 'daymet data, after processing, has some years != 365 days'
    
    # drop these to as their replicated in phenocam_data
    daymet_data = daymet_data.drop(columns=['phenocam_name','roi_type','roi_id'])
    # Full outer join to combine all selected years + the preceding predictor years
    # This will make NA gcc values for those preceding years
    everything = phenocam_data.merge(daymet_data, how='outer', on=['year','doy','timeseries_id'])
    everything.sort_values(['phenocam_name','date'], inplace=True)
    
    # Sanity checks
    assert set(everything.groupby(['timeseries_id','year','doy']).count().tmin.unique()) == set([1]), 'combined data, after processing, has some timeseries/dates names with > 1 entry'
    assert set(everything.groupby('timeseries_id').year.nunique().unique()) == set([len(predictor_years)]), 'after combining data, some timeseries do not have all years available'
    assert set(everything.groupby(['timeseries_id','year']).count().tmin.unique()) == set([365]), 'after combining data, some timeseries do not have 365 days of each year'
    
    # Soil and MAP values are a single value/tower, so it doesn't need combining with everything else.
    # Just need to replicate it to different ROIs, and make sure it's ordered correctly
    site_level_values = unique_timeseries.merge(phenocam_info[['phenocam_name','roi_type','roi_id','MAP_daymet','Wp','Wcap']], 
                                                how='left', on=['phenocam_name','roi_type','roi_id'])
    
    site_level_values.sort_values('timeseries_id', inplace=True)
    
    # Ensure pixel are aligned in the arrays correctly
    assert (long_to_wide(everything, index_column = 'date', value_column = 'gcc').columns == site_level_values.timeseries_id).all(), 'predictor data.frame not aligning with soil data.frame'
    assert (long_to_wide(everything, index_column = 'date', value_column = 'gcc').columns == long_to_wide(everything, index_column = 'date', value_column = 'tmean').columns).all(), 'tmean and ndvi columns not lining up'
    
    # produce (timestep,phenocam_name) numpy arrays.
    gcc_pivoted = long_to_wide(everything, index_column = 'date', value_column = 'gcc')
    gcc_array = gcc_pivoted.values

    # the numpy arrays to be fed into GrasslandModels. Everything is float because
    # the cython code in GrasslandModels is set to that.
    predictor_vars = {}
    predictor_vars['precip'] = long_to_wide(everything, index_column = 'date', value_column = 'precip').values.astype(np.float32)
    predictor_vars['evap'] = long_to_wide(everything, index_column = 'date', value_column = 'et').values.astype(np.float32)
    predictor_vars['Tm'] = long_to_wide(everything, index_column = 'date', value_column = 'tmean').values.astype(np.float32)
    predictor_vars['Ra'] = long_to_wide(everything, index_column = 'date', value_column = 'radiation').values.astype(np.float32)
    
    # And site specific values
    predictor_vars['MAP'] = site_level_values.MAP_daymet.values.astype(np.float32)
    predictor_vars['Wp'] = site_level_values.Wp.values.astype(np.float32)
    predictor_vars['Wcap'] = site_level_values.Wcap.values.astype(np.float32)
    
    # Also return the phenocam_name (columns) and date (rows) indexes so the arrays
    # can be put back together later
    site_columns = gcc_pivoted.columns
    date_rows = gcc_pivoted.index
    
    
    return gcc_array, predictor_vars, site_columns, date_rows
