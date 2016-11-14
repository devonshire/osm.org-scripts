#!/usr/bin/perl -w
#----------------------------------------------------------------------
# Script: os_open_names_xapi_check.pl
# Check whether OS open names data can be found in the fosm db 
# This version of the script uses the xapi api
#
# Kevin Peat - 31-Mar-2015
# Licensed public domain
#----------------------------------------------------------------------
# OS file format (October, 2016 release)
#	0	ID								OS ID (not used?)
#	1	NAMES_URI					OS ID uri (not used)
#	2	NAME1							Name, ref or postcode (see below)
#	3	NAME1_LANG					Empty (?)
#	4	NAME2							Empty (?)
#	5	NAME2_LANG					Empty (?)
#	6	TYPE							Item type (see below)					
#	7	LOCAL_TYPE,					Item sub-type (see below)
#	8	GEOMETRY_X					Object X centrepoint
#	9	GEOMETRY_Y					Object Y centrepoint
#	10	MOST_DETAIL_VIEW_RES		Viewing scale (not used)
#	11	LEAST_DETAIL_VIEW_RES	Viewing scale (not used)
#	12	MBR_XMIN						Object X min
#	13	MBR_YMIN						Object Y min
#	14	MBR_XMAX						Object X max
#	15	MBR_YMAX						Object Y max
#	16	POSTCODE_DISTRICT			Postcode district
#	17	POSTCODE_DISTRICT_URI	OS postcode uri (not used)
#	18	POPULATED_PLACE			Empty (?)
#	19	POPULATED_PLACE_URI		Empty (?)
#	20	POPULATED_PLACE_TYPE		Empty (?)
#	21	DISTRICT_BOROUGH			Admin district
#	22	DISTRICT_BOROUGH_URI		OS Borough uri (not used)
#	23	DISTRICT_BOROUGH_TYPE	OS Borough uri (not used)
#	24	COUNTY_UNITARY				County/Unitary Authority name
#	25	COUNTY_UNITARY_URI		OS County/Unitary uri (not used)
#	26	COUNTY_UNITARY_TYPE		OS County/Unitary uri (not used)
#	27	REGION						Region name (not used)
#	28	REGION_URI					OS Region uri (not used)
#	29	COUNTRY						Country name
#	30	COUNTRY_URI					OS Country uri (not used)
#	31	RELATED_SPATIAL_OBJECT	Empty (?)
#	32	SAME_AS_DBPEDIA			dbpedia.org uri
#	33	SAME_AS_GEONAMES			geonames.org uri
#----------------------------------------------------------------------
# Contents of name column for type and local type
#----------------------------------------------------------------------
#	NAME1				TYPE					LOCAL_TYPE
#	-----------		----------------	------------------------
#	place name		populatedPlace		Village
#												Suburban Area
#												Hamlet
#												Town
#												City
#												Other Settlement
#
#	road name		transportNetwork	Named Road
#												Section Of Named Road
#
#	road ref			transportNetwork	Section Of Numbered Road
#
#	postcode			other					Postcode
#----------------------------------------------------------------------
use strict;
use File::Find;
use Geo::Coordinates::OSGB ':all';
use Geo::Coordinates::OSTN02  qw(OSGB36_to_ETRS89 ETRS89_to_OSGB36);
use LWP::Simple;

my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  print "\nUsage: os_open_names_reformat_osm_xapi_check.pl /path/to/os/files/ source_tag \n";
  exit;
}

my @item = undef;
my $lat = undef;
my $lon = undef;
my $node = -10000000;
my $name = undef;
my $place = undef;
my $ref = undef;
my $postcode = undef;
my $minlat = undef;
my $maxlat = undef;
my $minlon = undef;
my $maxlon = undef;
my $url = undef;
my $results = undef;
my $streets_found = 0;
my $streets_notfound = 0;
my $postcodes_found = 0;
my $postcodes_notfound = 0;
my $places_found = 0;
my $places_notfound = 0;
my $refs_found = 0;
my $refs_notfound = 0;

