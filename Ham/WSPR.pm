#!/usr/bin/perl

package Ham::WSPR;

use strict;
use warnings;
use Ham::WSPR::Spot;

our $VERSION = '0.001';

use base qw(Class::Accessor);
use Carp qw(cluck croak confess);
use Data::Dumper;
use LWP::Simple;
use XML::Simple;
use Class::Date qw(:errors date localdate gmdate now -DateParse -EnvC);
use namespace::clean;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors( qw(call reporter lwp band limit sort request_uri) );
__PACKAGE__->mk_ro_accessors( qw(spots xml_spots) );

our $wsprnet_url_base = "http://wsprnet.org/olddb?";

sub init
{
	my ($self) = @_;

	$self->_init_lwp();

	# Set some default options
	$self->set_band('all');
	$self->set_limit('50');
	$self->set_sort('date');
	$self->set_call('');
	$self->set_reporter('');

	if($@)
	{
		return 1;
	} else {
		return 0;
	}
}
	
sub _build_request_uri
{
	my ($self) = @_;

	my $uri = $wsprnet_url_base;
	$uri .= "mode=html";
	$uri .= "&band=".$self->get_band;
	$uri .= "&limit=".$self->get_limit;
	$uri .= "&findcall=".$self->get_call;
	$uri .= "&findreporter=".$self->get_reporter;
	$uri .= "&sort=".$self->get_sort;

	$self->set_request_uri($uri);

	return 1;
}

sub _init_lwp
{
	my ($self) = @_;

	# Initiate a new LWP::UserAgent object and store it within the parent object
	my $ua = LWP::UserAgent->new();
	$ua->agent('Ham::WSPR/'.$VERSION);
	$self->set_lwp($ua);

	# Return false if we have any problems, otherwise return true
	if($@)
	{
		return 0;
	} else {
		return 1;
	}
}

sub retrieve_spots
{
	my ($self) = @_;

	# Build the request URI
	$self->_build_request_uri;

	my $req = HTTP::Request->new(GET => $self->get_request_uri());
#	$req->header('Accept' => 'text/html');

	my $res = $self->get_lwp->request($req);

	if($res->is_success)
	{
		$self->_parse_content($res->{_content});
	}
	else
	{
		print "Error requesting ".$self->get_request_uri().": ".$res->status_line."\n";
		print Dumper($res);
	}
}

sub _parse_content
{
	my ($self, $content) = @_;

	my @lines = split("\n", $content);
	my @spots;

	foreach my $line (@lines)
	{
		if($line =~ /^<tr id=/)
		{
			$line =~ s/&nbsp;//g;
			$line =~ s/\r//g;
			my ($date, $time, $call, $freq, $snr, $drift, $call_loc, $dbm, $watts, $spotter, $spotter_loc, $dist_km, $dist_mi) = $line =~ /<tr id=\"\w+\"><td align=left>(\d{4}-\d{2}-\d{2})\s(\d{2}:\d{2})<\/td><td align=left>(\S+)<\/td><td align=right>(\d+\.\d+)<\/td><td align=right>(\S\d+)<\/td><td align=right>(\S+)<\/td><td align=left>(\S+)<\/td><td align=right>(\S+)<\/td><td align=right>(\d+\.\d+)<\/td><td align=left>(\S+)<\/td><td align=left>(\S+)<\/td><td align=right>(\d+)<\/td><td align=right>(\d+)<\/td><\/tr>/;

			my $spot = Ham::WSPR::Spot->new({'date' => $date,
												'time' => $time,
												'call' => $call,
												'frequency' => $freq,
												'snr' => $snr,
												'drift' => $drift,
												'locator' => $call_loc,
												'power_dbm' => $dbm,
												'power_watts' => $watts,
												'spotter' => $spotter,
												'spotter_locator' => $spotter_loc,
												'distance_km' => $dist_km,
												'distance_mi' => $dist_mi});
			
			$spot->commit;

			$self->{spots}->{'spot'}{$spot->get_id} = $spot;
		}
	}

	$self->{spots}->{'wspr-url'} = $self->get_request_uri();
	my $date = now;
	$self->{spots}->{'date'} = $date;
	my $xml = XML::Simple->new('RootName' => 'wspr-spots', 'XMLDecl' => 1, 'NoAttr' => 1);

	$self->{xml_spots} = $xml->XMLout($self->{spots});
}

1;
