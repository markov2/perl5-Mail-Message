#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Body::String;
use parent 'Mail::Message::Body';

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw/__x fault/ ];

use Mail::Box::FastScalar ();

#--------------------
=chapter NAME

Mail::Message::Body::String - body of a Mail::Message stored as single string

=chapter SYNOPSIS

  See Mail::Message::Body

=chapter DESCRIPTION

The body (content) of a message can be stored in various ways.  In this
documentation you will find the description of extra functionality you have
when a message is stored as a single scalar.

Storing a whole message in one string is only a smart choice when the content
is small or encoded. Even when stored as a scalar, you can still treat the
body as if the data is stored in lines or an external file, but this will be
slower.

=chapter METHODS

=c_method new %options

=fault Unable to read file $name for message body scalar: $!
A Mail::Message::Body::String object is to be created from a named
file, but it is impossible to read that file to retrieve the lines within.
=cut

# The scalar is stored as reference to avoid a copy during creation of
# a string object.

sub _data_from_filename(@)
{	my ($self, $filename) = @_;

	delete $self->{MMBS_nrlines};
	open my $in, '<:raw', $filename
		or fault __x"unable to read file {name} for message body scalar", name => $filename;

	my @lines = $in->getlines;
	$in->close;

	$self->{MMBS_nrlines} = @lines;
	$self->{MMBS_scalar}  = join '', @lines;
	$self;
}

sub _data_from_filehandle(@)
{	my ($self, $fh) = @_;
	if(ref $fh eq 'Mail::Box::FastScalar')
	{	my $lines = $fh->getlines;
		$self->{MMBS_nrlines} = @$lines;
		$self->{MMBS_scalar}  = join '', @$lines;
	}
	else
	{	my @lines = $fh->getlines;
		$self->{MMBS_nrlines} = @lines;
		$self->{MMBS_scalar}  = join '', @lines;
	}
	$self;
}

sub _data_from_lines(@)
{	my ($self, $lines) = @_;
	$self->{MMBS_nrlines} = @$lines unless @$lines==1;
	$self->{MMBS_scalar}  = @$lines==1 ? shift @$lines : join('', @$lines);
	$self;
}

sub clone()
{	my $self = shift;
	(ref $self)->new(data => $self->string, based_on => $self);
}

sub nrLines()
{	my $self = shift;
	return $self->{MMBS_nrlines} if defined $self->{MMBS_nrlines};

	my $lines = $self->{MMBS_scalar} =~ tr/\n/\n/;
	$lines++ if $self->{MMBS_scalar} !~ m/\n\z/;
	$self->{MMBS_nrlines} = $lines;
}

sub size()   { length $_[0]->{MMBS_scalar} }
sub string() { $_[0]->{MMBS_scalar} }

sub lines()
{	my @lines = split /^/, shift->{MMBS_scalar};
	wantarray ? @lines : \@lines;
}

sub file() { Mail::Box::FastScalar->new(\shift->{MMBS_scalar}) }

sub print(;$)
{	my $self = shift;
	my $fh   = shift || select;
	$fh->print($self->{MMBS_scalar});
	$self;
}

sub read($$;$@)
{	my ($self, $parser, $head, $bodytype) = splice @_, 0, 4;
	delete $self->{MMBS_nrlines};

	(my $begin, my $end, $self->{MMBS_scalar}) = $parser->bodyAsString(@_);
	$self->fileLocation($begin, $end);

	$self;
}

sub endsOnNewline() { $_[0]->{MMBS_scalar} =~ m/\A\z|\n\z/ }

1;
