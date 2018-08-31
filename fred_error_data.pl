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

require "scripts/FRED_Errors.pm";

my $key;
my $datafile;
my $variable;
my $help;
my $delay;
my $gof = 0;
my $result_opts = GetOptions("h"=>\$help,"k=s"=>\$key, "f=s"=>\$datafile, "v=s"=>\$variable, "d=i"=>\$delay, "gof=i"=>\$gof);
die "fred_plot_data -k key -f datafile [-h help] [-d delay in weeks]\n" if ($help);
die "please specify a key -k key\n" unless($key);
die "please specify a datafile -d datafile\n" unless($datafile);
die "please specify a variable -v variable \n" unless($variable);



&ERROR::setup($datafile);
&ERROR::set_gof($gof);
my $error;
($error) =  &ERROR::get_error_key($key,$variable,$delay);
$error = int($error);
print "$error \n";




