#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Field::Date;
use parent 'Mail::Message::Field::Structured';

use warnings;
use strict;

use Log::Report   'mail-message', import => [ qw/__x error/ ];

use POSIX qw/mktime tzset/;

#--------------------
=chapter NAME

Mail::Message::Field::Date - message header field with uris

=chapter SYNOPSIS

  my $f = Mail::Message::Field->new(Date => time);
  my $f = Mail::Message::Field::Date->new(Date => time);
  my $date = $f->date;    # cleaned-up and validated
  my $time = $date->time; # converted to POSIX time

=chapter DESCRIPTION
Dates are a little more tricky than it should be: the formatting permits
a few constructs more than other RFCs use for timestamps.  For instance,
a small subset of timezone abbreviations are permitted.

The studied date field will reformat the content into a standard
form.

=chapter METHODS

=section Constructors

=c_method new $data
=default attributes <ignored>

=examples
  my $mmfd = 'Mail::Message::Field::Date';
  my $f = $mmfd->new(Date => time);
=cut

my $dayname = qr/Mon|Tue|Wed|Thu|Fri|Sat|Sun/;
my @months  = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
my %monthnr; { my $i; $monthnr{$_} = ++$i for @months }
my %tz      = qw/
	EDT -0400  EST -0500  CDT -0500  CST -0600
	MDT -0600  MST -0700  PDT -0700  PST -0800
	UT  +0000  GMT +0000/;

sub parse($)
{	my ($self, $string) = @_;

	my ($dn, $d, $mon, $y, $h, $min, $s, $z) = $string =~ m/
		 ^	\s*
			(?: ($dayname) \s* \, \s* )?         # dayname (optional)
			( 0?[1-9] | [12][0-9] | 3[01] ) \s+  # day
			( [A-Z][a-z][a-z]|[0-9][0-9]  ) \s+  # month
			( (?: 19 | 20 | ) [0-9][0-9]  ) \s+  # year
			( [0-1]?[0-9] | 2[0-3] )        \s*  # hour
			    [:.] ( [0-5][0-9] )         \s*  # minute
			(?: [:.] ( [0-5][0-9] ) )?      \s*  # second (optional)
			( [+-][0-9]{4} | [A-Z]+ )?           # zone
			                                     # optionally followed by trash
		/x or return undef;

	$dn //= '';
	$dn   =~ s/\s+//g;
	$mon  = $months[$mon-1] if $mon =~ /[0-9]+/;   # Broken mail clients

	$y   += 2000 if $y < 50;
	$y   += 1900 if $y < 100;

	$z  ||= '-0000';
	$z    = $tz{$z} || '-0000' if $z =~ m/[A-Z]/;

	$self->{MMFD_date} = sprintf "%s%02d %s %04d %02d:%02d:%02d %s",
		(length $dn ? "$dn, " : ''), $d, $mon, $y, $h, $min, $s // 0, $z;

	$self;
}

sub produceBody() { $_[0]->{MMFD_date} }

#--------------------
=section Access to the content

=method addAttribute ...
Attributes are not supported for date fields.

=error no attributes for date fields.
It is not possible to add attributes to date fields: it is not permitted
by the RFCs.
=cut

sub addAttribute($;@)
{	my $self = shift;
	error __x"no attributes for date fields.";
}

=method date
The validated and standardized date representation for this field.
When the body of this field is not recognized, then this will return
undef.
=cut

sub date() { $_[0]->{MMFD_date} }

=method time
Convert date into a timestamp, as produced with POSIX::time().
=cut

sub time()
{	my $date = shift->date or return;
	my ($d, $mon, $y, $h, $min, $s, $z) = $date =~ m/
		^ (?:\w\w\w\,\s+)? (\d\d)\s+(\w+)\s+(\d\d\d\d) \s+ (\d\d)\:(\d\d)\:(\d\d) \s+ ([+-]\d\d\d\d)? \s* $
	/x;

	my $oldtz = $ENV{TZ};
	$ENV{TZ}  = 'UTC';
	tzset;
	my $timestamp = mktime $s, $min, $h, $d, $monthnr{$mon}-1, $y-1900;
	if(defined $oldtz) { $ENV{TZ}  = $oldtz } else { delete $ENV{TZ} }
	tzset;

	$timestamp += ($1 eq '-' ? 1 : -1) * ($2*3600 + $3*60)
		if $z =~ m/^([+-])(\d\d)(\d\d)$/;
	$timestamp;
}

#--------------------
=section Error handling
=cut

1;
