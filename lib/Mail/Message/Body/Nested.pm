#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Body::Nested;
use parent 'Mail::Message::Body';

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw/__x error/ ];

use Mail::Message::Body::Lines ();
use Mail::Message::Part        ();

#--------------------
=chapter NAME

Mail::Message::Body::Nested - body of a message which contains a message

=chapter SYNOPSIS

  See Mail::Message::Body

  if($body->isNested) {
     my $nest = $body->nested;
     $nest->delete;
  }

=chapter DESCRIPTION

The body (content) of a message can be stored in various ways.  In this
manual-page you find the description of extra functionality you have
when a message contains a nested message, like C<message/rfc822>.

A nested message is different from a multipart message which contains
only one element, because a nested message has a full set of message
header fields defined by the RFC882, where a part of a multipart has
only a few.  But because we do not keep track whether all fields are
presented, a C<Mail::Message::Part> is used anyway.

B<WARNING:> Since 2023, at least outlook started to interpret RFC6533
incorrectly.  Bodies of type 'message/rfc822' can only be 'nested', but
when they (illegally) have Content-Transfer-Encoding, they can now behave
like normal message parts (the same as a pdf or image).

=chapter METHODS

=c_method new %options

=default mime_type C<'message/rfc822'>

=option  nested $message
=default nested undef
The $message which is encapsulated within this body.

=examples

  my $msg   = $folder->message(3);
  my $encaps= Mail::Message::Body::Nested->new(nested => $msg);

  # The body will be coerced into a message, which lacks a few
  # lines but we do not bother.
  my $intro = Mail::Message::Body->new(data => ...);
  my $body  = Mail::Message::Body::Nested->new(nested  => $intro);

=error data not convertible to a message (type is $class)
=cut

sub init($)
{	my ($self, $args) = @_;
	$args->{mime_type} ||= 'message/rfc822';

	$self->SUPER::init($args);

	my $nested;
	if(my $raw = $args->{nested})
	{	$nested = Mail::Message::Part->coerce($raw, $self)
			or error __x"data not convertible to a message (type is {class})", class => ref $raw;
	}

	$self->{MMBN_nested} = $nested;
	$self;
}

sub clone()
{	my $self     = shift;
	(ref $self)->new(based_on => $self, nested => $self->nested->clone);
}

sub isNested() { 1 }
sub isBinary() { $_[0]->nested->body->isBinary }
sub nrLines()  { $_[0]->nested->nrLines }
sub size()     { $_[0]->nested->size }

sub string()   { my $nested = $_[0]->nested; defined $nested ? $nested->string : '' }
sub lines()    { my $nested = $_[0]->nested; defined $nested ? $nested->lines  : () }
sub file()     { my $nested = $_[0]->nested; defined $nested ? $nested->file   : undef }
sub print(;$)  { my $self = shift; $self->nested->print(shift || select) }
sub endsOnNewline() { $_[0]->nested->body->endsOnNewline }

sub partNumberOf($)
{	my ($self, $part) = @_;
	$self->message->partNumber || '1';
}

=method foreachLine(CODE)
It is NOT possible to call some code for each line of a nested
because that would damage the header of the encapsulated message

=error you cannot use foreachLine on a nested.
M<foreachLine()> should be used on decoded message bodies only, because
it would modify the header of the encapsulated message. which is
clearly not acceptable.

=cut

sub foreachLine($)
{	my ($self, $code) = @_;
	error __x"you cannot use foreachLine on a nested.";
}

sub check() { $_[0]->forNested( sub { $_[1]->check } ) }

sub encode(@)
{	my ($self, %args) = @_;
	$self->forNested( sub { $_[1]->encode(%args) } );
}

sub encoded() { $_[0]->forNested( sub { $_[1]->encoded } ) }

sub read($$$$)
{	my ($self, $parser, $head, $bodytype) = @_;

	my $nest = Mail::Message::Part->new(container => undef);
	$nest->readFromParser($parser, $bodytype) or return;
	$nest->container($self);

	$self->{MMBN_nested} = $nest;
	$self;
}

sub fileLocation()
{	my $nested   = $_[0]->nested;
	( ($nested->head->fileLocation)[0], ($nested->body->fileLocation)[1] );
}

sub moveLocation($)
{	my ($self, $dest) = @_;
	$dest or return $self;  # no move

	my $nested = $self->nested;
	$nested->head->moveLocation($dest);
	$nested->body->moveLocation($dest);
	$self;
}

#--------------------
=section Access to the payload

=method nested
Returns the Mail::Message::Part message which is enclosed within
this body.
=cut

sub nested() { $_[0]->{MMBN_nested} }

=method forNested CODE
Execute the CODE for the nested message.  This returns a new
nested body object.  Returns undef when the CODE returns undef.
=cut

sub forNested($)
{	my ($self, $code) = @_;
	my $nested    = $self->nested;
	my $body      = $nested->body;

	my $new_body  = $code->($self, $body) or return;
	$new_body != $body or return $self;

	my $new_nested  = Mail::Message::Part->new(head => $nested->head->clone, container => undef);
	$new_nested->body($new_body);

	my $created = (ref $self)->new(based_on => $self, nested => $new_nested);
	$new_nested->container($created);

	$created;
}

sub toplevel() { my $msg = $_[0]->message; $msg ? $msg->toplevel : undef}

1;
