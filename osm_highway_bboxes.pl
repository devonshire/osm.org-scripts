#!/usr/bin/perl -w
#----------------------------------------------------------------------
# Script: osm_highway_bboxes.pl
# Calculates bounding boxes for osm highways and writes to file
# as json ready to be imported to MongoDB
#----------------------------------------------------------------------
use strict;

my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  print "\nUsage: osm_highway_bboxes.pl input.osm output.json \n";
  exit;
}

my $osm = $ARGV[0];
my $json = $ARGV[1];
my $highways = "osm_highways.tmp";

open(OSM, "< $osm") or die "Couldn't open osm input file: $!\n";
open(HIGHWAYS, "> $highways") or die "Couldn't open temporary highways output file: $!\n";
open(BBOXES, "> $json") or die "Couldn't open json output file: $!\n";

my %nodes = (); my $ndID = ""; my $nodeCount = 0; my $way = "";
my $wayCount = 0; my $searchTrue = 0; my $inWay = 0;
my %tmpNodes = (); my $k = undef; my $v = undef; my $lat = undef;
my $lon=undef; my $wayID = undef; my $wayName = undef;
my $hiLat = 0; my $loLat = 0; my $hiLon = 0; my $loLon = 0;
my $cLat = 0; my $cLon = 0; my $notName = undef; my $ref = undef;
my $cyName = undef; my $enName = undef; my $altName = undef;

print "Reading in highway nodes...\n";
while(<OSM>) {

	# Start of a new way
	if (/<way/) {
		$inWay = 1;
		$way = "";
	}

	# Only need highways
	if ($inWay && /tag k=\"highway\"/) {
		$searchTrue = 1;
		$wayCount++;
	}

	# Capture nodes and other tags
	if ($inWay) {
		$way .= $_;

		# Get node id
		if (/<nd ref/) {
			$_ =~ /<nd ref=\"(.*?)\"/; $ndID = $1;
			$tmpNodes{$ndID} = "0.0|0.0";
		}
	}

	# End of way
	if (/<\/way>/ && $searchTrue) {

		# Write out way details
		print HIGHWAYS $way;

		# Save node id's
		while (($k,$v) = each(%tmpNodes)) {
			$nodes{$k} = $v;
			$nodeCount++;
		}

		# Reset
		%tmpNodes = ();
		$inWay = 0;
		$searchTrue = 0;
	}
}

close(OSM);
close(HIGHWAYS);

print "Loaded: $nodeCount highway node id's\n";
print "Saved: $wayCount highways for later processing\n";
print "Reading in node locations...\n";

open(OSM, "< $osm") or die "Couldn't open input file: $!\n";

while(<OSM>) {

	# Get node id
	if (/<node/) {

		# Get node id
		$_ =~ /<node id=\"(.*?)\"/; $ndID = $1;

		# Do we need this node 
		if (exists($nodes{$ndID})) {

			#Save node location
			$_ =~ /lat=\"(.*?)\"/; $lat = $1;
			$_ =~ /lon=\"(.*?)\"/; $lon = $1;
			$nodes{$ndID} = $lat."|".$lon;
		}
	}
}

close(OSM);
print "Completed reading node locations\n";
print "Calculating highway bounding boxes...\n";

open(HIGHWAYS, "< $highways") or die "Couldn't open highways input file: $!\n";

