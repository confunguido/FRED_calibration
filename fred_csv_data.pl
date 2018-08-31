#!/usr/bin/perl
###==========
## Guido C.
##
##===========
use strict;
use warnings;
use Getopt::Long;
use Cwd;
use POSIX;
my $h = $ENV{Dhome};
require $h."/personal_Library/Perl_lib/FRED_Errors.pm";

my $key;
my $datafile;
my $variable;
my $help;
my $delay;
my $cumulative;
my $output;
my $gof = 0;
my $result_opts = GetOptions("h"=>\$help,"k=s"=>\$key, "f=s"=>\$datafile, "v=s"=>\$variable, "d=i"=>\$delay,"cum"=>\$cumulative, "o=s"=>\$output, "gof=i"=>\$gof);
die "fred_csv_data -k key -f datafile [-h help] [-d delay in weeks][--cum prints cumulatives]\n" if ($help);
die "please specify a key -k key\n" unless($key);
die "please specify a datafile -f datafile\n" unless($datafile);
die "please specify a variable -v variable \n" unless($variable);

&ERROR::set_gof($gof);
&ERROR::setup($datafile);

my $image;
my ($cum_data,$cum_model,$cum_model_t,$cum_sd,$cum_sd_t) = &ERROR::export_curve_data($key,$variable,$delay,$output);
if($cumulative){
    print "DATA \t MODEL \t MODEL_TOTAL \t MODEL_SD \t MODEL_SD_T\n";
    print "$cum_data\t$cum_model\t$cum_model_t\t$cum_sd\t$cum_sd_t\n";
}


