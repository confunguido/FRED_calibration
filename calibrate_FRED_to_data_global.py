#!/usr/local/bin/python3
import copy
import sys
import re
import os
import subprocess
import argparse
import numpy as np
from scipy.optimize import minimize
from scipy.optimize import basinhopping
#======================================================================
# Functions
#======================================================================
def read_config_file(config_in):    
    params_list = list()
    paramsfh = open(config_in,"r")
    p = 0
    for line in paramsfh:
        line = line.rstrip()
        if re.search("^\#", line):
            continue
        params = re.split("\s+", line)
        if len(params) == 5:
            param_tmp = dict()            
            param_tmp['name'] = params[0]
            param_tmp['init'] = float('%.3f' % float(params[1]))
            param_tmp['step'] = float('%.3f' % float(params[2]))
            param_tmp['min'] = float('%.3f' % float(params[3]))
            param_tmp['max'] = float('%.3f' % float(params[4]))
            params_list.append(param_tmp);
    paramsfh.close()
    if len(params_list) == 0:
        print("Wrong configuration settings in %s" % (config_in))
        quit()
    return(params_list)

def create_params_file(params_in, params_settings, params_base, newparamsfile, seed_in):
    basefh = open(params_base,"r")
    newfh = open(newparamsfile, "w")
    
    for line in basefh:
        line = line.rstrip()
        match_tmp = re.match(r"(?P<name>.*)=(?P<value>.*)", line)
        if match_tmp:
            name_tmp = match_tmp.group("name").strip()
            value_tmp = match_tmp.group("value").strip()
            for p in range(len(params_in)):
                if(params_settings[p]["name"] == name_tmp):
                    value_tmp =  '%.3f' % (float(params_in[p]))
            if name_tmp == "seed" and seed_in == True:
                value_tmp = '%d' % (random.randint(1,1000000000))
                
            newfh.write("%s = %s\n" % (name_tmp, value_tmp))                    
            
    basefh.close()
    newfh.close()
    return(1)

def denormalize_parameters(params_in, params_settings):
    params_out = copy.deepcopy(params_in)
    for p in range(len(params_in)):
        if params_in[p] > 1 : params_in[p] = 1
        if params_in[p] < 0 : params_in[p] = 0        
        params_out[p] = params_settings[p]['min'] + (params_settings[p]['max'] - params_settings[p]['min']) * params_in[p]
    return(params_out)

def normalize_parameters(params_in, params_settings):
    params_out = copy.deepcopy(params_in)
    for p in range(len(params_in)):
        if params_in[p] > params_settings[p]['max'] : params_in[p] = params_settings[p]['max']
        if params_in[p] < params_settings[p]['min'] : params_in[p] = params_settings[p]['min']
        params_out[p] = (params_in[p] - params_settings[p]['min']) / (params_settings[p]['max'] - params_settings[p]['min'])
    return(params_out)


def get_FRED_error(params_norm,params_settings, params_base, data_in, log_in,n_in, seed_in, dir_in="PYOPTIMPARAMSDIR"):
    keylist = list()
    params_in = denormalize_parameters(params_norm, params_settings)
    for p in range(len(params_in)):
        if params_in[p] > params_settings[p]['max'] : params_in[p] = params_settings[p]['max']
        if params_in[p] < params_settings[p]['min'] : params_in[p] = params_settings[p]['min']
        keylist.append('%s=%.3f' % (params_settings[p]['name'], params_in[p]))

    keystr = 'params.' + dir_in + "." + "-".join(keylist)
    newparamsfile = dir_in + "/" + keystr
    create_params_file(params_in, params_settings, params_base, newparamsfile,seed_in)
    
    print("Running FRED to calculate error of %s" % (keystr))
    fred_status = subprocess.run("scripts/fred_get_error.pl -k %s -p %s -data %s -n %d -gof 2" % (keystr,newparamsfile,data_in,n_in), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell = True)
    fred_error = fred_status.stderr.decode()    
    fred_output = fred_status.stdout.decode()
    print('The output from fred-error is: %s' % fred_output)
    error_match = re.match("FRED-DATA-ERROR:(?P<error>.*)",fred_output.splitlines()[-1])
    #error_match = re.match("FRED-DATA-ERROR:(?P<error>.*\n)",fred_output, re.MULTILINE)     
    if error_match:
        strtmp = ','.join([str(p) for p in params_in])
        log_in.write('%s,%.3f,%s\n' % (strtmp,float(error_match.group("error").strip()), keystr))
        print('%s,%.3f,%s' % (strtmp,float(error_match.group("error").strip()), keystr))
        return(float(error_match.group("error").strip()))
    else:
        print("ERROR!! FRED-DATA-ERROR IT did not match %s" % (fred_output))
        quit()
        return(1000000000000)

