#!/usr/bin/perl

package Ham::WSPR::Spot;

use strict;
use warnings;

our $VERSION = '0.001';

use base qw(Class::Accessor);
use Carp qw(cluck croak confess);
use Data::Dumper;
use Data::GUID;
use Digest::MD5 qw(md5_hex);
use namespace::clean;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors( qw(date time call frequency snr drift locator power_dbm power_watts spotter spotter_locator distance_km distance_miles) );
__PACKAGE__->mk_ro_accessors( qw(id hash) );

sub commit
{
	my ($self) = @_;

	# Generate GUID
	my $guid = Data::GUID->new;
	$self->{id} = $guid->as_string();

	# Calculate hash
	$self->{hash} = $self->calculate_hash($self->get_call, $self->get_date, $self->get_time, $self->get_frequency, $self->get_spotter, $self->get_snr);

	if($@)
	{
		return 0;
	}
	else
	{
		return 1;
	}
}

sub calculate_hash
{
	my ($self, $given_call, $given_date, $given_time, $given_frequency, $given_spotter, $given_snr) = @_;

	my $hash_source = "$given_call~$given_date~$given_time~$given_frequency~$given_spotter~$given_snr";
	my $hash = md5_hex($hash_source);

	return $hash;
}
	
1;
