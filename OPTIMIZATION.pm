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


package OPTIMIZATION;
my $cdir = Cwd::getcwd;
#print "$cdir\n";
my $dimensions; 
my $max_eq_error = 100;
my $vertices;
my @initial_points;
my @initial_step;
my @b_constrains;
my @t_constrains;
my $threshold = 0.00000001;
my $iterations = 150;
my $worst_simplex_error = 0;
my $verbose = 0;
my $X = 2;
my $p = 1;
my $G = 0.5;
my $o = 0.5;
sub setup{
#    print "SETUP\n";
    $iterations = shift @_;
    $max_eq_error = shift @_;
}
sub verbose{
    $verbose = shift @_;
}
sub nelder_mead_simplex{    
    @initial_points = @{shift @_};
    @initial_step = @{shift @_};
    @b_constrains = @{shift @_}; 
    @t_constrains = @{shift @_};
    my @simplex;
    my @error_simplex;
    my $prev_error = -1;
    my $error_counter = 0;
    $dimensions =  @initial_points;
    $vertices = $dimensions + 1;
    @simplex = @{&build_initial_simplex(\@simplex)};
    print_simplex(\@simplex) if($verbose);
  NELDERMEAD:for(my $it = 0;$it<$iterations;$it++){
## Order the simplex
      @error_simplex = @{&get_simplex_error(\@simplex)};
      @simplex = @{&order_simplex_by_error(\@error_simplex, \@simplex)};
      @error_simplex = @{&get_simplex_error(\@simplex)};
      $error_counter++ if($prev_error == $error_simplex[0]);
      $prev_error = $error_simplex[0];
      print "$it $error_simplex[0]\n" if ($verbose > 0);
      print_simplex(\@simplex) if ($verbose);
      
      if ($error_counter >= $max_eq_error){
	  print "Multiple iterations with the same error.. iterations: $it\n";
	  last NELDERMEAD;
      }
      if($error_simplex[0] <= $threshold){
	  print "Error Tolerance Met\n";
	  last NELDERMEAD;
      }
      
      my @reflected_vertix = @{&reflexion(\@simplex)};
      my $ref_error = &get_vertix_error(\@reflected_vertix);
      my $best_error = &get_vertix_error($simplex[0]);
      my $worst_error = &get_vertix_error($simplex[-2]);
      print "ref $ref_error best $best_error n_error $worst_error\n" if ($verbose > 1);
      
      if(($ref_error < $worst_error) && ($ref_error >= $best_error)){
	  $simplex[-1] = \@reflected_vertix;
	  print_simplex(\@simplex) if ($verbose);
	  next NELDERMEAD;
      }elsif($ref_error < $best_error){
# calculate the expansion point
	  my @expanded_vertix = @{&expansion(\@simplex)};
	  my $exp_error = &get_vertix_error(\@expanded_vertix);
	  print "exp: $exp_error ref $ref_error best $best_error n_error $worst_error\n" if ($verbose > 1);
	  if($exp_error < $ref_error){
	      $simplex[-1] = \@expanded_vertix;
	      next NELDERMEAD;
	  }else{
	      $simplex[-1] = \@reflected_vertix;
	      next NELDERMEAD;
	  }
      }else{
# if ref point >= worst point
	  my $last_error = &get_vertix_error($simplex[-1]);
	  if($ref_error < $last_error){
	      my @out_vertix = @{&outside_contract(\@simplex)};
	      my $out_error = &get_vertix_error(\@out_vertix);
	      print "outside error: $out_error reflected error: $ref_error n+1 error: $last_error\n" if ($verbose > 1);
	      if($out_error <= $ref_error){
		  $simplex[-1] = \@out_vertix;
		  next NELDERMEAD;
	      }
	  }else{
	      my @in_vertix = @{&inside_contract(\@simplex)};
	      my $in_error = &get_vertix_error(\@in_vertix);
	      print "inside error: $in_error reflected error: $ref_error n+1 error: $last_error\n" if ($verbose);
	      if($in_error < $last_error){
		  $simplex[-1] = \@in_vertix;
		  next NELDERMEAD;
	      }
	  }
# if none of the steps reduced the error, perform a shrink step
	  @simplex = @{&shrink(\@simplex)};

      }
  }
    print "Nelder-Mead optimization algorithm ended: params: @{$simplex[0]}\n";
    return @{$simplex[0]};
}