# Output files to contain items not found in fosm db
my $missing_streets = "fosm_missing_streets.osm";
my $missing_postcodes = "fosm_missing_postcodes.osm";
my $missing_places = "fosm_missing_places.osm";
my $missing_refs = "fosm_missing_refs.osm";

# Open output files
open(STREETS, "> $missing_streets") or die "Couldn't open output file: $!\n";
print STREETS "<?xml version='1.0' encoding='UTF-8'?>\n";
print STREETS "<osm version='0.6' upload='false' generator='PERL'>\n";

open(POSTCODES, "> $missing_postcodes") or die "Couldn't open output file: $!\n";
print POSTCODES "<?xml version='1.0' encoding='UTF-8'?>\n";
print POSTCODES "<osm version='0.6' upload='false' generator='PERL'>\n";

open(PLACES, "> $missing_places") or die "Couldn't open output file: $!\n";
print PLACES "<?xml version='1.0' encoding='UTF-8'?>\n";
print PLACES "<osm version='0.6' upload='false' generator='PERL'>\n";

open(REFS, "> $missing_refs") or die "Couldn't open output file: $!\n";
print REFS "<?xml version='1.0' encoding='UTF-8'?>\n";
print REFS "<osm version='0.6' upload='false' generator='PERL'>\n";

# Source tag to use in output file
my $source = $ARGV[1];

# Process OS files
find(\&processFiles,($ARGV[0]));
 
# OSM Footers
print STREETS "</osm>\n";
print POSTCODES "</osm>\n";
print PLACES "</osm>\n";
print REFS "</osm>\n";

# Done
close(STREETS);
close(POSTCODES);
close(PLACES);
close(REFS);
print "Completed...\n";
print "  Places matched: $places_found \n";
print "  Places not-matched: $places_notfound \n";
print "  Streets matched: $streets_found \n";
print "  Streets not-matched: $streets_notfound \n";
print "  Postcodes matched: $postcodes_found \n";
print "  Postcodes not-matched: $postcodes_notfound \n";
print "  Refs matched: $refs_found \n";
print "  Refs not-matched: $refs_notfound \n";
exit;

# SUBS

