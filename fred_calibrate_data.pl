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
require "scripts/OPTIMIZATION.pm";

my $config_file = "config";
my $params_base = "params_base.txt";
my @init;
my @pnames;
my @step;
my @const_b;
my @const_t;
my $gof = 2;
my $sufix = "0";
my $delay;
my $cleanup;
my $datafile = "data.txt";
my $maxit = 100;
my $verbose = 0;
my $enable_multiple_seeds;
my $nruns = 1;
my $paramsout = "params_fitted_local.txt";
my $results = GetOptions("gof=i"=>\$gof, "s=s"=>\$sufix, "f=s"=>\$config_file, 
			 "n=i"=>\$nruns, "p=s"=>\$params_base, "data=s"=>\$datafile,
			 "seed"=>\$enable_multiple_seeds, "maxit=i"=>\$maxit,
			 "output=s"=>\$paramsout,
			 "verbose=i"=>\$verbose, "cleanup"=>\$cleanup);


&initial_conditions($config_file);

&ERROR::set_gof($gof);
&ERROR::setup($datafile,$params_base,$delay,\@pnames,"Cs",$sufix);


my $error = &ERROR::get_error(@init);
print "Initial Error: $error\n";


&OPTIMIZATION::setup($maxit,100);
&OPTIMIZATION::verbose($verbose);
my @p = &OPTIMIZATION::nelder_mead_simplex(\@init,\@step,\@const_b,\@const_t);
$error = &ERROR::get_error(@p);
my $key = &ERROR::get_fred_key(@p);

unless(-d "output"){
    mkdir("output", 0755) or die "cannot make directory of output\n";
}
my $paramsfitted = "output/".$paramsout;
my $tmpparams = "OPTPARAMSDIR".$sufix."/params.".$key;

system "cp $tmpparams $paramsfitted";
print "@pnames values: @p.\nError $error\n$key\n$paramsfitted\n";

if($cleanup){
    &ERROR::cleanup($sufix);
}


sub initial_conditions{
    my $c_file = shift @_;
    open my $fh,'<',$c_file or die "cannot open $c_file\n";
    while(<$fh>){
	chomp;
	next if($_ =~/^\#/);
	next if($_ eq "");
	my ($name,$init_,$step_,$b_co,$t_co) = split;
	push @init, $init_;
	push @pnames, $name;
	push @step, $step_;
	push @const_b, $b_co;
	push @const_t, $t_co;
    }
    close $fh;
    die "not correct configuration file\n" unless(@init && @pnames && @step && @const_b && @const_t);
    return 1;
}

