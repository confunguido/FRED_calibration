#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use POSIX;
use Getopt::Long;
## guido c. ##

sub wleast_square{
    my @expected_array = @{shift @_};
    my @modeled_array = @{shift @_};
    my $mean = 0;
    my $n =0;
    my $SSE = 0;
    foreach (@expected_array){
	$mean += $_;
	$n++;
    }
    $mean /= $n;
    foreach my $i(0..$#expected_array){
	$SSE += $expected_array[$i] * (($modeled_array[$i] - $expected_array[$i]) ** 2);
    }
    return $SSE;
}
sub chi_squared{
    my @expected_array = @{shift @_};
    my @modeled_array = @{shift @_};
    my $SSE = 0;
    foreach my $i(0..$#expected_array){
	$expected_array[$i] = 1 if($expected_array[$i] <=0);
	$SSE +=  ((($modeled_array[$i] - $expected_array[$i]) ** 2) / $expected_array[$i]);
    }
    return $SSE;
}
sub wchi_squared{
    my @expected_array = @{shift @_};
    my @modeled_array = @{shift @_};
    my $SSE = 0;
    my $max_e = 0;
    my $max_m = 0;
    foreach my $i(0..$#expected_array){
	$expected_array[$i] = 1 if($expected_array[$i] <=0);
	$max_e = $expected_array[$i] if($expected_array[$i] > $max_e);
	$max_m = $modeled_array[$i] if($modeled_array[$i] > $max_m);
	$SSE +=  ((($modeled_array[$i] - $expected_array[$i]) ** 2) / $expected_array[$i]);
    }
    $SSE = $SSE + abs(($max_e - $max_m)**2);
    return $SSE;
}
sub least_square_x{
    my @x1 = @{shift @_};
    my @y1 = @{shift @_};
    my @x2 = @{shift @_};
    my @y2 = @{shift @_};
# x1 and y 1 are  the expected arrays, create an expected array based on x2 measurements
    my @expected;
    foreach my $i(0..$#x2){
# find y1 based on y2 and x2, assuming y1 has more samples
	$expected[$i] = $y1[find_x(\@x1,$x2[$i])];
    }
    my $error = &least_square(\@expected,\@y2);
    return $error,\@expected;
}
sub find_x{
    my $cdf_ = shift @_;
    my $r = shift @_;
    my $low = 0;
    my $high = $#{$cdf_};
    my $mid = 0;
    return $low if (${$cdf_}[$low] > $r);
    while(($high - $low) > 1){
#	print "$low - $high - $mid\n";
	$mid = $low + floor(($high - $low) / 2);
	if(${$cdf_}[$mid] > $r){
	    $high = $mid;
	}else{
	    $low = $mid;
	}
	last if ($high == $r);
    }
#    print "$r index: $high val: $$cdf_[$high]\n";
    return $low if (${$cdf_}[$low] > $r);
    return $high;
}
sub least_square{
    my @expected_array = @{shift @_};
    my @modeled_array = @{shift @_};
    my $mean = 0;
    my $n =0;
    my $SSE = 0;
    foreach (@expected_array){
	$mean += $_;
	$n++;
    }
    $mean /= $n;
    foreach my $i(0..$#expected_array){
	next unless (defined($modeled_array[$i]));
	next unless(defined($expected_array[$i]));
	$SSE += (($modeled_array[$i] - $expected_array[$i]) ** 2);
    }
    return $SSE;
}

sub r2{
    my @expected_array = @{shift @_};
    my @modeled_array = @{shift @_};
    my $mean = 0;
    my $n =0;
    my $SST = 0;
    my $SSE = 0;
    foreach (@expected_array){
	$mean += $_;
	$n++;
    }
    $mean /= $n;
    foreach my $i(0..$#expected_array){
	$SSE += (($modeled_array[$i] - $expected_array[$i]) ** 2);
	$SST += (($expected_array[$i] - $mean)** 2);
    }
    my $R2 = 1 - $SSE/$SST;
    return $R2;    
}

1
