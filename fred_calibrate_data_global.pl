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

my $config_file = "config.txt";
my $params_base = "params_base.txt";
my $log = "GLOBAL_LOG.txt";
my @init;
my @pnames;
my @step;
my @const_b;
my @const_t;
my $gof = 2;
my $delay;
my $datafile = "data.txt";
my $nruns = 1;
my $max_local = 5;
my $enable_multiple_seeds = 0;
my $maxit = 100;
my $verbose = 0;
my $cleanup;
my $paramsout = "params_fitted_local.txt";
my $results = GetOptions("gof=i"=>\$gof, "f=s"=>\$config_file, 
			 "n=i"=>\$nruns, "p=s"=>\$params_base, 
			 "seed"=>\$enable_multiple_seeds, "maxit=i"=>\$maxit,
			 "local=i"=>\$max_local, "data=s"=>\$datafile,
			 "verbose=i"=>\$verbose, "cleanup"=>\$cleanup,
			 "output=s"=>\$paramsout);

my @error_by_it;
&ERROR::set_gof($gof);
&initial_conditions($config_file);
open my $logfh,'>',$log or die "cannot open $log\n";
my $formats = "%s\t".("%s\t"x @pnames)."%s\t%s\n";
printf {$logfh} $formats, "Iteration",@pnames," Error","key";
my $format = "%d\t".("%.3f\t"x @pnames)."%.4f\t%s\n";
my %fittedkeys;
foreach my $it(0..$max_local){
    print "Local optimization iteration $it\n";
    # generate random initial conditions
    my @random_values = @{&generate_random_values};
    print "initial conditions: @random_values\n";
    &ERROR::setup($datafile,$params_base,$delay,\@pnames,"Cs","Gl$it");    

    my $error = &ERROR::get_error(@random_values);
    print "Iteration $it, initial Conditions: @random_values Error : $error\n";
    ## calibrate the parameters
    
    &OPTIMIZATION::setup($maxit,100);
    &OPTIMIZATION::verbose($verbose);
    my @p = &OPTIMIZATION::nelder_mead_simplex(\@random_values,\@step,\@const_b,\@const_t);
    $error = &ERROR::get_error(@p);
    my $key = &ERROR::get_fred_key(@p);
    &ERROR::print_curve_data($key,"Cs","fred_opt_$it.png");
    
    unless(-d "output"){
	mkdir("output", 0755) or die "cannot make directory of output\n";
    }
    my $paramsfittedtmp = "output/params_fitted_global_it_".$it.".txt";
    my $tmpparams = "OPTPARAMSDIRGl".$it."/params.".$key;
    
    system "cp $tmpparams $paramsfittedtmp";
    print "Iteration $it: @pnames values: @p Key: $key\nError $error\n";
    $error_by_it[$it] = $error;
    $fittedkeys{$it} = $key;
    printf {$logfh} $format, $it,@p,$error,$key;
    
    if($cleanup){
	&ERROR::cleanup("GL$it");
    }
}
my $in = find_minimum(@error_by_it);
my $paramsfitted = "output/".$paramsout;
my $tmpparams = "OPTPARAMSDIRGl".$in."/params.".$fittedkeys{$in};
system "cp $tmpparams $paramsfitted";

print "Min: $error_by_it[$in] iteration $in, key: $fittedkeys{$in}, output: $paramsfitted\n";
close $logfh;

#-----sub routines
sub generate_random_values{
    my @rarray;
    foreach my $i (0 ..$#init){
	$rarray[$i] =  rand($const_t[$i] - $const_b[$i]) + $const_b[$i];
    }
    return \@rarray;
}
sub find_minimum{
    my @x = @_;
    my $min;
    my $min_v;
    foreach my $i(0..$#x){
	if($i == 0){
	    $min = 0;
	    $min_v = $x[0];
	}else{
	    if($x[$i] < $min_v){
		$min_v = $x[$i];
		$min = $i;
	    }
	}
    }
    return $min;
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



