#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Field::AuthResults;
use parent 'Mail::Message::Field::Structured';

use warnings;
use strict;

use Log::Report   'mail-message';

use URI;

#--------------------
=chapter NAME

Mail::Message::Field::AuthResults - message header field authentication result

=chapter SYNOPSIS

  my $f = Mail::Message::Field->new('Authentication-Results' => '...');

  my $g = Mail::Message::Field->new('Authentication-Results');
  $g->addResult(method => 'dkim', result => 'fail');

=chapter DESCRIPTION

Mail Transfer Agents may check the authenticity of an incoming message.
They add 'Authentication-Results' headers, maybe more than one.  This
implementation is based on RFC7601.

=chapter METHODS

=cut

#--------------------
=section Constructors

=c_method new %options

=default attributes <ignored>

=requires server $domain
Where the authentication tool ran.  This should be your local service,
otherwise you may accept spoofed headers!

=option  version INTEGER
=default version undef

=option  results ARRAY
=default results []
Each authentication method is represented by a HASH, which contains
the 'method' and 'result' keys.  Sometimes, there is a 'comment'.
Properties of form 'ptype.pname' will be there as well.
=cut

sub init($)
{	my ($self, $args) = @_;
	$self->{MMFA_server}  = delete $args->{server};
	$self->{MMFA_version} = delete $args->{version};

	$self->{MMFA_results} = [];
	$self->addResult($_) for @{delete $args->{results} || []};

	$self->SUPER::init($args);
}

sub parse($)
{	my ($self, $string) = @_;
	$string =~ s/\r?\n/ /g;

	(undef, $string) = $self->consumeComment($string);
	$self->{MMFA_server}  = $string =~ s/^\s*([.\w-]*\w)// ? $1 : 'unknown';

	(undef, $string) = $self->consumeComment($string);
	$self->{MMFA_version} = $string =~ s/^\s*([0-9]+)// ? $1 : 1;

	(undef, $string) = $self->consumeComment($string);
	$string =~ s/^.*?\;/;/;   # remove accidents

	my @results;
	while( $string =~ s/^\s*\;// )
	{
		(undef, $string) = $self->consumeComment($string);
		if($string =~ s/^\s*none//)
		{	(undef, $string) = $self->consumeComment($string);
			next;
		}

		my %result;
		push @results, \%result;

		$string =~ s/^\s*([\w-]*\w)// or next;
		$result{method} = $1;

		(undef, $string) = $self->consumeComment($string);
		if($string =~ s!^\s*/!!)
		{	(undef, $string) = $self->consumeComment($string);
			$result{method_version} = $1 if $string =~ s/^\s*([0-9]+)//;
		}

		(undef, $string) = $self->consumeComment($string);
		if($string =~ s/^\s*\=//)
		{	(undef, $string) = $self->consumeComment($string);
			$result{result} = $1
				if $string =~ s/^\s*(\w+)//;
		}

		(my $comment, $string) = $self->consumeComment($string);
		if($comment)
		{	$result{comment} = $comment;
			(undef, $string) = $self->consumeComment($string);
		}

		if($string =~ s/\s*reason//)
		{	(undef, $string) = $self->consumeComment($string);
			if($string =~ s/\s*\=//)
			{	(undef, $string) = $self->consumeComment($string);
				$result{reason} = $1
					if $string =~ s/^\"([^"]*)\"//
					|| $string =~ s/^\'([^']*)\'//
					|| $string =~ s/^(\w+)//;
			}
		}

		while($string =~ /\S/)
		{	(undef, $string) = $self->consumeComment($string);
			last if $string =~ /^\s*\;/;

			my $ptype = $string =~ s/^\s*([\w-]+)// ? $1 : last;
			(undef, $string) = $self->consumeComment($string);

			my ($property, $value);
			if($string =~ s/^\s*\.//)
			{	(undef, $string) = $self->consumeComment($string);
				$property = $string =~ s/^\s*([\w-]+)// ? $1 : last;
				(undef, $string) = $self->consumeComment($string);
				if($string =~ s/^\s*\=//)
				{	(undef, $string) = $self->consumeComment($string);
					$string =~ s/^\s+//;
					$string =~ s/^\"([^"]*)\"// || $string =~ s/^\'([^']*)\'// || $string =~ s/^([\w@.-]+)//
						or last;

					$value = $1;
				}
			}

			if(defined $value)
			{	$result{"$ptype.$property"} = $value;
			}
			else
			{	$string =~ s/^.*?\;/;/g;   # recover from parser problem
			}
		}
	}
	$self->addResult($_) for @results;

	$self;
}

sub produceBody()
{	my $self = shift;
	my $source  = $self->server;
	my $version = $self->version;
	$source    .= " $version" if $version!=1;

	my @results;
	foreach my $r ($self->results)
	{	my $method = $r->{method};
		$method   .= "/$r->{method_version}"
			if $r->{method_version} != 1;

		my $result = "$method=$r->{result}";

		$result   .= ' ' . $self->createComment($r->{comment})
			if defined $r->{comment};

		if(my $reason = $r->{reason})
		{	$reason =~ s/"/\\"/g;
			$result .= qq{ reason="$reason"};
		}

		foreach my $prop (sort keys %$r)
		{	index($prop, '.') > -1 or next;
			my $value = $r->{$prop};
			$value    =~ s/"/\\"/g;
			$result  .= qq{ $prop="$value"};
		}

		push @results, $result;
	}

	push @results, 'none' unless @results;
	join '; ', $source, @results;
}

#--------------------
=section Access to the content

=method addAttribute ...
Attributes are not supported here.

=error no attributes for Authentication-Results.
Is is not possible to add attributes to this field.
=cut

sub addAttribute($;@)
{	my $self = shift;
	error __x"no attributes for Authentication-Results.";
	$self;
}

=method server
The hostname which ran this authentication tool.

=method version
The version of the 'Authentication-Results' header, which may be different
from '1' (default) for successors of RFC7601.
=cut

sub server()  { $_[0]->{MMFA_server} }
sub version() { $_[0]->{MMFA_version} }

=method results
Returns a LIST of result HASHes.  Each HASH at least contains keys 'method',
'method_version', and 'result'.
=cut

sub results() { @{ $_[0]->{MMFA_results}} }

=method addResult HASH|PAIRS
Add new results to this header.  Invalid results are ignored.
=cut

sub addResult($)
{	my $self = shift;

	my $r = @_==1 ? shift : {@_};
	$r->{method} && $r->{result} or return ();
	$r->{method_version} ||= 1;
	push @{$self->{MMFA_results}}, $r;
	delete $self->{MMFF_body};

	$r;
}

#--------------------
=section Error handling
=cut

1;
