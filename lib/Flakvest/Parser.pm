#!/usr/bin/perl

package Flakvest::Parser;

use YAML;

sub new {
	my ($package, $opt) = @_;

	bless $package, $opt;
	return $opt;
}

sub loadRules {
	my ($self, $opt) = @_;

	my $rules;

	return($rules);	
}
