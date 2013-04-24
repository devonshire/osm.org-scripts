#!/usr/bin/perl -w
#----------------------------------------------------------------------
# Script: os_locator_reformat_csv.pl
# Reformat OS Locator data
#
# Output file csv format:
#   Highway Centroid Lat
#   Highway Centroid Lon
#   Highway Polygon SW Lat
#   Highway Polygon SW Lon
#   Highway Polygon NE Lat
#   Highway Polygon NE Lon
#   Name
#   Ref
#   County
#   District
#----------------------------------------------------------------------
use strict;
use Geo::Coordinates::OSGB qw(grid_to_ll shift_ll_into_WGS84);

my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  print "\nUsage: os_locator_reformat_csv.pl os_locator_input_file output_file.csv\n";
  exit;
}

my $input = $ARGV[0];
my $output = $ARGV[1];
my @way = undef;
my $lat = undef;
my $lon = undef;
my $sw_lat = undef;
my $sw_lon = undef;
my $ne_lat = undef;
my $ne_lon = undef;
my $name = undef;

open(INPUT, "< $input") or die "Couldn't open input file: $!\n";
open(OUTPUT, "> $output") or die "Couldn't open output file: $!\n";

while(<INPUT>) {
	chomp; 
	@way = split(/:/);

	# Currently only interested in Devon
	if ($way[10] =~ m/Torbay|Plymouth|Devon County/) {

		# Convert OS coords to wgs84 lat/lon
		($lat, $lon) = grid_to_ll($way[2], $way[3]);
		($lat, $lon) = shift_ll_into_WGS84($lat, $lon);
		($sw_lat, $sw_lon) = grid_to_ll($way[4], $way[6]);
		($sw_lat, $sw_lon) = shift_ll_into_WGS84($sw_lat, $sw_lon);
		($ne_lat, $ne_lon) = grid_to_ll($way[5], $way[7]);
		($ne_lat, $ne_lon) = shift_ll_into_WGS84($ne_lat, $ne_lon);

		# Expand ST to SAINT in names
		$way[0] =~ s/^ST /SAINT /; 
		$way[0] =~ s/^ST\. /SAINT /; 
		$way[0] =~ s/ ST / SAINT /; 
		$way[0] =~ s/ ST\. / SAINT /; 

		# Remove junk from county name
		$way[10] = uc($way[10]);
		$way[10] =~ s/ \(B\)$//; 
		$way[10] =~ s/ COUNTY$//; 
		$way[10] =~ s/ DISTRICT$//; 
		$way[10] =~ s/[',-]//g;

		# Remove Welsh bits from district names
		$way[10] =~ s/^ABERTAWE \/ //; 
		$way[10] =~ s/^BLAENAU GWENT \/ //; 
		$way[10] =~ s/^BRO MORGANNWG \/ //; 
		$way[10] =~ s/^CAERDYDD \/ //; 
		$way[10] =~ s/^CAERFFILI \/ //; 
		$way[10] =~ s/^CASNEWYDD \/ //; 
		$way[10] =~ s/^CASTELL NEDD PORT TALBOT \/ //; 
		$way[10] =~ s/^CASTELLNEDD PORT TALBOT \/ //; 
		$way[10] =~ s/^CONWY \/ //; 
		$way[10] =~ s/^GWYNEDD \/ //; 
		$way[10] =~ s/^MERTHYR TUDFUL \/ //; 
		$way[10] =~ s/^PEN Y BONT AR OGWR \/ //; 
		$way[10] =~ s/^PENYBONT AR OGWR \/ //; 
		$way[10] =~ s/^POWYS \/ //; 
		$way[10] =~ s/^RHONDDA CYNON TAF \/ //; 
		$way[10] =~ s/^SIR BENFRO \/ //; 
		$way[10] =~ s/^SIR CEREDIGION \/ //; 
		$way[10] =~ s/^SIR DDINBYCH \/ //; 
		$way[10] =~ s/^SIR FYNWY \/ //; 
		$way[10] =~ s/^SIR GAERFYRDDIN \/ //; 
		$way[10] =~ s/^SIR Y FFLINT \/ //; 
		$way[10] =~ s/^SIR YNYS MON \/ //; 
		$way[10] =~ s/^TORFAEN \/ //; 
		$way[10] =~ s/^TOR FAEN \/ //; 
		$way[10] =~ s/^WRECSAM \/ //; 

		# Remove junk from district names
		$way[11] = uc($way[11]);
		$way[11] =~ s/ \(B\)$//; 
		$way[11] =~ s/ COUNTY$//; 
		$way[11] =~ s/ DISTRICT$//; 
		$way[11] =~ s/ LONDON BORO$//; 
		$way[11] =~ s/[',-]//g;

		# Remove Welsh bits from district names
		$way[11] =~ s/^ABERTAWE \/ //; 
		$way[11] =~ s/^BLAENAU GWENT \/ //; 
		$way[11] =~ s/^BRO MORGANNWG \/ //; 
		$way[11] =~ s/^CAERDYDD \/ //; 
		$way[11] =~ s/^CAERFFILI \/ //; 
		$way[11] =~ s/^CASNEWYDD \/ //; 
		$way[11] =~ s/^CASTELL NEDD PORT TALBOT \/ //; 
		$way[11] =~ s/^CASTELLNEDD PORT TALBOT \/ //; 
		$way[11] =~ s/^CONWY \/ //; 
		$way[11] =~ s/^GWYNEDD \/ //; 
		$way[11] =~ s/^MERTHYR TUDFUL \/ //; 
		$way[11] =~ s/^PEN Y BONT AR OGWR \/ //; 
		$way[11] =~ s/^PENYBONT AR OGWR \/ //; 
		$way[11] =~ s/^POWYS \/ //; 
		$way[11] =~ s/^RHONDDA CYNON TAF \/ //; 
		$way[11] =~ s/^SIR BENFRO \/ //; 
		$way[11] =~ s/^SIR CEREDIGION \/ //; 
		$way[11] =~ s/^SIR DDINBYCH \/ //; 
		$way[11] =~ s/^SIR FYNWY \/ //; 
		$way[11] =~ s/^SIR GAERFYRDDIN \/ //; 
		$way[11] =~ s/^SIR Y FFLINT \/ //; 
		$way[11] =~ s/^SIR YNYS MON \/ //; 
		$way[11] =~ s/^TORFAEN \/ //; 
		$way[11] =~ s/^TOR FAEN \/ //; 
		$way[11] =~ s/^WRECSAM \/ //; 
		$way[11] =~ s/^CITY AND COUNTY OF //; 

		# Only using records with names initially
		if (length($way[0]) > 1) {
			print OUTPUT "$lat|$lon|$sw_lat|$sw_lon|$ne_lat|$ne_lon|$way[0]|$way[1]|$way[10]|$way[11]\n";
		}
	}
}

close(INPUT);
close(OUTPUT);
