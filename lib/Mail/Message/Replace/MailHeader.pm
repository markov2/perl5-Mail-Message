#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Replace::MailHeader;
use parent 'Mail::Message::Head::Complete';

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw/__x error panic/ ];

#--------------------
=chapter NAME

Mail::Message::Replace::MailHeader - fake Mail::Header

=chapter SYNOPSIS

  # change
  use Mail::Internet;
  use Mail::Header;
  # into
  use Mail::Message::Replace::MailInternet;
  # in existing code, and the code should still work, but
  # with the Mail::Message features.

=chapter DESCRIPTION

This module is a wrapper around a Mail::Message::Head::Complete,
which simulates a L<Mail::Header> object.  The name-space of that module
is hijacked and many methods are added.

Most methods will work without any change, but you should test your
software again.  Small changes have been made to M<fold_length()>,
M<header_hashref()>.

=chapter OVERLOADED

=chapter METHODS

=c_method new [$arg], %options
The $arg is an array with header lines.

=option  Modify BOOLEAN
=default Modify false
Reformat all header lines when they come in: change the folding.

=option  MailFrom 'IGNORE'|'ERROR'|'COERCE'|'KEEP'
=default MailFrom C<'KEEP'>
How to handle the C<From > lines.  See M<mail_from()>.

=option  FoldLength $octets
=default FoldLength 79
=cut

sub new(@)
{	my $class = shift;
	unshift @_, 'raw_data' if @_ % 2;
	$class->SUPER::new(@_);
}

sub init($)
{	my ($self, $args) = @_;
	$self->SUPER::init($args);

	$self->modify($args->{Modify} || $args->{Reformat} || 0);
	$self->fold_length($args->{FoldLength} || 79);
	$self->mail_from($args->{MailFrom} || 'KEEP');
	$self;
}

#--------------------
=section Access to the header

=method delete $tag, [$index]
Delete the fields with the specified $tag.  The deleted fields are
returned.  If no index is given, then all are removed.

=cut

sub delete($;$)
{	my ($self, $tag) = (shift, shift);
	@_ or return $self->delete($tag);

	my $index   = shift;
	my @fields  = $self->get($tag);
	my ($field) = splice @fields, $index, 1;
	$self->reset($tag, @fields);
	$field;
}

=method add $line, [$index]
Add a header line, which simply calls C<Mail::Message::Head::add()> on
the header for the specified $line.  The $index is ignored, the unfolded
body of the field is returned.
=cut

sub add($$)
{	my $self  = shift;
	my $field = $self->add(shift);
	$field->unfoldedBody;
}

=method replace $tag, $line, [$index]
Replace the field named $tag. from place $index (by default the first) by
the $line.  When $tag is undef, it will be extracted from the $line first.
This calls M<Mail::Message::Head::Complete::reset()> on the message's head.
=cut

sub replace($$;$)
{	my ($self, $tag, $line, $index) = @_;
	$tag //= $line =~ s/^([^:]+)\:\s*// ? $1 : 'MISSING';

	my $field  = Mail::Message::Field::Fast->new($tag, $line);
	my @fields = $self->get($tag);
	$fields[ $index||0 ] = $field;
	$self->reset($tag, @fields);

	$field;
}

#--------------------
=section Access to the header

=method get $name, [$index]
Get all the header fields with the specified $name.  In scalar context,
only the first fitting $name is returned.  Even when only one $name is
specified, multiple lines may be returned in list context: some fields
appear more than once in a header.
=cut

sub get($;$)
{	my $head = shift->head;
	my @ret  = map $head->get(@_), @_;

	  wantarray ? (map $_->unfoldedBody, @ret)
	: @ret      ? $ret[0]->unfoldedBody
	:    undef;
}

#--------------------
=section Simulating Mail::Header

=method modify [BOOLEAN]
Refold the headers when they are added.
=cut

sub modify(;$)
{	my $self = shift;
	@_ ? ($self->{MH_refold} = shift) : $self->{MH_refold};
}

