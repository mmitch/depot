#!/usr/bin/env perl
#
#   depot.pl  -  track a share portfolio
#   Copyright (C) 2022  Christian Garbs <mitch@cgarbs.de>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;


package Format;

sub cash {
    return sprintf '%8.2f EUR', $_[0];
}

sub date {
    my (undef, undef, undef, $mday, $mon, $year) = localtime( $_[0] );
    return sprintf '%02d.%02d.%04d', $mday, $mon+1, $year+1900;
}

sub pair {
    return sprintf '%s  (%s)', $_[0], $_[1];
}

sub rate {
    return sprintf '%8.3f EUR', $_[0];
}

sub rel {
    return sprintf '%+7.2f%%', $_[0];
}

sub shares {
    return sprintf '%8.3f St.', $_[0];
}


package Transaction;

use Moo;
has date   => ( is => 'ro', required => 1 );
has shares => ( is => 'ro', required => 1 );
has cash   => ( is => 'ro', required => 1 );
has fees   => ( is => 'ro', required => 1 );
has rate   => ( is => 'lazy' );

sub _build_rate {
    my $self = shift;
    my $rate =  $self->cash / $self->shares;
    return $rate < 0 ? -$rate : $rate;
}

sub is_buy {
    my $self = shift;
    return $self->shares > 0;
}

sub is_sell {
    my $self = shift;
    return $self->shares < 0;
}


package Ledger;

use Moo;
has tx             => ( is => 'ro', required => 1 );
has prev           => ( is => 'ro');
has shares         => ( is => 'lazy' );
has shares_formatted     => ( is => 'lazy' );
has cash           => ( is => 'lazy' );
has cash_formatted       => ( is => 'lazy' );
has fees           => ( is => 'lazy' );
has rate           => ( is => 'lazy' );
has rate_formatted       => ( is => 'lazy' );
has bought         => ( is => 'lazy' );
has sold           => ( is => 'lazy' );
has invested       => ( is => 'lazy' );
has d_rate_rel     => ( is => 'lazy' );
has d_rate_rel_formatted => ( is => 'lazy' );
has d_cash_abs     => ( is => 'lazy' );
has d_cash_abs_formatted => ( is => 'lazy' );
has d_cash_rel     => ( is => 'lazy' );
has d_cash_rel_formatted => ( is => 'lazy' );
has first_rate     => ( is => 'lazy' );

sub date {
    my $self = shift;
    return $self->tx->date;
}

sub date_formatted {
    my $self = shift;
    return Format::date($self->date);
}

sub _build_shares {
    my $self = shift;
    return $self->tx->shares + $self->_prev->shares;
}

sub _build_shares_formatted {
    my $self = shift;
    return Format::shares($self->shares);
}

sub _build_cash {
    my $self = shift;
    return $self->shares * $self->tx->rate;
}

sub _build_cash_formatted {
    my $self = shift;
    return Format::cash($self->cash);
}

sub _build_fees {
    my $self = shift;
    return $self->tx->fees + $self->_prev->fees;
}

sub _build_rate {
    my $self = shift;
    return $self->tx->rate;
}

sub _build_rate_formatted {
    my $self = shift;
    return Format::rate($self->rate);
}

sub _build_bought {
    my $self = shift;
    return $self->_prev->bought + ($self->tx->is_buy  ? $self->tx->cash : 0);
}

sub _build_sold {
    my $self = shift;
    return $self->_prev->sold   + ($self->tx->is_sell ? $self->tx->cash : 0);
}

sub _build_invested {
    my $self = shift;
    return $self->bought + $self->fees - $self->sold;
}

sub _build_d_rate_rel {
    my $self = shift;
    return (100 * $self->rate / $self->first_rate) - 100;
}

sub _build_d_rate_rel_formatted {
    my $self = shift;
    return Format::rel($self->d_rate_rel);
}

sub _build_d_cash_abs {
    my $self = shift;
    return $self->cash - $self->invested;
}

sub _build_d_cash_abs_formatted {
    my $self = shift;
    return Format::cash($self->d_cash_abs);
}

sub _build_d_cash_rel {
    my $self = shift;
    return (100 * $self->cash / $self->invested) - 100;
}

sub _build_first_rate {
    my $self = shift;
    return $self->prev ? $self->prev->first_rate : $self->rate;
}

sub _build_d_cash_rel_formatted {
    my $self = shift;
    return Format::rel($self->d_cash_rel);
}

