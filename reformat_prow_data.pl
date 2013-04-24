#!/usr/bin/perl -w
#----------------------------------------------------------------------
# Script: reformat_prow_data.pl
# Reformat prow data to add osm tags
#----------------------------------------------------------------------
use strict;

my $num_args = $#ARGV + 1;
if ($num_args != 1) {
  print "\nUsage: reformat_prow_data.pl input_file\n";
  exit;
}

my $input = $ARGV[0];
my $output = "tagged_".$input;
my @attr = undef;

open(INPUT, "< $input") or die "Couldn't open input file: $!\n";
open(OUTPUT, "> $output") or die "Couldn't open output file: $!\n";

while(<INPUT>) {
	chomp; 

	if (/<tag k='name'/) {

		# Name formatted as: County Code|Parish Name|PRoW Type+Ref
		@attr = split(/\|/);

		if (/Footpath/) {
			print OUTPUT "<tag k='designation' v='public_footpath' />\n";
			print OUTPUT "<tag k='highway' v='footway' />\n";
		} elsif (/Bridleway/) {
			print OUTPUT "<tag k='designation' v='public_bridleway' />\n";
			print OUTPUT "<tag k='highway' v='track' />\n";
		} elsif (/Byway/) {
			print OUTPUT "<tag k='designation' v='byway_open_to_all_traffic' />\n";
			print OUTPUT "<tag k='highway' v='track' />\n";
		}

		print OUTPUT "<tag k='prow_ref' v='$attr[1] $attr[2]' />\n";
		print OUTPUT "<tag k='source:prow_ref' v='definitive_statement' />\n";

	} else {
		print OUTPUT $_."\n";
	}
}

close(INPUT);
close(OUTPUT);
