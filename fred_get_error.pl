#!/usr/bin/perl
#============================================================================
# Guido Espana
# This script computes the error of FRED against weekly incidence data
#============================================================================
use strict;
use warnings;
use Getopt::Long;
use Cwd;
use POSIX;

require "scripts/FRED_Errors.pm";

my $params_file = "params.base";
my $gof = 2;
my $delay;
my $datafile = "data.txt";
my $nruns = 1;
my $help;
my $key;
my $variable = "Cs";
my $results = GetOptions(    
    "gof=i"=>\$gof, "k=s"=>\$key, "var=s"=>\$variable,
    "n=i"=>\$nruns, "p=s"=>\$params_file, "data=s"=>\$datafile, "h"=>\$help);

if($help){
    die " fred_get_error.pl [options] get error from FRED compared to data
\t\t -gof [2] select a goodness of fit measure
\t\t -k FRED key
\t\t -var [Cs] variable to compare FRED results to data
\t\t -n [1] number of runs per job
\t\t -p [params.base] choose a parameters file
\t\t -data [data.txt] choose a file with the weekly timeseries
\t\t -h display this message
";
}
unless($key){
    die "Please specify a FRED key\n";
}
    
&ERROR::set_gof($gof);
&ERROR::setup_key($datafile,$params_file,$delay);

my $error = &ERROR::get_error_with_key($key, $variable,$nruns);
print "FRED-DATA-ERROR:$error\n";

