#!/usr/bin/perl -w
#----------------------------------------------------------------------
# Script: ons_rec_postcodes.pl
# Reconcile ONS postcodes with OSM data
#----------------------------------------------------------------------
use strict;
use Geo::Coordinates::OSGB qw(grid_to_ll shift_ll_into_WGS84);
use Geo::Coordinates::OSTN02 qw(OSGB36_to_ETRS89 ETRS89_to_OSGB36);

my $num_args = $#ARGV + 1;
if ($num_args != 4) {
  print "\nUsage: ons_rec_postcodes.pl area input.osm ons_postcodes.csv output.osm\n";
  exit;
}

my $area = $ARGV[0];			# Postcode area eg. TQ to reconcile
my $osm = $ARGV[1];			# OSM input file
my $ons = $ARGV[2];			# ONS input file
my $output = $ARGV[3];		# OSM output filename
my @rec = undef;				# ONS input record parsed from csv
my $lat = undef;				# Latitude to write to OSM file
my $lon = undef;				# Longitude to write to OSM file
my %postcodes = ();			# All OSM postcodes for area read from file
my %pc_areas = ();			# Stats for postcode area matches
my %pc_area_tots = ();		# Total number of postcodes by area part
my $postcode = undef;		# Postcode being processed
my $pc_area = undef;			# Postcode area (3/4 char) being processed
my $total_osm = 0;			# Total OSM postcodes
my $total_ons = 0;			# Total ONS postcodes
my $unmatched = 0;			# Total unmatched postcodes
my $matched = 0;				# Total matched postcodes
my $count = undef;			# Postcode counts
my $node = -1000000;			# Current node id to write to OSM file

# Read in osm postcodes for area
print "Reading OSM Postcodes...\n";
open(OSM, "< $osm") or die "Couldn't open osm input file: $!\n";
while(<OSM>) {
	if (/\"$area/) {
		if (/<tag k="postal_code" v=\"(.*?)\"/ || /<tag k="addr:postcode" v=\"(.*?)\"/) {
			$postcode = $1;
			$postcode =~ tr/ //ds;
			if (!exists($postcodes{$postcode})) {
				$postcodes{$postcode} = $1;
				$total_osm++;
			}
		}
	}
}
close(OSM);
print "...completed reading OSM Postcodes\n";

# Read in ons postcodes for area and reconcile
print "Reading ONS Postcodes...\n";
open(ONS, "< $ons") or die "Couldn't open ons input file: $!\n";
open(OUTPUT, "> $output") or die "Couldn't open output file: $!\n";

print OUTPUT "<?xml version='1.0' encoding='UTF-8'?>\n";
print OUTPUT "<osm version='0.6' upload='false' generator='JOSM'>\n";

while(<ONS>) {
	chomp; 

	# Only process postcodes for particular area
	if (/^\"$area/) {

		@rec = &parse_csv($_);

		# Only interested in postcodes with no end date
		if (length($rec[4]) < 1) {

			my ($x, $y, $z) = OSGB36_to_ETRS89($rec[9], $rec[10]);
			($lat, $lon) = grid_to_ll($x, $y, 'WGS84'); # or 'WGS84'

			# Match postcode without spaces
			$postcode = $rec[0];
			$postcode =~ tr/ //ds;

			# Get postcode area (first part of postcode)
			my @values = split(' ', $rec[1]);
			$pc_area = $values[0];

			# Update total postcodes for each area
			if (!exists($pc_area_tots{$pc_area})) {
				$pc_area_tots{$pc_area} = 1;
			} else {
				$pc_area_tots{$pc_area} += 1;
			}

			# Matched
			if (exists($postcodes{$postcode})) {
				print "...postcode $rec[2] matched\n";
				$total_ons++;
				$matched++;

				# Also record match against area
				if (!exists($pc_areas{$pc_area})) {
					$pc_areas{$pc_area} = 1;
				} else {
					$pc_areas{$pc_area} += 1;
				}

			# Not matched
			} else {
				print OUTPUT "  <node id='$node' visible='true' lat='$lat' lon='$lon'>\n";
				print OUTPUT "    <tag k='addr:postcode' v='$rec[2]' />\n";
				print OUTPUT "    <tag k='source:postcode' v='ONS_Postcode_Directory' />\n";
				print OUTPUT "  </node>\n";
				$node--;
				$total_ons++;
				$unmatched++;
			}
		}
	}
}

print OUTPUT "</osm>\n";

close(ONS);
close(OUTPUT);
print "...completed processing.\n\n";
print "Area processed                  : $area\n";
print "Total unique OSM postcodes read : $total_osm\n";
print "Total unique ONS postcodes read : $total_ons\n";
print "Total matched postcodes         : $matched\n";
print "Total unmatched postcodes       : $unmatched\n\n";

print "Matches by postcode area...\n";

# Sort totals keys by length and then alpha
my @keys = sort {length $a <=> length $b || $a cmp $b} (keys %pc_area_tots);

foreach $pc_area (@keys) {

	print "...$pc_area: matched ";

	if (exists($pc_areas{$pc_area})) {
		print $pc_areas{$pc_area};
				} else {
		print "0";
	}

	print " out of $pc_area_tots{$pc_area}\n";
}

# Parse comma and quote delimited record to fields
sub parse_csv {
  my $text = shift; #record containing CSVs
  my @columns = ();
  push(@columns ,$+) while $text =~ m{
    # The first part groups the phrase inside quotes
    "([^\"\\]*(?:\\.[^\"\\]*)*)",?
      | ([^,]+),?
      | ,
    }gx;
  push(@columns ,undef) if substr($text, -1,1) eq ',';
  return @columns ; # list of vars that was comma separated.
}

