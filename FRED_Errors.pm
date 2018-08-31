#!/usr/bin/perl
###==========
## Guido C.
##
##===========
use strict;
use warnings;
use Cwd;
use POSIX;

package ERROR;
my $cdir = Cwd::getcwd;
my $optdir;
require "scripts/GOF_measurements.pm";
my $fred_csv = "$ENV{FRED_HOME}/bin/fred_csv";
my $fred_find = "$ENV{FRED_HOME}/bin/fred_find";  
my $gnuplot = $ENV{FRED_GNUPLOT};
my $params_base;
my @data;
my $plot = 0;
my @paramnames;
my @fred_data;
my @xdata;
my @fdata;
my $delay;
my $sufix;
my $var;
my $n_runs = 1;
my $cores = 1;
my $gof_measure = 0;
sub set_gof{
# 0 - lsq, 1 - wlsq, 2 - chi squared 3 - w chi squared
    my $gof_ = shift @_;
    if($gof_ < 0 || $gof_ > 3){
	$gof_ = 0;
    }
    $gof_measure = $gof_;
    return 1;
}
sub setup{
    my $datafile = shift @_;
    $params_base = shift @_;
    if($params_base){
	$delay = shift @_;
	@paramnames = @{shift @_};
	$var = shift @_;
	$sufix = shift @_;
	$sufix = "" unless(defined($sufix));
	$optdir = "OPTPARAMSDIR"."$sufix";
	unless(-d $optdir){
	    mkdir( $optdir, 0755) or die "cannot make directory of $optdir\n";
	}else{
	    chdir $optdir;
	    my @files =  <*>;
	    chdir $cdir;
	    my $fs = ":";
	    foreach my $file(@files){
		if($file =~ /params/){
		    my $fred_key = $file;
		    $fred_key =~ s/^params\.//g;
		    system "fred_delete -f -k $fred_key";
		    print "$fred_key deleted\n";
		}
	    }
	    unlink glob $optdir."/*";
	}
    }
# the format of the data needs to be: week    value 
    @data = ();
    open my $fh,'<',$datafile or die "cannot read $datafile\n";
    while(<$fh>){
	chomp;
	next unless (/[0-9]+/);
	push @data, (split)[1];
    }
    close $fh;
}

sub cleanup{
    $sufix = shift @_;
    $sufix = "" unless(defined($sufix));
    $optdir = "OPTPARAMSDIR"."$sufix";
    if(-d $optdir){
	chdir $optdir;
	my @files =  <*>;
	chdir $cdir;
	my $fs = ":";
	foreach my $file(@files){
	    if($file =~ /params/){
		my $fred_key = $file;
		$fred_key =~ s/^params\.//g;
		system "fred_delete -f -k $fred_key";
		print "$fred_key deleted\n";
	    }
	}
    }
}

sub setup_key{
    my $datafile = shift @_;
    $params_base = shift @_;    
    if($params_base){
	$delay = shift @_;
    }else{
	die "specify parameters file\n";
    }    
# the format of the data needs to be: week    value 
    @data = ();
    open my $fh,'<',$datafile or die "cannot read $datafile\n";
    while(<$fh>){
	chomp;
	next unless (/[0-9]+/);
	push @data, (split)[1];
    }
    close $fh;
}

sub get_error{
    my @p = @_;
    my $key = get_fred_key(@p);
#    print "$key\n";
    unless (-e $cdir."/$optdir/params.".$key){
	&create_params_file($key,\@p);
	system "fred_delete -f -k $key"; 
	system "fred_job -k $key -p $optdir/params."."$key -n $n_runs  -m $cores > temp.$sufix";
    }
    my ($error) = get_error_key($key,$var,$delay);
    if($plot){
	&print_curve_data($key,$var,"temp_error.png");
	system "open temp_error.png";
    }
    my $tfile = "temp.".$sufix;
    unlink $tfile;
    return $error;
}
sub get_error_with_key{
    my $key = shift @_;
    $var = shift @_;
    $n_runs = shift @_;
    my $job_found = 0;
    my $found = `$fred_find -k $key 2>&1`;
    chomp($found);
    unless($found =~ /UNKNOWN/){
	$job_found = 1;
    }
    unless($job_found){
	print "JOB $key not found... Running FRED\n";
	system "fred_job -k $key -p $params_base -n $n_runs  -m $cores > temp.$key";
    }
    my ($error) = get_error_key($key,$var,$delay);
    
    if($plot){
	&print_curve_data($key,$var,"temp_error.png");
	system "open temp_error.png";
    }
    my $tfile = "temp.".$key;
    unlink $tfile;
    return $error;
}

