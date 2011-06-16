#!/usr/bin/perl

# query.pl
#
# (c)2011 Andy Smith <andy@m0vkg.org.uk>
#
# Quick and (very) dirty example of using Ham::WSPR.
#

use lib "Ham/Locator.pm";
use lib "Ham/WSPR.pm";
use DBI;

require Ham::WSPR;
require Ham::Locator;
use Data::Dumper;
use Class::Date qw(:errors date localdate gmdate now -DateParse -EnvC);
use strict;
use warnings;
use CGI;
use Getopt::Std;

my $dbh = DBI->connect('DBI:mysql:dbname', 'dbuser', 'dbpass') || die "Could not connect to database: ".$DBI::errstr;
$dbh->trace(0);

# Prepared statements
my $q_exist = $dbh->prepare("SELECT * FROM wspr WHERE hash = ?");
my $q_insert = $dbh->prepare("INSERT INTO wspr (guid, hash, callsign, timestamp, frequency, locator, callsign_lt, callsign_ln, power_watts, power_dbm, drift, snr, spotter, spotter_locator, spotter_lt, spotter_ln, distance_mi, distance_km) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

my $w = new Ham::WSPR;
my $m = new Ham::Locator;
$w->init();

our($opt_c, $opt_n, $opt_r, $opt_b);

getopt('cnbr');

my ($q_limit, $q_tx, $q_rx, $q_band);

if($opt_n)
{
	$w->set_limit($opt_n);
	$q_limit = $opt_n;
}
else
{
	$w->set_limit(1000);
	$q_limit = 1000;
}

if($opt_c)
{
	$w->set_call($opt_c);
	$q_tx = $opt_c;
}
else
{
	$q_tx = "ALL";
}

if($opt_r)
{
	$w->set_reporter($opt_r);
	$q_rx = $opt_r;
}
else
{
	$q_rx = "ALL";
}

if($opt_b)
{
	$w->set_band($opt_b);
	$q_band = $opt_b;
}
else
{
	$q_band = "ALL";
}

print "WSPRNet Query Tool v1.0\n";
print "(c)2011 Andy Smith M0VKG - http://m0vkg.org.uk/\n\n";
print "Arguments: TX: [33;1m$q_tx[0m RX: [33;1m$q_rx[0m Band: [33;1m$q_band[0m Limit: [33;1m$q_limit[0m\n\n";
print "Querying wsprnet.org... ";
$w->retrieve_spots();
print "[32;1mok[0m\n";

#my $q = CGI->new;

#print $q->header('text/xml');

#print $w->get_xml_spots();dd

my $count = 0;
my $added = 0;
my $skipped = 0;
my $errored = 0;

print "Processing...\n";

while (my ($key, $value) = each(%{$w->get_spots->{spot}}))
{
	$count++;
	#print "-> Processing spot [[32;1m$count[0m] [36;1m$key[0m (spot of [33;1m".$value->{call}."[0m by [33;1m".$value->{spotter}."[0m)...\n[1A";

	print "> [[32;1m$count\n[1A[8C[0m] ";
	print "[33;1m".$value->{call}."[0m ([36;1m".$value->{locator}."[0m)                                ";
	print "\n[1A[28C";
	print " --->                                       ";
	print "\n[1A[34C";
	print "[33;1m".$value->{spotter}."[0m ([36;1m".$value->{spotter_locator}."[0m)                       ";
	print "\n[1A[56C";
	print "on [35;1m".$value->{frequency}."[0m with [35;1m".$value->{power_watts}."W/".$value->{power_dbm}."dBm[0m";
	print "                 \n[1A";

	# Check to see if it exists in the DB already
	$q_exist->execute($value->{hash});

	if($q_exist->rows ne 0)
	{
		#print "> entry exists, skipping...\n";
		$skipped++;
	}
	else
	{
		#print "> entry does not exist... inserting into database...";
		my $date = date $value->{date} . " " .$value->{time};
		$m->set_loc($value->{locator});
		my ($c_lt, $c_ln) = $m->loc2latlng;
		$m->set_loc($value->{spotter_locator});
		my ($s_lt, $s_ln) = $m->loc2latlng;
		#print "spot: ".$value->{spotter_locator}." $s_lt $s_ln tx: ".$value->{locator}." $c_lt $c_ln\n";
		$q_insert->execute($value->{id}, $value->{hash}, $value->{call}, $date->epoch, $value->{frequency}, $value->{locator}, $c_lt, $c_ln, $value->{power_watts}, $value->{power_dbm}, $value->{drift}, $value->{snr}, $value->{spotter}, $value->{spotter_locator}, $s_lt, $s_ln, $value->{distance_mi}, $value->{distance_km});
		if($@)
		{
			#print $@."\n";
			$errored++;
		}
		else
		{
			#print "ok.\n";
			$added++;
		}
	}
}

print "\n\n";

print "Completed: [32;1m$added added[0m, [33;1m$skipped skipped[0m, [31;1m$errored errored[0m - [36;1m$count total[0m\n";
