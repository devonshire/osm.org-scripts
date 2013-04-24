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

my $area = $ARGV[0];			# Postcode area eg. TQ
my $osm = $ARGV[1];			# OSM input file
my $ons = $ARGV[2];			# ONS input file
my $output = $ARGV[3];		# OSM output filename

my @way = undef;
my $lat = undef;
my $lon = undef;
my %postcodes = ();
my $postcode = undef;
my $total_osm = 0;
my $total_ons = 0;
my $unmatched = 0;
my $matched = 0;
my $node = -1000000;

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

		@way = &parse_csv($_);

		# Only interested in postcodes with no end date
		if (length($way[4]) < 1) {

			my ($x, $y, $z) = OSGB36_to_ETRS89($way[9], $way[10]);
			($lat, $lon) = grid_to_ll($x, $y, 'WGS84'); # or 'WGS84'

			# Match postcode without spaces
			$postcode = $way[0];
			$postcode =~ tr/ //ds;

			# Matched
			if (exists($postcodes{$postcode})) {
				print "...postcode $way[2] matched\n";
				$total_ons++;
				$matched++;

			# Not matched
			} else {
				print OUTPUT "  <node id='$node' visible='true' lat='$lat' lon='$lon'>\n";
				print OUTPUT "    <tag k='addr:postcode' v='$way[2]' />\n";
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