=method mail_from ['IGNORE'|'ERROR'|'COERCE'|'KEEP']
What to do when a header line in the form `From ' is encountered. Valid
values are P<IGNORE> - ignore and discard the header, P<ERROR> - invoke
an error (die), P<COERCE> - rename them as Mail-From and P<KEEP>
- keep them.

=error bad Mail-From choice: '$pick'.
=cut

sub mail_from(;$)
{	my $self = shift;
	@_ or return $self->{MH_mail_from};

	my $choice = uc(shift);
	$choice =~ /^(IGNORE|ERROR|COERCE|KEEP)$/
		or error __x"bad Mail-From choice: '{pick}'.", pick => $choice;

	$self->{MH_mail_from} = $choice;
}

=method fold [$length]
Refold all fields in the header, to $length or whatever M<fold_length()>
returns.
=cut

sub fold(;$)
{	my $self = shift;
	my $wrap = @_ ? shift : $self->fold_length;
	$_->setWrapLength($wrap) for $self->orderedFields;
	$self;
}

=method unfold [$tag]
Remove the folding for all instances of $tag, or all fields at once.
=cut

sub unfold(;$)
{	my $self = shift;
	my @fields = @_ ? $self->get(shift) : $self->orderedFields;
	$_->setWrapLength(100_000) for @fields;  # blunt approach
	$self;
}

=method extract \@lines
Extract (and remove) header fields from the array.
=cut

sub extract($)
{	my ($self, $lines) = @_;

	my $parser = Mail::Box::Parser::Perl->new(filename => 'extract from array', data => $lines, trusted => 1);
	$self->read($parser);
	$parser->close;

	# Remove header from array
	shift @$lines while @$lines && $lines->[0] != m/^[\r\n]+/;
	shift @$lines if @$lines;
	$self;
}

=method read $file
Read the header from the $file.
=cut

sub read($)
{	my ($self, $file) = @_;
	my $parser = Mail::Box::Parser::Perl->new(filename => ('from file-handle '.ref $file), file => $file, trusted => 1);
	$self->read($parser);
	$parser->close;
	$self;
}

=method empty
Clean-out the whole hash. Better not use this (simply create another
header object), although it should work.
=cut

sub empty() { $_[0]->removeFields( m/^/ ) }

=method header [ARRAY]
Extract the fields from the ARRAY, if specified, and then fold the fields.
Returned is an array with all fields, produced via M<orderedFields()>.
=cut

sub header(;$)
{	my $self = shift;
	$self->extract(shift) if @_;
	$self->fold if $self->modify;
	[ $self->orderedFields ];
}

=method header_hashref HASH
If you are using this method, you must be stupid... anyway: I do not want to
support it for now: use M<add()> and friends.
=cut

sub header_hashref($) { panic "Don't use header_hashref!!!" }

=method combine $tag, [$with]
I do not see any valid reason for this command, so did not implement it.
=cut

sub combine($;$) { panic "Don't use combine()!!!" }

=method exists
Returns whether there are any fields.
=cut

sub exists() { $_[0]->count }

=method as_string
Returns the whole header as one big scalar.
Calls M<Mail::Message::Head::Complete::string()>.
=cut

sub as_string() { $_[0]->string }

=method fold_length [[$tag], $length]
Returns the line wrap, optionally after setting it to $length.  The
old value is returned.  The $tag argument is ignored, because it is
silly to have different lines fold in different ways.  This method
cannot be called statically anymore.
=cut

sub fold_length(;$$)
{	my $self = shift;
	@_ or return $self->{MH_wrap};

	my $old  = $self->{MH_wrap};
	my $wrap = $self->{MH_wrap} = shift;
	$self->fold($wrap) if $self->modify;
	$old;
}

=method tags
Returns all the names of fields, implemented by
M<Mail::Message::Head::Complete::names()>.
=cut

sub tags() { $_[0]->names }

=method dup
Duplicate the header, which is simply M<clone()>.
=cut

sub dup() { $_[0]->clone }

=method cleanup
Cleanup memory usage.  Not needed here.
=cut

sub cleanup() { $_[0] }

#--------------------
=section The nasty bits

=cut

BEGIN
{	no warnings;
	*Mail::Header::new = sub {
		my $class = shift;
		Mail::Message::Replace::MailHeader->new(@_);
	};
}


=ci_method isa $class
Of course, the C<isa()> class inheritance check should not see our
nasty trick.
=cut

sub isa($)
{	my ($thing, $class) = @_;
	$class eq 'Mail::Mailer' ? 1 : $thing->SUPER::isa($class);
}


1;
