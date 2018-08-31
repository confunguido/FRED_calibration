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
my $output;
my $delay;
my $gof = 0;
my $eps;
my $error_bars;
my $title;
my $cum;
my $result_opts = GetOptions("h"=>\$help,"k=s"=>\$key, "f=s"=>\$datafile, "v=s"=>\$variable,"o=s"=>\$output, "d=i"=>\$delay, "gof=i"=>\$gof, "eps"=>\$eps, "t=s"=>\$title, "e"=>\$error_bars,"cum"=>\$cum);
die "fred_plot_data -k key -f datafile [-h help] [-o output image] [-d delay in weeks]\n\t[-gof goodness of fit measure] [--eps produce an eps figure] [-t title][--e errorbars]\n" if ($help);
die "please specify a key -k key\n" unless($key);
die "please specify a datafile -f datafile\n" unless($datafile);
die "please specify a variable -v variable \n" unless($variable);


&ERROR::set_gof($gof);
&ERROR::setup($datafile);

my $image;
if($error_bars){
    unless($cum){
	$image = &ERROR::print_curve_data_e($key,$variable,$output,$delay,$eps,$title);
    }else{
	$image = &ERROR::print_curve_data_cum_e($key,$variable,$output,$delay,$eps,$title);
    }
}else{
    unless($cum){
	$image = &ERROR::print_curve_data($key,$variable,$output,$delay,$eps,$title);
    }else{
	$image = &ERROR::print_curve_data_cum($key,$variable,$output,$delay,$eps,$title);
    }
}

system "open $image";


