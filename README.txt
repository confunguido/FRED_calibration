#=============================================================
#TOOLS TO CALIBRATE FRED USING WEEKLY REPORTS OF CASE DATA
# Author: Guido Camargo Espana
# For some simulations with vector control it's necessary
# to have this version of fred_job and defaults
# please copy fred_job to $FRED_HOME/bin
# and defaults to $FRED_HOME/input_files
# Please adjust as necessary to newer versions of FRED
#=============================================================

calibrate_FRED_to_data.py and calibrate_FRED_to_data_global.py are python scripts that perform the same routines as their perl conterparts. They rely on other perl routines to get errors from jobs. Below is a summary of the perl functions. The python routines work in a similar way.

This set of tools takes care of three methods:
     * fred_calibrate_data.pl: Use it to calibrate FRED to weekly data using Nelder-Mead local optimization algorithm
     * fred_calibrate_data_global.pl: Use it to extend the capabilities of fred_calibrate_data.pl to sample in space for multiple initial starting points
     * delete_multiple_jobs.pl: When something goes wrong, this script can delete multiple jobs from a specified directory

To Run this methods, make sure the necessary modules are included in the same directory:
   * FRED_Errors.pm
   * GOF_measurements.pm
   * OPTIMIZATION.pm

Also, make sure that there is a file called params.base with the right parameter values. Without this file, the code won't run.


% fred_calibrate_data.pl [OPTIONS]:
  -f [default: config.txt]. This option specifies the configuration file to read the initial points of the optimization algorithm. See config.txt for a sample.
  
  -gof [default: 2]. Goodness-of-fit measure to apply.
       0. Least squares
       1. Weighted least squares
       2. Chi square
       3. Weighted Chi square
       
  -s [default: 0]. A sufix to add to the name of the job to be used by the 'fred_job' script. This is useful to avoid conflict among jobs. 

  -n [default: 1]. Number of runs for each FRED job

% fred_calibrate_data_global.pl [OPTIONS]:
  -f [default: config.txt]. This option specifies the configuration file to read the initial points of the optimization algorithm. See config.txt for a sample.
  
  -gof [default: 2]. Goodness-of-fit measure to apply.
       0. Least squares
       1. Weighted least squares
       2. Chi square
       3. Weighted Chi square
       
  -n [default: 1]. Number of runs for each FRED job  

% delete_multiple_jobs.pl [dir]
  -dir : Specify the directory with multiple parameter files with the same name as the jobs to delete. Usually it would be something like OPTPARAMSDIR*