sub get_error_key{
    my $key = shift @_;
    my $variable = shift @_;
    my $del = shift @_;
    my $week = "--weekly";
    my @f_data = `$fred_csv -k $key -v $variable $week`;   
    my $fs = ",";
    @xdata = ();
    @fdata = ();
    @fred_data = ();

    foreach(@f_data){
	next unless($_ =~ /^[0-9]+/);
	chomp($_);
	my $val_ = (split /$fs/, $_)[5];
	push @fred_data, $val_;
    }
    my $error = 1000000000000;
    if(defined($del)){
	foreach my $i(0..$#fred_data){
	    next unless($i >= $del && $i < ($del + @data));
	    push @xdata, $data[$i-$del];
	    push @fdata, $fred_data[$i];
	}
	if(@xdata){
	    if($gof_measure == 0){
		$error = &least_square(\@xdata,\@fdata);
	    }elsif($gof_measure == 1){
		$error = &wleast_square(\@xdata,\@fdata);
	    }elsif($gof_measure == 2){
		$error = &chi_squared(\@xdata,\@fdata);
	    }elsif($gof_measure == 3){
		$error = &wchi_squared(\@xdata,\@fdata);
	    }
	}
    }else{
#	print "delay not defined...calculating it\n";
	my @errors;
	my ($epi_pk,$fred_pk) = get_peaktimes(\@fred_data,\@data);
	my $time_delay = $fred_pk - $epi_pk;
	$time_delay = 0 if ($time_delay < 0);
	my $min_delay = $time_delay - 3;
	$min_delay = 0 if($min_delay < 0);
	my $max_delay = $time_delay + 3;
	$max_delay = ($#fred_data - $#data) if ($max_delay > ($#fred_data - $#data));
	$min_delay = $#fred_data - $#data - 2 if ($min_delay >= ($#fred_data - $#data - 2));
	my $min_d;
	my $min_e;
	foreach my $d($min_delay..$max_delay){
	    @xdata = ();
	    @fdata = ();
	    foreach my $i(0..$#fred_data){
		next unless($i >= $d && $i < ($d + @data));
		push @xdata, $data[$i-$d];
		push @fdata, $fred_data[$i];
	    }
	    my $d_ = $d-$min_delay;
	    if($gof_measure == 0){
		$errors[$d_] = &least_square(\@xdata,\@fdata);
	    }elsif($gof_measure == 1){
		$errors[$d_] = &wleast_square(\@xdata,\@fdata);
	    }elsif($gof_measure == 2){
		$errors[$d_] = &chi_squared(\@xdata,\@fdata);
	    }elsif($gof_measure == 3){
		$errors[$d_] = &wchi_squared(\@xdata,\@fdata);
	    }
#	    $errors[$d_] = &least_square(\@xdata,\@fdata) if (@xdata);
#	    print "$d: $errors[$d_]\n";
	}
        $del = &find_minimum(@errors);
	$error = $errors[$del];
	$del += $min_delay;


#	print "$del : $error\n";
    }
    return $error,$del;
}
sub get_peaktimes{
    my @fdata = @{shift @_};
    my @edata = @{shift @_};
    my $fred_max = 0;
    my $epi_max = 0;
    my $fred_peaktime = 0;
    my $epi_peaktime = 0;
    foreach my $i(0..$#fdata){
	if($fdata[$i] > $fred_max){
	    $fred_peaktime = $i;
	    $fred_max = $fdata[$i];
	}
    }
    foreach my $i(0..$#edata){
	if($edata[$i] > $epi_max){
	    $epi_peaktime = $i;
	    $epi_max = $edata[$i];
	}
    }
    return $epi_peaktime, $fred_peaktime;
}
sub find_minimum{
    my @x = @_;
    my $min_;
    my $min_v;
    foreach my $i(0..$#x){
	if($i == 0){
	    $min_ = 0;
	    $min_v = $x[0];
	}else{
	    if($x[$i] < $min_v){
		$min_v = $x[$i];
		$min_ = $i;
	    }
	}
    }
    return $min_;
}

sub print_curve_data{
    my $key = shift @_;
    my $variable = shift @_;
    my $output_image = shift @_;
    my $del = shift @_;
    my $eps = shift @_;
    my $plot_title = shift @_;
    my $color_d = "\#006666";
   # my $color_d = "\#CCFFFF";
    my $error;
    ($error,$del) = get_error_key($key,$variable,$del);
    $error  = int($error);
    my $week = "--weekly";
    my @f_data = `$fred_csv -k $key -v $variable $week`;   
    my $temp_data = "temp_data_$variable";
    open my $fh,'>',$temp_data or die "cannot open $temp_data\n";
    my $fs = ",";
    @fred_data = ();
    foreach(@f_data){
	next unless($_ =~ /^[0-9]+/);
	chomp($_);
	my $val_ = (split /$fs/, $_)[5];
	push @fred_data, $val_;
    }
    foreach my $i(0..$#fred_data){
	if($i >= $del && $i < ($del + @data)){
	    print {$fh} "$i\t$data[$i-$del]\t $fred_data[$i]\n";
	}else{
	    print {$fh} "$i\tNaN\t$fred_data[$i]\n";	    
	}
    }
    my $temp_gnu = "plot-FRED-$variable.plt";
    my $end = $eps ? "eps" : "png";
    my $title = $plot_title ? "\"".$plot_title."\"" : "\" FRED Simulation of $variable \\nKey: $key\\nError: $error Delay: $del\"";
    my $terminal = $eps ? "postscript eps enhanced color colortext font \",30\" size 7,5" : "pngcairo dashed font \"/Library/Fonts/Arial.ttf\" size 900, 700";
    $output_image = "plot-FRED-$variable.$end" unless ($output_image);
    open my $fhg,'>',$temp_gnu or die "cannot open $temp_gnu\n";
    print {$fhg}<<EOF;
\#!$gnuplot
reset
set terminal $terminal
set output \"$output_image\"
set boxwidth 0.7
set style fill solid
set xlabel \"Simulation Weeks\"
set ylabel \"People\"
set title $title
set yrange [:]
plot \'$temp_data\' u 1:3 w l ls -1 lw 4 lc rgb \'\#606060\' t \'FRED\',  \'\' u 1:2 w lp ps 2 pt 3 lw 4 lc rgb \'$color_d\' t \'Data\'
EOF
close $fhg;
#  \'\' u 1:2 w l ls 3 lc rgb '#006666' t \'\',
    chmod 0755,$temp_gnu;
    system "$gnuplot $temp_gnu";
    return $output_image;
}
sub print_curve_data_cum{
    my $key = shift @_;
    my $variable = shift @_;
    my $output_image = shift @_;
    my $del = shift @_;
    my $eps = shift @_;
    my $plot_title = shift @_;
    my $color_d = "\#006666";
   # my $color_d = "\#CCFFFF";
    my $error;
    ($error,$del) = get_error_key($key,$variable,$del);
    $error  = int($error);
    my $week = "--weekly";
    my @f_data = `$fred_csv -k $key -v $variable $week`;   
    my $temp_data = "temp_data_$variable";
    open my $fh,'>',$temp_data or die "cannot open $temp_data\n";
    my $fs = ",";
    @fred_data = ();
    my $sum_ = 0;
    foreach(@f_data){
	next unless($_ =~ /^[0-9]+/);
	chomp($_);
	my $val_ = (split /$fs/, $_)[5];
	$sum_ += $val_;
	push @fred_data, $sum_;
    }
    foreach my $i(0..$#fred_data){
	if($i >= $del && $i < ($del + @data)){
	    print {$fh} "$i\t$data[$i-$del]\t $fred_data[$i]\n";
	}else{
	    print {$fh} "$i\tNaN\t$fred_data[$i]\n";	    
	}
    }
    my $temp_gnu = "plot-FRED-$variable.plt";
    my $end = $eps ? "eps" : "png";
    my $title = $plot_title ? "\"".$plot_title."\"" : "\" FRED Simulation of $variable \\nKey: $key\\nError: $error Delay: $del\"";
    my $terminal = $eps ? "postscript eps enhanced color colortext font \",30\" size 7,5" : "pngcairo dashed font \"/Library/Fonts/Arial.ttf\" size 900, 700";
    $output_image = "plot-FRED-$variable.$end" unless ($output_image);
    open my $fhg,'>',$temp_gnu or die "cannot open $temp_gnu\n";
    print {$fhg}<<EOF;
\#!$gnuplot
reset
set terminal $terminal
set output \"$output_image\"
set boxwidth 0.7
set style fill solid
set xlabel \"Simulation Weeks\"
set ylabel \"People\"
set title $title
set yrange [:]
plot \'$temp_data\' u 1:3 w l ls -1 lw 4 lc rgb \'\#606060\' t \'FRED\',  \'\' u 1:2 w lp ps 2 pt 3 lw 4 lc rgb \'$color_d\' t \'Data\'
EOF
close $fhg;
#  \'\' u 1:2 w l ls 3 lc rgb '#006666' t \'\',
    chmod 0755,$temp_gnu;
    system "$gnuplot $temp_gnu";
    return $output_image;
}
sub print_curve_data_e{
    my $key = shift @_;
    my $variable = shift @_;
    my $output_image = shift @_;
    my $del = shift @_;
    my $eps = shift @_;
    my $plot_title = shift @_;
    my $error;
    my $color_d = "\#006666";
#    my $color_d = "\#CCFFFF";
    ($error,$del) = get_error_key($key,$variable,$del);
    $error  = int($error);
    my $week = "--weekly";
    my @f_data = `$fred_csv -k $key -v $variable $week`;   
    my $temp_data = "temp_data_$variable";
    open my $fh,'>',$temp_data or die "cannot open $temp_data\n";
    my $fs = ",";
    @fred_data = ();
    my @fred_sd = ();
    foreach(@f_data){
	next unless($_ =~ /^[0-9]+/);
	chomp($_);
	my ($val_,$sd_) = (split /$fs/, $_)[5,6];
	push @fred_data, $val_;
	push @fred_sd, $sd_;
    }
    foreach my $i(0..$#fred_data){
	if($i >= $del && $i < ($del + @data)){
	    print {$fh} "$i\t$data[$i-$del]\t $fred_data[$i] \t $fred_sd[$i]\n";
	}else{
	    print {$fh} "$i\tNaN\t$fred_data[$i]\t$fred_sd[$i]\n";	    
	}
    }
    my $temp_gnu = "plot-FRED-$variable.plt";
    my $end = $eps ? "eps" : "png";
    my $title = $plot_title ? "\"".$plot_title."\"" : "\" FRED Simulation of $variable \\nKey: $key\\nError: $error Delay: $del\"";
    my $terminal = $eps ? "postscript eps enhanced color colortext font \",30\" size 7,5" : "pngcairo dashed font \"/Library/Fonts/Arial.ttf\" size 900, 700";
    $output_image = "plot-FRED-$variable.$end" unless ($output_image);
    open my $fhg,'>',$temp_gnu or die "cannot open $temp_gnu\n";
    print {$fhg}<<EOF;
\#!$gnuplot
reset
set terminal $terminal;
set output \"$output_image\"
set boxwidth 0.7
set style fill solid
set xlabel \"Simulation Weeks\"
set ylabel \"People\"
set title $title
set yrange [0:]
plot \'$temp_data\' u 1:3 w l ls -1 lw 4 lc rgb '#606060' t \'FRED\', \'\' u 1:3:(\$3+\$4):(\$3-\$4) w yerrorbars ls -1 lw 2 lc rgb '#606060' t \'\',  \'\' u 1:2 w lp ps 2 pt 3 lw 4 lc rgb \'$color_d\' t \'Data\'
EOF
close $fhg;
    chmod 0755,$temp_gnu;
    system "$gnuplot $temp_gnu";
    return $output_image;
}
sub print_curve_data_cum_e{
    my $key = shift @_;
    my $variable = shift @_;
    my $output_image = shift @_;
    my $del = shift @_;
    my $eps = shift @_;
    my $plot_title = shift @_;
    my $error;
    my $color_d = "\#006666";
#    my $color_d = "\#CCFFFF";
    ($error,$del) = get_error_key($key,$variable,$del);
    $error  = int($error);
    my $week = "--weekly";
    my @f_data = `$fred_csv -k $key -v $variable $week`;   
    my $temp_data = "temp_data_$variable";
    open my $fh,'>',$temp_data or die "cannot open $temp_data\n";
    my $fs = ",";
    @fred_data = ();
    my @fred_sd = ();
    my $sum_ = 0;
    my $sum_sd = 0;
    foreach(@f_data){
	next unless($_ =~ /^[0-9]+/);
	chomp($_);
	my ($val_,$sd_) = (split /$fs/, $_)[5,6];
	$sum_ += $val_;
	$sum_sd += $sd_;
	push @fred_data, $sum_;
	push @fred_sd, $sum_sd;
    }
    foreach my $i(0..$#fred_data){
	if($i >= $del && $i < ($del + @data)){
	    print {$fh} "$i\t$data[$i-$del]\t $fred_data[$i] \t $fred_sd[$i]\n";
	}else{
	    print {$fh} "$i\tNaN\t$fred_data[$i]\t$fred_sd[$i]\n";	    
	}
    }
    my $temp_gnu = "plot-FRED-$variable.plt";
    my $end = $eps ? "eps" : "png";
    my $title = $plot_title ? "\"".$plot_title."\"" : "\" FRED Simulation of $variable \\nKey: $key\\nError: $error Delay: $del\"";
    my $terminal = $eps ? "postscript eps enhanced color colortext font \",30\" size 7,5" : "pngcairo dashed font \"/Library/Fonts/Arial.ttf\" size 900, 700";
    $output_image = "plot-FRED-$variable.$end" unless ($output_image);
    open my $fhg,'>',$temp_gnu or die "cannot open $temp_gnu\n";
    print {$fhg}<<EOF;
\#!$gnuplot
reset
set terminal $terminal;
set output \"$output_image\"
set boxwidth 0.7
set style fill solid
set xlabel \"Simulation Weeks\"
set ylabel \"People\"
set title $title
set yrange [0:]
plot \'$temp_data\' u 1:3 w l ls -1 lw 4 lc rgb '#606060' t \'FRED\', \'\' u 1:3:(\$3+\$4):(\$3-\$4) w yerrorbars ls -1 lw 2 lc rgb '#606060' t \'\',  \'\' u 1:2 w lp ps 2 pt 3 lw 4 lc rgb \'$color_d\' t \'Data\'
EOF
close $fhg;
    chmod 0755,$temp_gnu;
    system "$gnuplot $temp_gnu";
    return $output_image;
}
sub export_curve_data{
    my $key = shift @_;
    my $variable = shift @_;
    my $del = shift @_;
    my $temp_out = shift @_;
    my $error;
    ($error,$del) = get_error_key($key,$variable,$del);
    $error  = int($error);
    my $week = "--weekly";
    my @f_data = `$fred_csv -k $key -v $variable $week`;   
    my $temp_data;
    if($temp_out){
	$temp_data = $temp_out;
    }else{
	$temp_data = "temp_data_$variable";
    }
    open my $fh,'>',$temp_data or die "cannot open $temp_data\n";
    my $fs = ",";
    @fred_data = ();
    my @fred_sd = ();
    my @fr_data = ();
    my @fred_sd_data = ();
    foreach(@f_data){
	next unless($_ =~ /^[0-9]+/);
	chomp($_);
	my ($val_,$sd_) = (split /$fs/, $_)[5,6];
	push @fred_data, $val_;
	push @fred_sd, $sd_;
    }
    foreach my $i(0..$#fred_data){
	if($i >= $del && $i < ($del + @data)){
	    print {$fh} "$i\t$data[$i-$del]\t $fred_data[$i] \t $fred_sd[$i]\n";
	    push @fr_data,$fred_data[$i];
	    push @fred_sd_data,$fred_sd[$i];
	}else{
	    print {$fh} "$i\tNaN\t$fred_data[$i]\t$fred_sd[$i]\n";	    
	}
    }
    my $cum_data = &sum(@data);
    my $cum_model_t = &sum(@fred_data);
    my $cum_model = &sum(@fr_data);
    my $cum_sd = &sum(@fred_sd_data);
    my $cum_sd_t = &sum(@fred_sd); 
    return $cum_data,$cum_model,$cum_model_t,$cum_sd,$cum_sd_t;
}
sub sum{
    my $sum = 0;
    foreach(@_){
	$sum += $_;
    }
    return $sum;
}
sub get_fred_key{
    my @pv = @_;
    my $key;
    my $temp_key;
    my @pstring;
    for(my $i=0;$i<@pv;$i++){
	my $p_v = sprintf("%.3f",$pv[$i]);
	$pstring[$i] = join "=",$paramnames[$i],$p_v;
    }
    $temp_key = join "-", @pstring;
    $key = join ":",$sufix,$temp_key;
    return $key;
}

sub create_params_file{
    my $fred_key = shift @_;
    my @param_values = @{shift @_};
#    print "@param_values @paramnames \n";
    die "unable to open $params_base to create a param for the new key\n" if (! open PARAMBASE,'<',$cdir."/$params_base");
    die "Cannot open /$optdir/params.$fred_key to create a new param file\n" if (!open NEWPARAMS, '>',$cdir."/$optdir/params.".$fred_key);
    select NEWPARAMS;
    while(<PARAMBASE>){
	foreach my $i(0..$#paramnames){
	    s/($paramnames[$i])\s+=.*/$paramnames[$i] = $param_values[$i]/;
	}
        print;
    }
    close NEWPARAMS;
    close PARAMBASE;
    select STDOUT;
}


1;
