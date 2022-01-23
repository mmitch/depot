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
use locale;


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

sub yearly_rel {
    my ($duration, $rel) = @_;
    return '' unless $duration;
    my $warn = $duration < 1 ? '!!' : '  ';
    return $warn . '  ' . Format::rel($rel);
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
has tx         => ( is => 'ro', required => 1 );
has prev       => ( is => 'ro');
has first      => ( is => 'lazy' );
has shares     => ( is => 'lazy' );
has cash       => ( is => 'lazy' );
has fees       => ( is => 'lazy' );
has rate       => ( is => 'lazy' );
has bought     => ( is => 'lazy' );
has sold       => ( is => 'lazy' );
has invested   => ( is => 'lazy' );
has d_rate_rel => ( is => 'lazy' );
has d_cash_abs => ( is => 'lazy' );
has d_cash_rel => ( is => 'lazy' );

sub date {
    my $self = shift;
    return $self->tx->date;
}

sub _build_first {
    my $self = shift;
    return $self->prev ? $self->prev->first : $self;
}

sub _build_shares {
    my $self = shift;
    return $self->tx->shares + $self->_prev->shares;
}

sub _build_cash {
    my $self = shift;
    return $self->shares * $self->tx->rate;
}

sub _build_fees {
    my $self = shift;
    return $self->tx->fees + $self->_prev->fees;
}

sub _build_rate {
    my $self = shift;
    return $self->tx->rate;
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
    return (100 * $self->rate / $self->first->rate) - 100;
}

sub _build_d_cash_abs {
    my $self = shift;
    return $self->cash - $self->invested;
}

sub _build_d_cash_rel {
    my $self = shift;
    return (100 * $self->cash / $self->invested) - 100;
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

use Module::Load;

use Moo;
has id                   => ( is => 'ro', required => 1 );
has _ledger              => ( is => 'rw' );

sub add_tx {
    my ($self, $tx) = @_;
    $self->_ledger( new Ledger(tx => $tx, prev => $self->_ledger) );
}

sub cash {
    my $self = shift;
    return $self->_ledger->cash;
}

sub d_cash_abs {
    my $self = shift;
    return $self->_ledger->d_cash_abs;
}

sub invested {
    my $self = shift;
    return $self->_ledger->invested;
}

sub bought_formatted {
    my $self = shift;
    return Format::cash($self->_ledger->bought);
}

sub sold_formatted {
    my $self = shift;
    return Format::cash($self->_ledger->sold);
}

sub fees_formatted {
    my $self = shift;
    return Format::cash($self->_ledger->fees);
}

sub years_formatted {
    my $self = shift;
    return sprintf '%6.2f Jahre', $self->_years;
}

sub date_formatted {
    my $self = shift;
    return Format::date($self->_ledger->date);
}

sub shares_formatted {
    my $self = shift;
    return Format::shares($self->_ledger->shares);
}

sub cash_formatted {
    my $self = shift;
    return Format::cash($self->cash);
}

sub rate_formatted {
    my $self = shift;
    return Format::rate($self->_ledger->rate);
}

sub first_rate_formatted {
    my $self = shift;
    return Format::rate($self->_ledger->first->rate);
}

sub d_rate_rel_formatted {
    my $self = shift;
    return Format::rel($self->_ledger->d_rate_rel);
}

sub d_cash_abs_formatted {
    my $self = shift;
    return Format::cash($self->_ledger->d_cash_abs);
}

sub d_cash_rel_formatted {
    my $self = shift;
    return Format::rel($self->_ledger->d_cash_rel);
}

sub d_cash_rel_per_year_formatted {
    my $self = shift;
    return Format::yearly_rel($self->_years, $self->_d_cash_rel_per_year);
}

sub d_rate_rel_per_year_formatted {
    my $self = shift;
    return Format::yearly_rel($self->_years, $self->_d_rate_rel_per_year);
}

sub d_rate_rel_over_time {
    my $self = shift;

    return $self->_get_over_time(
	sub { my ($tx) = @_; [ $tx->date, $tx->d_rate_rel ] }
	);
}

sub d_cash_rel_over_time {
    my $self = shift;

    return $self->_get_over_time(
	sub { my ($tx) = @_; [ $tx->date, $tx->d_cash_rel ] }
	);
}

sub _get_over_time {
    my ($self, $mapper) = @_;

    my @data;
    
    my $tx = $self->_ledger;
    while (defined $tx) {
	unshift @data, &$mapper($tx);
	$tx = $tx->prev;
    }

    return @data;
}

sub _years {
    load "DateTime";

    my $self = shift;
    my $first = DateTime->from_epoch( epoch => $self->_ledger->first->date );
    my $last  = DateTime->from_epoch( epoch => $self->_ledger->date );
    my $duration = $last - $first;

    # 31 days/month is an approximation, but it is of low magnitude in the result
    return $duration->years + ($duration->months/12) + ($duration->days/31);
}

sub _d_cash_rel_per_year {
    my $self = shift;
    return $self->_ledger->d_cash_rel / $self->_years;
}

sub _d_rate_rel_per_year {
    my $self = shift;
    return $self->_ledger->d_rate_rel / $self->_years;
}


package FileReader;

use POSIX qw(mktime);

sub import {
    my $filename = shift;

    my %funds;
    my $date;

    open my $fh, '<', $filename or die "can't open `$filename': $!";

    while (my $line = <$fh>) {
	chomp $line;
	$line =~ s/#.*$//;
	next if $line =~ /^\s*$/;

	if ($line =~ /@@ (\d{2})\.(\d{2})\.(\d{4})/) {
	    my ($hour, $min, $sec) = (12, 0, 0);
	    my ($mday, $mon, $year) = ($1, $2-1, $3-1900);
	    my $newdate = mktime($sec, $min, $hour, $mday, $mon, $year);
	    die "date `$1.$2.$3' must be later than previous date in line $." unless (!defined $date or $newdate > $date);
	    $date = $newdate;
	}
	elsif ($line =~ /
			\+FUND				# fixed marker
			\s+				# separator
			([a-zA-Z0-9_]+)			# fund name
			/x) {
	    my ($id) = ($1);
	    $funds{$id} = new Fund( id => $id );
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
	    die "transaction for unknown fund `$id' in line $.\n" unless exists $funds{$id};
	    my $fund = $funds{$id};

	    $shares =~ tr/,/./;
	    $cash   =~ tr/,/./;
	    $fees   =~ tr/,/./;
	
	    my $tx = new Transaction( date => $date, shares => $shares, cash => $cash, fees => $fees );

	    $fund->add_tx($tx);
	}
	else {
	    die "unparseable line `$line' at line $.\n";
	}
    }

    close $fh or die "can't close `$filename': $!";

    return map { $funds{$_} } sort keys %funds;
}


package Parallel;

use threads;

sub start {
    my ($coderef, @params) = @_;
    threads->create($coderef, @params);
}

sub wait_for_all {
    foreach my $thr (threads->list()) {
	$thr->join();
    }
}


package GnuPlot;

# Gnuplot does the right thing™ although months have different lengths
my $SECONDS_PER_MONTH = 2592000;

use constant PALETTE => [ qw( 1B7EBB D95F02 7570B3 E7298A 66A61E E6AB02 A6761D 666666 ) ];

sub plot_all {
    my @funds = @_;

    Parallel::start(\&plot_d_rate_rel, @funds);
    Parallel::start(\&plot_d_cash_rel, @funds);
    Parallel::start(\&plot_cash, @funds);
    Parallel::start(\&plot_plusminus, @funds);
    Parallel::wait_for_all();
}

sub plot_d_rate_rel {
    my @funds = @_;

    _plot_over_time(
	'share price over time',
	sub { my ($fund) = @_; $fund->d_rate_rel_over_time },
	@funds
	);
}

sub plot_d_cash_rel {
    my @funds = @_;

    _plot_over_time(
	'win/loss over time',
	sub { my ($fund) = @_; $fund->d_cash_rel_over_time },
	@funds
	);
}

sub plot_cash {
    my @funds = @_;

    _plot_distribution(
	'portfolio',
	sub { my ($fund) = @_; [ $fund->cash, $fund->cash_formatted . ' ' . $fund->id ] },
	@funds
	);
}

sub plot_plusminus {
    my @funds = @_;

    _plot_stacked(
	'win/loss by fund',
	sub { my ($fund) = @_; $fund->d_cash_abs },
	@funds
	);
}

sub _plot_over_time {
    my ($title, $getter, @funds) = @_;

    my $gnuplot = _open_gnuplot();

    print $gnuplot <<~"EOF";
	set title "$title"
	set xdata time
	set timefmt "%s"
	set format x "%m/%Y"
	set format y "%+-.0f%%"
	set xtics $SECONDS_PER_MONTH*3
	set key left
	# grid
	set style line 12 lc rgb'#808080' lt 0 lw 1
	set grid back ls 12
	EOF

    my $i = 0;
    printf $gnuplot "plot %s\n",
	join(", ", map { sprintf "'-' using 1:2 title \"%s\" with lines lt 1 lw 2 lc rgb '#%s'", $_->{id}, PALETTE->[$i++] } @funds);

    foreach my $fund (@funds) {
	printf $gnuplot "%d %.3f\n", @{$_} foreach &$getter($fund);
	print  $gnuplot "e\n";
    }

    _close_gnuplot($gnuplot);

}

sub _plot_stacked {
    my ($title, $getter, @funds) = @_;

    my $gnuplot = _open_gnuplot();

    print $gnuplot <<~"EOF";
	set title "$title"
	set format y "%+-.2f EUR"
	set key outside
	set style data histogram
	set style histogram rowstacked
	set style fill solid border -1
	set boxwidth 1.5
	set xrange [-1:1]
	set xzeroaxis lw 1 lt 1 lc black
	unset xtics
	# grid
	set style line 12 lc rgb'#808080' lt 0 lw 1
	set grid back ls 12
	EOF

    my $i = 0;
    printf $gnuplot "plot %s\n",
	join(", ", map { sprintf "'-' using 1 title \"%s\" lc rgb '#%s'", $_->{id}, PALETTE->[$i++] } @funds);

    foreach my $fund (@funds) {
	my $value = &$getter($fund);
	printf $gnuplot "%.2f\n", $value;
	print  $gnuplot "e\n";
    }

    _close_gnuplot($gnuplot);

}

sub _plot_distribution {
    my ($title, $getter, @funds) = @_;

    my $gnuplot = _open_gnuplot();

    print $gnuplot <<~"EOF";
	set title "$title"
	set size square
	set xrange [-1.1:1.1]
	set yrange [-1.1:1.1]
	set style fill solid 1
	set key Left reverse
	unset tics
	unset border
	EOF

    my $sum;
    my @data = map {
	my $fund = $_;
	my $value = &$getter($fund);
	$sum += $value->[0];

	# replace leading x spaces by a blank space of x zeroes width
	$value->[1] =~ s/^( +)/_create_filler($1)/e;
	$value;
    } @funds;

    my $i = 0;
    printf $gnuplot "plot %s\n",
	join(", ", map { sprintf "'-' title \"%s\" with circle lc rgb '#%s'", $_->[1], PALETTE->[$i++] } @data);

    my $x = 0;
    my $y = 0;
    my $radius = 1;
    my $angle_from = 0;
    foreach my $data (@data) {

	my $angle_to = $angle_from + ( 360.0 * $data->[0] / $sum );

	printf $gnuplot "%d %d %d %d %d\n", $x, $y, $radius, $angle_from, $angle_to;
	print  $gnuplot "e\n";

	$angle_from = $angle_to;
    }

    _close_gnuplot($gnuplot);

}

sub _create_filler {
    my $width = shift;
    return sprintf '&{%s}', '0' x length $width;
}

sub _open_gnuplot {
    open my $gnuplot, '|-', 'gnuplot -p - ' or die "can't pipe to gnuplot: $!";
    return  $gnuplot;
}

sub _close_gnuplot {
    my $gnuplot = shift;
    print $gnuplot "pause mouse close\n";
    close $gnuplot or die "can't close gnuplot: $!";
}


package TablePrinter;

use Text::ASCIITable;

sub short {
    my @funds = @_;

    my $table = Text::ASCIITable->new();
    $table->setCols('ETF','Anteile','Wert', 'Kurs        (seit Start)', 'Gewinn        (relativ )', 'Stand');
    my ($total_cash, $total_invested);
    foreach my $fund (@funds) {
	$table->addRow(
	    $fund->id,
	    $fund->shares_formatted,
	    $fund->cash_formatted,
	    Format::pair($fund->rate_formatted,       $fund->d_rate_rel_formatted),
	    Format::pair($fund->d_cash_abs_formatted, $fund->d_cash_rel_formatted),
	    $fund->date_formatted,
	    );

	$total_cash     += $fund->cash;
	$total_invested += $fund->invested;
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

    print $table;
}

sub verbose {
    my @funds = @_;

    use utf8;
    binmode STDOUT, ':encoding(utf8)';

    my $table = Text::ASCIITable->new(); # this has problems with UTF8 and multibyte characters :(
    $table->setCols('ETF', map { shift->id } @funds);

    my $data = [ $table, \@funds ];

    _addRow($data, 'Stand',     sub { shift->date_formatted });
    _addRow($data, 'Anteile',   sub { shift->shares_formatted });
    $table->addRowLine();

    _addRow($data, 'Kurs',      sub { shift->rate_formatted });
    _addRow($data, '1. Kurs',   sub { shift->first_rate_formatted });
    _addRow($data, '± Kurs %',  sub { shift->d_rate_rel_formatted });
    $table->addRowLine();

    _addRow($data, 'Gekauft',   sub { shift->bought_formatted });
    _addRow($data, 'Verkauft',  sub { shift->sold_formatted });
    _addRow($data, 'Gebuehren', sub { shift->fees_formatted });
    $table->addRowLine();

    _addRow($data, 'Wert',      sub { shift->cash_formatted });
    _addRow($data, 'Gewinn',    sub { shift->d_cash_abs_formatted });
    _addRow($data, 'Gewinn %',  sub { shift->d_cash_rel_formatted });
    $table->addRowLine();

    _addRow($data, 'Haltezeit', sub { shift->years_formatted });
    _addRow($data, 'Gewinn/J.', sub { shift->d_cash_rel_per_year_formatted });
    _addRow($data, '± Kurs/J.', sub { shift->d_rate_rel_per_year_formatted });
    $table->addRowLine();


    print $table;
}

sub _addRow {
    my ($data, $title, $getter) = @_;
    $data->[0]->addRow( $title, map { &$getter($_) } @{$data->[1]} );
}


package main;

my $mode = \&TablePrinter::short;
my $first_arg = $ARGV[0] // '';

if ($first_arg eq '-default') {
    shift;
}
elsif ($first_arg eq '-verbose') {
    shift;
    $mode = \&TablePrinter::verbose;
}
elsif ($first_arg eq '-plot') {
    shift;
    $mode = \&GnuPlot::plot_all;
}

my @funds = FileReader::import($ARGV[0] // 'depot.txt');
die "no funds found" unless @funds;

&$mode(@funds);

# TODO: show colored output (red/green)?  looks nice in the git diff view ;)
# TODO: add stacked barchart for wins/losses per fund
# TODO: add total portfolio pseudo-fund to -verbose