sub _prev {
    my $self = shift;
    return $self->prev // EmptyLedger->instance();
}



package EmptyLedger;

use Moo;
extends 'Ledger';
with 'MooX::Singleton';

has tx     => ( is => 'lazy' );
has shares => ( is => 'ro', default => 0 );
has bought => ( is => 'ro', default => 0 );
has sold   => ( is => 'ro', default => 0 );
has fees   => ( is => 'ro', default => 0 );

sub _build_tx {
    return new Transaction(
	date   => 0,
	shares => 0,
	cash   => 0,
	fees   => 0,
	);
}



package Fund;

use Moo;
has id     => ( is => 'ro', required => 1 );
has ledger => ( is => 'rwp' );

sub add_tx {
    my ($self, $tx) = @_;
    $self->_set_ledger( new Ledger(tx => $tx, prev => $self->ledger) );
}


package FileReader;

use POSIX qw(mktime);

sub import {
    my $filename = shift;

    my $funds = {};
    my $date;

    open my $fh, '<', $filename or die "can't open `$filename': $!";

    while (my $line = <$fh>) {
	chomp $line;
	$line =~ s/#.*$//;
	next if $line =~ /^\s*$/;

	if ($line =~ /@@ (\d{2})\.(\d{2})\.(\d{4})/) {
	    my ($hour, $min, $sec) = (12, 0, 0);
	    my ($mday, $mon, $year) = ($1, $2-1, $3-1900);
	    $date = mktime($sec, $min, $hour, $mday, $mon, $year);
	}
	elsif ($line =~ /
			\+FUND				# fixed marker
			\s+				# separator
			([a-zA-Z0-9_]+)			# fund name
			/x) {
	    my ($id) = ($1);
	    $funds->{$id} = new Fund( id => $id );
	}
	elsif ($line =~ /
			(\S+)				# fund
			\s+				# separator
			([+-][0-9]+(?:,[0-9]+)?)	# share amount with optional fraction, always signed
			\s+=\s+				# = separator
			([0-9]+(?:,[0-9]+)?)		# EUR amount with optional fraction
			\s+!\s+				# ! separator
			([0-9]+(?:,[0-9]+)?)		# EUR fees with optional fraction
		    	/x) {

	    my ($id, $shares, $cash, $fees) = ($1, $2, $3, $4);
	    die "transaction for unknown fund `$id' in line $.\n" unless exists $funds->{$id};
	    my $fund = $funds->{$id};

	    $shares =~ tr/,/./;
	    $cash   =~ tr/,/./;
	    $fees   =~ tr/,/./;
	
	    my $tx = new Transaction( date => $date, shares => $shares, cash => $cash, fees => $fees );

	    $fund->add_tx($tx);
	}
    }

    close $fh or die "can't close `$filename': $!";

    return $funds;
}


package TableFormatter;

use Text::ASCIITable;

sub short {
    my %funds = %{$_[0]};

    my $table = Text::ASCIITable->new();
    $table->setCols('ETF','Anteile','Wert', 'Kurs        (seit Start)', 'Gewinn        (relativ )', 'Stand');
    my ($total_cash, $total_invested);
    foreach my $fund (map { $funds{$_} } sort keys %funds) {
	my $ledger = $fund->ledger;
	$table->addRow(
	    $fund->id,
	    $ledger->shares_formatted,
	    $ledger->cash_formatted,
	    Format::pair($ledger->rate_formatted,       $ledger->d_rate_rel_formatted),
	    Format::pair($ledger->d_cash_abs_formatted, $ledger->d_cash_rel_formatted),
	    $ledger->date_formatted,
	    );

	$total_cash     += $ledger->cash;
	$total_invested += $ledger->invested;
    }
    $table->addRowLine();

    my $total_d_cash_abs = $total_cash - $total_invested;
    my $total_d_cash_rel = (100 * $total_cash / $total_invested) - 100;
    $table->addRow(
	'Depot',
	'',
	Format::cash($total_cash),
	'',
	Format::pair(Format::cash($total_d_cash_abs), Format::rel($total_d_cash_rel)),
	''
	);

    return $table;
}


package main;

my $funds = FileReader::import($ARGV[0] // 'depot.txt');

print TableFormatter::short($funds);

# TODO: print GnuPlots of Kursentwicklung und Gewinn/Verlustentwicklung
# TODO: show Performance pro Jahr (mit Marker, wenn jünger als 1 Jahr)
# TODO: show colored output (red/green)?  looks nice in the git diff view ;)