#======================================================================
# Main function
#======================================================================
def main():    
    parser = argparse.ArgumentParser(
        description='Specify settings for FRED optimization' )
    parser.add_argument("--file", type = str,  help = "Specify config file", required = True)
    parser.add_argument("--data", type = str, help="Specify weekly incidence data", required = True)
    parser.add_argument("--output", type = str, help="Specify name of output fitted parameters file", default = "fitted_params_global.txt")
    parser.add_argument("-p", help = "Specify the baseline parameters file", required = True)
    parser.add_argument("-n", type = int,help = "Number of runs per job [default = 1]", default = 1)
    parser.add_argument("--maxit",type = int, help="Specify the maximum number of iterations [default = 1]", default = 1)
    parser.add_argument("--local",type = int, help="Specify the number of local optimizations [default = 1]", default = 1)
    parser.add_argument("--seed", help="Enable random seed per run", action="store_true", default = False)
    parser.add_argument("--verbose", help="Enable verbose", action="store_true", default = False)
    parser.add_argument("--cleanup", help="Cleanup FRED simulations after calibration", action="store_true", default = False)
    
    args = parser.parse_args()
    config_file = args.file
    params_file = args.p
    data_file = args.data
    nruns = args.n
    max_local = args.local
    max_iter = args.maxit
    params_fit = "output/" + args.output
    enable_random_seed = args.seed
    verbose = args.verbose
    cleanup = args.cleanup

    optimization_dir = "PYOPTIMPARAMSDIRGL"
    os.system("scripts/fred_delete_multiple_jobs.pl -dir %s" % (optimization_dir))
    os.system("rm -r %s" % (optimization_dir))
    parameters = copy.deepcopy(read_config_file(config_file))
    parameters_init = list()
    for k in range(len(parameters)):
        parameters_init.append(parameters[k]['init'])

    parameters_tmp = normalize_parameters(parameters_init,parameters)
    if not os.path.exists(optimization_dir):
        os.makedirs(optimization_dir)
    if not os.path.exists("output"):
        os.makedirs("output")
        
    logfile = optimization_dir + "_LOG.txt"
    loghead = ', '.join([parameters[n]['name'] for n in range(len(parameters))]) + ', error, FREDkey'
    logfh = open(logfile, 'w')
    logfh.write('%s\n' % (loghead))
    
    test_error =  get_FRED_error(parameters_tmp, parameters, params_file, data_file, logfh,nruns,enable_random_seed,dir_in = optimization_dir)
    print("TEST ERROR %.3f * 1.5 = %.3f" % (test_error,test_error * 1.5))
    
    res = basinhopping(get_FRED_error,parameters_tmp,niter = max_local,
                       minimizer_kwargs={'method':'Nelder-Mead',
                                         'options':{'maxiter':max_iter},
                                         'args': (parameters,params_file,data_file,logfh,nruns,enable_random_seed,optimization_dir)},
                       disp=True)
    print(res.x)
    logfh.close()
    create_params_file(denormalize_parameters(res.x,parameters), parameters, params_file, params_fit,enable_random_seed)
    
    if cleanup:
        os.system("scripts/fred_delete_multiple_jobs.pl -dir %s" % (optimization_dir))
        
#======================================================================
# Generate submission files
#======================================================================
if __name__ == '__main__':
    main()