# Process files
sub processFiles {

	if (/\.csv$/i) {

		open(INPUT, "< $File::Find::name") or die "Couldn't open input file: $!\n";

		while(<INPUT>) {
			chomp; 
			@item = split(/,/);

			# Convert OS coords to lat/lon
			my ($x, $y, $z) = OSGB36_to_ETRS89($item[8], $item[9]);
			($lat, $lon) = grid_to_ll($x, $y, 'WGS84');
			$minlat = $lat - 0.02;
			$maxlat = $lat + 0.02;
			$minlon = $lon - 0.04;
			$maxlon = $lon + 0.04;

			# Place names
			if ($item[6] eq "populatedPlace") {

				# Set place type
				$place = "unknown";
				if ($item[7] eq "Hamlet") {$place = "hamlet"}
				elsif ($item[7] eq "Village") {$place = "village"}
				elsif ($item[7] eq "Town") {$place = "town"}
				elsif ($item[7] eq "Suburban Area") {$place = "neighbourhood"} # better for my area than suburb
				elsif ($item[7] eq "City") {$place = "city"}
				elsif ($item[7] eq "Other Settlement") {$place = "hamlet"} # these look like hamlets to me

				# Check if place exists in fosm.org
				$name = &processInputName($item[2]);
				$url = "http://fosm.org/api/0.6/node[place=$place][name=$name][bbox=$minlon,$minlat,$maxlon,$maxlat]";
				$results = get $url;

				if (index($results, $place) != -1) {
					$places_found++;
					print "Found $name \n";
				} else {
					$places_notfound++;
					print "Can't find $name \n";

					print PLACES "  <node id='$node' action='modify' visible='true' lat='$lat' lon='$lon'>\n";
					print PLACES "    <tag k='place' v='$place' />\n";
					print PLACES "    <tag k='name' v='$name' />\n";
					print PLACES "    <tag k='source' v='$source' />\n";
					print PLACES "  </node>\n";
					$node--;
				} 
			}

			# Street names
			if ($item[6] eq "transportNetwork" && ($item[7] eq "Named Road" || $item[7] eq "Section Of Named Road")) {

				# Check if street exists in fosm.org
				$name = &processInputName($item[2]);
				$url = "http://fosm.org/api/0.6/way[highway=*][name=$name][bbox=$minlon,$minlat,$maxlon,$maxlat]";
				$results = get $url;

				if (index($results, "highway") != -1) {
					$streets_found++;
					print "Found $name \n";
				} else {

					# Test for existence of not:name tags (caters for cases where OS name is or appears to be wrong)
					$url = "http://fosm.org/api/0.6/way[highway=*][not:name=$name][bbox=$minlon,$minlat,$maxlon,$maxlat]";
					$results = get $url;

					if (index($results, "highway") != -1) {
						$streets_found++;
						print "Found $name \n";
					} else {

						$streets_notfound++;
						print "Can't find $name \n";

						print STREETS "  <node id='$node' action='modify' visible='true' lat='$lat' lon='$lon'>\n";
						print STREETS "    <tag k='highway' v='road' />\n";
						print STREETS "    <tag k='name' v='$name' />\n";
						print STREETS "    <tag k='source:name' v='$source' />\n";
						print STREETS "  </node>\n";
						$node--;
					}
				} 
			}

			# Road references
			if ($item[6] eq "transportNetwork" && $item[7] eq "Section Of Numbered Road") {

				# Check if ref exists in fosm.org
				$ref = $item[2];
				$url = "http://fosm.org/api/0.6/way[highway=*][ref=$ref][bbox=$minlon,$minlat,$maxlon,$maxlat]";
				$results = get $url;

				if (index($results, $ref) != -1) {
					$refs_found++;
					print "Found $ref \n";
				} else {
					$refs_notfound++;
					print "Can't find $ref \n";

					print REFS "  <node id='$node' action='modify' visible='true' lat='$lat' lon='$lon'>\n";
					print REFS "    <tag k='highway' v='road' />\n";
					print REFS "    <tag k='ref' v='$ref' />\n";
					print REFS "    <tag k='source:ref' v='$source' />\n";
					print REFS "  </node>\n";
					$node--;
				} 
			}

			# Postcodes
			if ($item[6] eq "other" && $item[7] eq "Postcode") {

				# Check if postcode exists in fosm.org
				$postcode = $item[2];
				$url = "http://fosm.org/api/0.6/*[addr:postcode=$postcode][bbox=$minlon,$minlat,$maxlon,$maxlat]";
				$results = get $url;

				if (index($results, $postcode) != -1) {
					$postcodes_found++;
					print "Found $postcode \n";
				} else {
					$postcodes_notfound++;
					print "Can't find $postcode \n";

					print POSTCODES "  <node id='$node' action='modify' visible='true' lat='$lat' lon='$lon'>\n";
					print POSTCODES "    <tag k='addr:postcode' v='$postcode' />\n";
					print POSTCODES "    <tag k='source:postcode' v='$source' />\n";
					print POSTCODES "  </node>\n";
					$node--;
				} 
			}
		}
		close(INPUT);
	}
}


# Process name for OS input data
sub  processInputName
{
	my $name = shift;

	# Convert '
	$name =~ s/'/&apos;/;

	# Expand ST to SAINT in names
	$name =~ s/^St /Saint /; 
	$name =~ s/^St\. /Saint /; 
	$name =~ s/ St / Saint /; 
	$name =~ s/ St\. / Saint /; 

	return $name;
}