while(<HIGHWAYS>) {

	# Start of a new way
	if (/<way/) {
		$hiLat = -999; $loLat = 999;
		$hiLon = -999; $loLon = 999;
		$wayName = "NONAME"; $notName = "NONAME";
		$cyName = "NONAME"; $enName = "NONAME";
		$altName = "NONAME"; $ref="NOREF";
		$_ =~ /<way id=\"(.*?)\"/; $wayID = $1;
	}

	# Build highway bounding boxes
	if (/<nd ref/) {
		$_ =~ /<nd ref=\"(.*?)\"/; $ndID = $1;
		($lat, $lon) = split(/\|/, $nodes{$ndID});
		if ($lat > $hiLat) {$hiLat = $lat}
		if ($lat < $loLat) {$loLat = $lat}
		if ($lon > $hiLon) {$hiLon = $lon}
		if ($lon < $loLon) {$loLon = $lon}
	}

	# Capture and process name tags
	if (/<tag k="name" v=\"(.*?)\"/) {$wayName = &processName($1)}
	if (/<tag k="not:name" v=\"(.*?)\"/) {$notName = &processName($1)}
	if (/<tag k="name:cy" v=\"(.*?)\"/) {$cyName = &processName($1)}
	if (/<tag k="name:en" v=\"(.*?)\"/) {$enName = &processName($1)}
	if (/<tag k="alt_name" v=\"(.*?)\"/) {$altName = &processName($1)}

	# Capture ref tag
	if (/<tag k="ref" v=\"(.*?)\"/) {$ref = uc($1)}

	# End of way
	if (/<\/way>/) {

		# Write out way details
		$cLat = ($loLat + $hiLat) / 2;
		$cLon = ($loLon + $hiLon) / 2;

		# Add a separate record for name, alt_name, not:name, name:cy and name:en (if they exist)
		if ($wayName ne "NONAME") {&printWayMulti($wayID, $wayName, $ref, $loLon, $loLat, $hiLon, $hiLat, $cLon, $cLat)}
		if ($notName ne "NONAME") {&printWayMulti($wayID, $notName, $ref, $loLon, $loLat, $hiLon, $hiLat, $cLon, $cLat)}
		if ($cyName ne "NONAME") {&printWayMulti($wayID, $cyName, $ref, $loLon, $loLat, $hiLon, $hiLat, $cLon, $cLat)}
		if ($enName ne "NONAME") {&printWayMulti($wayID, $enName, $ref, $loLon, $loLat, $hiLon, $hiLat, $cLon, $cLat)}
		if ($altName ne "NONAME") {&printWayMulti($wayID, $altName, $ref, $loLon, $loLat, $hiLon, $hiLat, $cLon, $cLat)}
	}
}

close(HIGHWAYS);
close(BBOXES);
print "Done\n";
exit;

# Output way as json
sub printWay
{
	my $wayID = shift; my $name = shift; my $ref = shift;
	my $loLon = shift; my $loLat = shift; my $hiLon = shift;
	my $hiLat = shift; my $cLon = shift; my $cLat = shift;

	print BBOXES "{ \"wayID\": $wayID, \"name\": \"$name\", \"ref\": \"$ref\", \"swLoc\" : { \"lon\": $loLon, \"lat\": $loLat }, \"neLoc\" : { \"lon\": $hiLon, \"lat\": $hiLat }, \"loc\" : { \"lon\": $cLon, \"lat\": $cLat } }\n";	
}

# Output way as json (duplicate long ways with multiple centrepoints)
sub printWayMulti
{
	my $wayID = shift; my $name = shift; my $ref = shift;
	my $loLon = shift; my $loLat = shift; my $hiLon = shift;
	my $hiLat = shift; my $cLon = shift; my $cLat = shift;

	# Check for bad input data
	if ($loLon == 0 || $loLat == 0 || $hiLon == 0 || $hiLat == 0) {
		print "Error: Way id $wayID has a zero lat/lon value, ignoring.\n";
		return;
	}

	# Size of bounding box
	my $latRange = $hiLat - $loLat;
	my $lonRange = $hiLon - $loLon;

	# Split larger bounding boxes
	my $latSteps = 2 + int($latRange * 100);
	my $lonSteps = 2 + int($lonRange * 100);

	# Write more than one copy of the way with different centrepoints?
	for (my $latCount = 1; $latCount < $latSteps; $latCount++) {
		for (my $lonCount = 1; $lonCount < $lonSteps; $lonCount++) {

			$cLat = $loLat + ($latCount / $latSteps) * $latRange;
			$cLon = $loLon + ($lonCount / $lonSteps) * $lonRange;

			&printWay($wayID, $name, $ref, $loLon, $loLat, $hiLon, $hiLat, $cLon, $cLat);
		}
	}
}

# Process name
sub  processName
{
	my $name = shift;

	# To uppercase
	$name = uc($name);

	# Convert '
	$name =~ s/&APOS;/'/;
	$name =~ s/&#39;/'/;

	# Expand ST to SAINT in names
	$name =~ s/^ST /SAINT /; 
	$name =~ s/^ST\. /SAINT /; 
	$name =~ s/ ST / SAINT /; 
	$name =~ s/ ST\. / SAINT /; 

	return $name;
}
