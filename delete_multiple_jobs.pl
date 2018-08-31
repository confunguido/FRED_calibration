#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Cwd;
my $dir;
my $cdir = getcwd;
GetOptions("dir=s"=>\$dir);
die "please specify a directory\n" unless ($dir);
chdir $dir;
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