sub print_simplex{
    my @s = @{shift @_};
    print "SIMPLEX\n" ;
    foreach(@s){
	print "@{$_}\n";
    }
}
sub reflexion{
    my $simplex_ = shift @_;
    my @mean_simplex = @{&calculate_mean_vector($simplex_)};
    my @reflected_vertix;
    print "REFLEXION\n" if ($verbose);
    for(my $i = 0;$i<$dimensions;$i++){
	$reflected_vertix[$i] = (1+$p)*$mean_simplex[$i] - $p * $$simplex_[$dimensions][$i];
    }
#    @reflected_vertix = @{&check_b_constrains(\@reflected_vertix)};
#    @reflected_vertix = @{&check_t_constrains(\@reflected_vertix)};
    print "@reflected_vertix\n" if ($verbose);
    return \@reflected_vertix;
}
sub expansion{
    my $simplex_ = shift @_;
    my @mean_simplex = @{&calculate_mean_vector($simplex_)};
    my @expanded_vertix;
    print "EXPANSION\n" if ($verbose);
    for(my $i = 0;$i<$dimensions;$i++){
	$expanded_vertix[$i] = (1+$p*$X)*$mean_simplex[$i] - $p * $X * $$simplex_[$dimensions][$i];
    }
#    @expanded_vertix = @{&check_b_constrains(\@expanded_vertix)};
#    @expanded_vertix = @{&check_t_constrains(\@expanded_vertix)};
    print "@expanded_vertix\n" if ($verbose);
    return \@expanded_vertix;
}
sub outside_contract{
    my $simplex_ = shift @_;
    my @mean_simplex = @{&calculate_mean_vector($simplex_)};
    my @outside_vertix;
    print "OUTSIDE CONTRACTION\n" if ($verbose);
    for(my $i = 0;$i<$dimensions;$i++){
	$outside_vertix[$i] = (1+$p*$G)*$mean_simplex[$i] - $p * $G * $$simplex_[$dimensions][$i];
    }
#    @outside_vertix = @{&check_b_constrains(\@outside_vertix)};
#    @outside_vertix = @{&check_t_constrains(\@outside_vertix)};
    print "@outside_vertix\n" if ($verbose);
    return \@outside_vertix;
}

sub inside_contract{
    my $simplex_ = shift @_;
    my @mean_simplex = @{&calculate_mean_vector($simplex_)};
    my @inside_vertix;
    print "INSIDE CONTRACTION\n" if ($verbose);
    for(my $i = 0;$i<$dimensions;$i++){
	$inside_vertix[$i] = (1-$G)*$mean_simplex[$i] +  $G * $$simplex_[$dimensions][$i];
    }
#    @inside_vertix = @{&check_b_constrains(\@inside_vertix)};
#    @inside_vertix = @{&check_t_constrains(\@inside_vertix)};
    print "@inside_vertix\n" if ($verbose);
    return \@inside_vertix;
}
sub shrink{
    my $simplex_ = shift @_;
    my @shrink_simplex;
    for (my $n = 0;$n < $vertices;$n++){
	for (my $i = 0; $i<$dimensions;$i++){
	    if($n==0){
		$shrink_simplex[$n][$i] = $$simplex_[0][$i];
	    }else{
		$shrink_simplex[$n][$i] = $$simplex_[0][$i] + $o * ($$simplex_[$n][$i] - $$simplex_[0][$i]);
	    }
	}
    }
    print "SHRINK\n" if ($verbose);
    foreach(@shrink_simplex){
	print "@{$_}\n" if ($verbose);
    }
    return \@shrink_simplex;
}
sub calculate_mean_vector{
    my @simplex_ = @{shift @_};
    my @mean_simplex;
    for(my $i = 0;$i < $dimensions;$i++){
	$mean_simplex[$i] =0;
	for(my $j = 0;$j < $dimensions;$j++){
	    $mean_simplex[$i] += $simplex_[$j][$i];
	}
	$mean_simplex[$i] /= ($dimensions);
    }
    print "@mean_simplex\n" if ($verbose > 1);
    return \@mean_simplex;
}

