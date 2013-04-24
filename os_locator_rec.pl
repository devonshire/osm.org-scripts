#!/usr/bin/perl -w
#----------------------------------------------------------------------
# Script: os_locator_rec.pl
# Reconcile OS Locator data with fosm data from MongoDB
#----------------------------------------------------------------------

use strict;
use MongoDB;
use MongoDB::OID;
use IO::File;

my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  print "\nUsage: os_locator_rec.pl os_locator_csv_file output_dir\n";
  exit;
}

my $conn = MongoDB::Connection->new;
my $db = $conn->osm;
my $coll = $db->highways;
my $input = $ARGV[0];
my $outputDir = $ARGV[1];
my %outputFiles = ();
my @way = undef;
my $cursor = undef;
my $query = undef;
my $lonlat = undef;
my $found = undef;
my $fileHandle = undef;
my $records = 0;

open(INPUT, "< $input") or die "Couldn't open input file: $!\n";

while(<INPUT>) {
	chomp; 

	@way = split(/\|/);

	$fileHandle = &getOutputFileHandle($way[8], $way[9]);

	if (!&searchHighwaysBbox()) {
		if (!&searchHighwaysNear(30)) {
			print $fileHandle "<wpt lat=\"$way[0]\" lon=\"$way[1]\">\n";
			print $fileHandle "   <name>$way[6]</name>\n";
			print $fileHandle "</wpt>\n";
			print $fileHandle "<trk>\n";
			print $fileHandle "   <name>$way[6]</name>\n";
			print $fileHandle "   <trkseg>\n";
			print $fileHandle "      <trkpt lat=\"$way[2]\" lon=\"$way[3]\"/>\n";
			print $fileHandle "      <trkpt lat=\"$way[2]\" lon=\"$way[5]\"/>\n";
			print $fileHandle "      <trkpt lat=\"$way[4]\" lon=\"$way[5]\"/>\n";
			print $fileHandle "      <trkpt lat=\"$way[4]\" lon=\"$way[3]\"/>\n";
			print $fileHandle "      <trkpt lat=\"$way[2]\" lon=\"$way[3]\"/>\n";
			print $fileHandle "   </trkseg>\n";
			print $fileHandle "</trk>\n";

		# Success
		} else {

			# Collect some stats or something?
		}

	# Success
	} else {

		# Collect some stats or something?
	}

	$records++;
	if ($records % 10000 == 0) {print "$records records processed\n"}

}

# Tidy up
close(INPUT);
&closeAllOutputFiles();

exit 1;

# Highway search (using near)
sub searchHighwaysNear
{
	my $limit = shift;
	my $retVal = 0;
	my $lonlat = [$way[1] + 0.000001, $way[0] + 0.000001];

	$cursor = $coll->query({"loc" => {'$near' => $lonlat}})->limit($limit);

	while (my $doc = $cursor->next) {
		if ($way[6] eq $doc->{'name'}){
			$retVal = 1;
		}
	}

	return $retVal;
}

# Highway search (using bbox)
sub searchHighwaysBbox
{
	my $retVal = 0;
	my $swCorner = [$way[3] - 0.006, $way[2] - 0.006];
	my $neCorner = [$way[5] + 0.006, $way[4] + 0.006];
	my $bbox = [$swCorner, $neCorner];

	$cursor = $coll->query({"loc" => {'$within' => {'$box' => $bbox}}});

	while (my $doc = $cursor->next) {
		if ($way[6] eq $doc->{'name'}){
			$retVal = 1;
		}
	}

	return $retVal;
}

# Get output file handle (create if required)
sub getOutputFileHandle
{
	my $county = shift;
	my $district = shift;
	my $key = undef;
	my $value = undef;
	my $fileName = undef;
	my $fileHandle = undef;
	my $found = 0;

	# Build file name
	$county = lc($county); $county =~ s/[', -\/]/_/g;
	$district = lc($district); $district =~ s/[', -\/]/_/g;

	if ($county eq $district) {
		$fileName = "$county.gpx";
		
	} else {
		$fileName = "$county-$district.gpx";
	}

	# Did we open this file already?
	while(($key, $value) = each(%outputFiles)) {
		if ($key eq $fileName) {
			$found = 1;
			$fileHandle = $value;
		}
	}

	# File wasn't found so open new one
	if (!$found) {

		$fileHandle = IO::File->new("> $outputDir/$fileName")
			or die "Error opening $fileName file: $!";
		$outputFiles{$fileName} = $fileHandle;
		
		# Write output header
		print $fileHandle <<HEADER;
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.0"
creator="GPSBabel - http://www.gpsbabel.org"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xmlns="http://www.topografix.com/GPX/1/0"
xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
HEADER

	}

	return $fileHandle;
}

# Close all output files
sub closeAllOutputFiles
{
	my $key = undef;
	my $value = undef;
	
	while(($key, $value) = each(%outputFiles)) {
		print $value "</gpx>\n";
		close($value);
	}
}
