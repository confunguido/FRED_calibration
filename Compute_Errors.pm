#!/usr/bin/perl
###==========
## Guido C.
##
##===========
use strict;
use warnings;
use Cwd;
use POSIX;
my $h = $ENV{home};
package ERROR;
my $cdir = Cwd::getcwd;
require "scripts/GOF_measurements.pm";
my @data;

sub setup{
    my $datafile = shift @_;
    open my $fh,'<',$datafile or die "cannot open $datafile\n";
    while(<$fh>){
	chomp;
	push @data,(split)[1];
    }
}

sub get_error {
    my @p =  @_;
    my $x_min = -100;
    my $x_max = 100;
    my @Y;
    my @x;
    for(my $k = $x_min;$k<=$x_max;$k++){
	my $y = 0;
	my $x_ = $k/10;
	foreach my $i(0..10){
	    last unless(defined($p[$i]));
	    $y += $p[$i] * (($x_) ** ($i));
	}
	push @Y, $y;
	push @x, $x_;
    }
    
    my $error = &least_square(\@Y,\@data);
    return $error;
}
1;