sub build_initial_simplex{
#initial vertix
    my @simplex_ = @{shift @_};

    for (my $n = 0;$n < $vertices;$n++){
	for (my $i = 0; $i<$dimensions;$i++){
	    if($n==0){
		$simplex_[$n][$i] = $initial_points[$i]; 
	    }else{
		if($i == $n - 1){
		    $simplex_[$n][$i] = $initial_points[$i] + $initial_step[$i]; 
		}else{
		    $simplex_[$n][$i] = $initial_points[$i];
		}
	    }
#
#	    }elsif($n<$dimensions){
#		if($i < $n){
#		    $simplex_[$n][$i] = $initial_points[$i] + $initial_step[$i]; 
#		}else{
#		    $simplex_[$n][$i] = $initial_points[$i] - $initial_step[$i]; 
#		}
#	    }else{
#		if($i < $n - 1){
#		    $simplex_[$n][$i] = $initial_points[$i];
#		}else{
#		    $simplex_[$n][$i] = $initial_points[$i] + $initial_step[$i]; 
#		}
#	    }
	}
	my @vertix = @{$simplex_[$n]};
#	@vertix = @{&check_b_constrains(\@vertix)};
#        @vertix = @{&check_t_constrains(\@vertix)};
	for (my $i = 0; $i<$dimensions;$i++){
	    $simplex_[$n][$i] = $vertix[$i];
	}
    }
    return \@simplex_;
}

sub check_b_constrains{
    my @vertix = @{shift @_};
    print "@vertix \n" if ($verbose > 1);
    if(@b_constrains){
	for(my $i = 0;$i<$dimensions;$i++){
	    if(defined($b_constrains[$i])){
		if($vertix[$i] < $b_constrains[$i]){
		    $vertix[$i] = $b_constrains[$i];
		}
	    }
	}
    }
    print "b cons: @vertix\n" if ($verbose > 1);
    return \@vertix;
}
sub check_t_constrains{
    my @vertix = @{shift @_};
    if(@t_constrains){
	for(my $i = 0;$i<$dimensions;$i++){
	    if(defined($t_constrains[$i])){
		if($vertix[$i] > $t_constrains[$i]){
		    $vertix[$i] = $t_constrains[$i];
		}
	    }
	}
    }
    print "t cons: @vertix\n" if ($verbose > 1);
    return \@vertix;
}
sub t_constrains{
    my @vertix = @{shift @_};
    my $out_of_bounds = 0;
    if(@t_constrains){
	for(my $i = 0;$i<$dimensions;$i++){
	    if(defined($t_constrains[$i])){
		if($vertix[$i] > $t_constrains[$i]){
		    $out_of_bounds = 1;
		}
	    }
	}
    }
    print "t cons: @vertix out of bounds\n" if ($verbose > 1);
    return $out_of_bounds;
}
sub b_constrains{
    my @vertix = @{shift @_};
    my $out_of_bounds = 0;
    if(@b_constrains){
	for(my $i = 0;$i<$dimensions;$i++){
	    if(defined($b_constrains[$i])){
		if($vertix[$i] < $b_constrains[$i]){
		    $out_of_bounds = 1;
		}
	    }
	}
    }
    print "b cons: @vertix out of bounds\n" if ($verbose > 1);
    return $out_of_bounds;
}
sub get_vertix_error{
    my $v = shift @_;
    my $out_of_bounds = 0;
    print "calculating vertix error @{$v}\n" if ($verbose > 2);
# check for constrains if it's out of bound then the error is worst error + 1
    $out_of_bounds += &b_constrains($v);
    $out_of_bounds += &t_constrains($v);
    my $error;
    if($out_of_bounds == 0){
        $error = &ERROR::get_error(@{$v});
	if($error > $worst_simplex_error){
	    $worst_simplex_error = $error;
	}
    }else{
	$error = $worst_simplex_error + 1;
	$worst_simplex_error = $error;
    }
    print "Error: $error\n" if ($verbose > 2);
    return abs($error);
}

sub get_simplex_error{
    my $simplex_ = shift @_;
    print "Get simplex error\n" if ($verbose > 2);
    my @error;
    my @s = @{$simplex_};
    foreach my $i(0..$dimensions){
	print "get_simplex error $i: @{$$simplex_[$i]}\n" if ($verbose > 2);
	$error[$i] = &get_vertix_error($$simplex_[$i]);
#	print "@{$$simplex_[$i]} $error[$i]\n";
    }
    return \@error;
}
sub order_simplex_by_error{
    print "Ordering simplex by error\n" if ($verbose > 2);
    my @error = @{shift @_};
    my @simplex_ = @{shift @_};
    my @n_simplex = @simplex_;
    my  @new_index = sort {$error[$a] <=> $error[$b]} 0 .. $#error;
    for(my $i=0;$i<@error;$i++){
	$simplex_[$i] = $n_simplex[$new_index[$i]];
    }
    return \@simplex_;
}

1;
