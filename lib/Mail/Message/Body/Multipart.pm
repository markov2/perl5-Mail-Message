#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Body::Multipart;
use parent 'Mail::Message::Body';

use strict;
use warnings;

use Log::Report   'mail-message';

use Scalar::Util   qw/blessed/;

use Mail::Message::Body::Lines ();
use Mail::Message::Part        ();
use Mail::Box::FastScalar      ();

#--------------------
=chapter NAME

Mail::Message::Body::Multipart - body of a message with attachments

=chapter SYNOPSIS

  See Mail::Message::Body

  if($body->isMultipart) {
     my @attachments = $body->parts;
     my $attachment3 = $body->part(2);
     my $before      = $body->preamble;
     my $after       = $body->epilogue;
     $body->part(1)->delete;
  }

=chapter DESCRIPTION

The body (content) of a message can be stored in various ways.  In this
manual-page you find the description of extra functionality you have
when a message contains attachments (parts).

The number of multipart alternatives is growing.  A full list is maintained
by IANA af L<https://www.iana.org/assignments/media-types/media-types.xhtml#multipart>

=over 4
=item * multipart/mixed
=item * multipart/alternative
=item * multipart/related
=item * multipart/report, RFC6522
=item * multipart/signed, RFC1847
=item * multipart/encrypted
=item * multipart/multilingual, RFC8255 (unused)
=back

=chapter METHODS

=c_method new %options

=default mime_type  C<'multipart/mixed'>

=option  boundary $separator
=default boundary undef
The $separator string to be used between parts of the message.
This separator must be unique in case the message contains nested
multiparts (which are not unusual).  If undef, a nice unique boundary
will be generated.

=option  epilogue $body|$text
=default epilogue ''
The text which is included in the main body after the final boundary.  This
is usually empty, and has no meaning.

Provide a $body object or plain $text (which will automatically translated
into a C<text/plain> body).

=option  parts [$message, $body, ...]
=default parts undef
Specifies an initial list of parts in this body.  These may be full
$message objects, or $body objects which will be transformed into messages
before use.  Each message is coerced into a Mail::Message::Part object.

MIME::Entity and Mail::Internet objects are acceptable in the
list, because they are coercible into Mail::Message::Part's.  Values
of undef will be skipped silently.

=option  preamble $body|$text
=default preamble undef
The $text which is included in the body before the first part.  It is
common use to include a text to warn the user that the message is a
multipart.  However, this was useful in earlier days: most mail
agents are very capable in warning the user themselves.

Provide a $body object or plain $text (which will automatically translated
into a C<text/plain> body).

=examples

  my $intro = Mail::Message::Body->new(data => ['part one']);
  my $pgp   = Mail::Message::Body->new(data => ['part three']);

  my $body  = Mail::Message::Body::Multipart->new(
    boundary => time . '--it-s-mine',
    preamble => "This is a multi-part message in MIME format.\n\n",
    parts    => [ $intro, $folder->message(3)->decoded, $pgp ],
  );

=error data not convertible to a message (type is $type)
An object which is not coercable into a Mail::Message::Part object was
passed to the initiation.
=cut

sub init($)
{	my ($self, $args) = @_;
	my $based = $args->{based_on};
	$args->{mime_type} ||= defined $based ? $based->type : 'multipart/mixed';

	$self->SUPER::init($args);

	my @parts;
	if($args->{parts})
	{	foreach my $raw (@{$args->{parts}})
		{	defined $raw or next;
			my $cooked = Mail::Message::Part->coerce($raw, $self);

			defined $cooked
				or error __x"data not convertible to a message (type is {class})", class => ref $raw;

			push @parts, $cooked;
		}
	}

	my $preamble = $args->{preamble};
	$preamble    = Mail::Message::Body->new(data => $preamble)
		if defined $preamble && ! blessed $preamble;

	my $epilogue = $args->{epilogue};
	$epilogue    = Mail::Message::Body->new(data => $epilogue)
		if defined $epilogue && ! blessed $epilogue;

	if($based)
	{	$self->boundary($args->{boundary} || $based->boundary);
		$self->{MMBM_preamble} = $preamble // $based->preamble;

		$self->{MMBM_parts}
		  = @parts ? \@parts
		  : !$args->{parts} && $based->isMultipart ? [ $based->parts('ACTIVE') ]
		  :    [];

		$self->{MMBM_epilogue} = $epilogue // $based->epilogue;
	}
	else
	{	$self->boundary($args->{boundary} ||$self->type->attribute('boundary'));
		$self->{MMBM_preamble} = $preamble;
		$self->{MMBM_parts}    = \@parts;
		$self->{MMBM_epilogue} = $epilogue;
	}

	$self;
}

sub isMultipart() { 1 }
sub isBinary()    { 0 }   # A multipart body is never binary itself.  The parts may be.

sub clone()
{	my $self     = shift;
	my $preamble = $self->preamble;
	my $epilogue = $self->epilogue;

	my $body     = (ref $self)->new(
		based_on => $self,
		preamble => ($preamble ? $preamble->clone : undef),
		epilogue => ($epilogue ? $epilogue->clone : undef),
		parts    => [ map $_->clone, $self->parts('ACTIVE') ],
	);

}

sub nrLines()
{	my $self = shift;
	my $nr   = 1;  # trailing part-sep

	if(my $preamble = $self->preamble)
	{	$nr += $preamble->nrLines;
		$nr++ if $preamble->endsOnNewline;
	}

	foreach my $part ($self->parts('ACTIVE'))
	{	$nr += 1 + $part->nrLines;
		$nr++ if $part->body->endsOnNewline;
	}

	if(my $epilogue = $self->epilogue)
	{	# nrLines should match mbox counts, which is a bit
		# unclear w.r.t. the \n after a multipart separator
		# line.
		$nr += $epilogue->nrLines -1;
	}

	$nr;
}

sub size()
{	my $self   = shift;
	my $bbytes = length($self->boundary) +4;  # \n--$b\n

	my $bytes  = $bbytes +2;   # last boundary, \n--$b--\n
	if(my $preamble = $self->preamble)
	     { $bytes += $preamble->size }
	else { $bytes -= 1 }      # no leading \n

	$bytes += $bbytes + $_->size foreach $self->parts('ACTIVE');
	if(my $epilogue = $self->epilogue)
	{	$bytes += $epilogue->size;
	}
	$bytes;
}

sub string() { join '', $_[0]->lines }

sub lines()
{	my $self     = shift;
	my $boundary = $self->boundary;
	my $preamble = $self->preamble;

	my @lines;
	push @lines, $preamble->lines if $preamble;

	foreach my $part ($self->parts('ACTIVE'))
	{	# boundaries start with \n
		if(!@lines) { ; }
		elsif($lines[-1] =~ m/\n$/) { push @lines, "\n" }
		else { $lines[-1] .= "\n" }
		push @lines, "--$boundary\n", $part->lines;
	}

	if(!@lines) { ; }
	elsif($lines[-1] =~ m/\n$/) { push @lines, "\n" }
	else { $lines[-1] .= "\n" }
	push @lines, "--$boundary--";

	if(my $epilogue = $self->epilogue)
	{	$lines[-1] .= "\n";
		push @lines, $epilogue->lines;
	}

	wantarray ? @lines : \@lines;
}

sub file()                    # It may be possible to speed-improve the next code, which first
{	my $self   = shift;       # produces a full print of the message in memory...
	my $dump   = Mail::Box::FastScalar->new;
	$self->print($dump);
	$dump->seek(0,0);
	$dump;
}

sub print(;$)
{	my $self = shift;
	my $out  = shift || select;

	my $boundary = $self->boundary;
	my $count    = 0;
	if(my $preamble = $self->preamble)
	{	$preamble->print($out);
		$count++;
	}

	foreach my $part ($self->parts('ACTIVE'))
	{	$out->print("\n") if $count++;
		$out->print("--$boundary\n");
		$part->print($out);
	}
	$out->print("\n") if $count++;
	$out->print("--$boundary--");

	if(my $epilogue = $self->epilogue)
	{	$out->print("\n");
		$epilogue->print($out);
	}

	$self;
}

sub endsOnNewline()
{	my $self = shift;
	my $epilogue = $self->epilogue or return 1;
	$epilogue =~ m/[\r\n]$/;
}

=method foreachLine(CODE)
It is NOT possible to call some code for each line of a multipart,
because that would not only inflict damage to the body of each
message part, but also to the headers and the part separators.

=error You cannot use foreachLine on a multipart.
M<foreachLine()> should be used on decoded message bodies only, because
it would attempt to modify part-headers and separators as well, which is
clearly not acceptable.

=cut

sub foreachLine($)
{	my ($self, $code) = @_;
	error __x"you cannot use foreachLine on a multipart.";
}

sub check()
{	my $self = shift;
	$self->foreachComponent( sub { $_[1]->check } );
}

sub encode(@)
{	my ($self, %args) = @_;
	$self->foreachComponent( sub { $_[1]->encode(%args) } );
}

sub encoded()
{	my $self = shift;
	$self->foreachComponent( sub { $_[1]->encoded } );
}

sub read($$$$)
{	my ($self, $parser, $head, $bodytype) = @_;
	my $boundary   = $self->boundary;

	$parser->pushSeparator("--$boundary");

	my $te;
	$te = lc $1 if +($head->get('Content-Transfer-Encoding') || '') =~ m/(\w+)/;

	my @sloppyopts = (mime_type => 'text/plain', transfer_encoding => $te);

	# Get preamble.
	my $headtype = ref $head;
	my $begin    = $parser->filePosition;
	my $preamble = Mail::Message::Body::Lines->new(@sloppyopts)->read($parser, $head);

	$preamble->nrLines or undef $preamble;
	$self->{MMBM_preamble} = $preamble if defined $preamble;

	# Get the parts.

	my ($has_epilogue, @parts);
	while(my $sep = $parser->readSeparator)
	{	if($sep =~ m/^--\Q$boundary\E--[ \t]*\n?/)
		{	# Per RFC 2046, a CRLF after the close-delimiter marks the presence
			# of an epilogue.  Preserve the epilogue, even if empty, so that the
			# printed multipart body will also have the CRLF.
			# This, however, is complicated w.r.t. mbox folders.
			$has_epilogue = $sep =~ /\n/;
			last;
		}

		my $part = Mail::Message::Part->new(container => $self);
		$part->readFromParser($parser, $bodytype)
			or last;

		push @parts, $part if $part->head->names || $part->body->size;
	}
	$self->{MMBM_parts} = \@parts;

	# Get epilogue

	$parser->popSeparator;
	my $epilogue = Mail::Message::Body::Lines->new(@sloppyopts)
		->read($parser, $head);

	my $end
	  = defined $epilogue ? ($epilogue->fileLocation)[1]
	  : @parts            ? ($parts[-1]->body->fileLocation)[1]
	  : defined $preamble ? ($preamble->fileLocation)[1]
	  :    $begin;

	$self->fileLocation($begin, $end);

	$has_epilogue || $epilogue->nrLines
		or undef $epilogue;

	$self->{MMBM_epilogue} = $epilogue
		if defined $epilogue;

	$self;
}

#--------------------
=section Constructing a body

=method foreachComponent CODE
Execute the CODE for each component of the message: the preamble, the
epilogue, and each of the parts.

Each component is a body and is passed as second argument to the CODE.
The first argument is a reference to this multi-parted body.  The CODE
returns a body object.  When any of the returned bodies differs from
the body which was passed, then a new multi-part body will be returned.
Reference to the not-changed bodies and the changed bodies will be
included in that new multi-part.

=examples
  my $checked = $multi->foreachComponent(sub {$_[1]->check});

=cut

sub foreachComponent($)
{	my ($self, $code) = @_;
	my $changes  = 0;

	my $new_preamble;
	if(my $preamble = $self->preamble)
	{	$new_preamble = $code->($self, $preamble);
		$changes++ unless $preamble == $new_preamble;
	}

	my $new_epilogue;
	if(my $epilogue = $self->epilogue)
	{	$new_epilogue = $code->($self, $epilogue);
		$changes++ unless $epilogue == $new_epilogue;
	}

	my @new_bodies;
	foreach my $part ($self->parts('ACTIVE'))
	{	my $part_body = $part->body;
		my $new_body  = $code->($self, $part_body);

		$changes++ if $new_body != $part_body;
		push @new_bodies, [$part, $new_body];
	}

	$changes or return $self;

	my @new_parts;
	foreach (@new_bodies)
	{	my ($part, $body) = @$_;
		my $new_part = Mail::Message::Part->new(head => $part->head->clone, container => undef);
		$new_part->body($body);
		push @new_parts, $new_part;
	}

	my $constructed = (ref $self)->new(
		preamble => $new_preamble,
		parts    => \@new_parts,
		epilogue => $new_epilogue,
		based_on => $self,
	);

	$_->container($constructed)
		for @new_parts;

	$constructed;
}

=method attach $messages|$bodies
Attach a list of $messages to this multipart.  A new body is returned.
When you specify $bodies, they will first be translated into
real messages.  MIME::Entity and Mail::Internet objects may be
specified too.  In any case, the parts will be coerced into
Mail::Message::Part's.
=cut

sub attach(@)
{	my $self  = shift;
	(ref $self)->new(based_on => $self, parts => [ $self->parts, @_ ]);
}

=method stripSignature %options
Removes all parts which contains data usually defined as being signature.
The MIME::Type module provides this knowledge.  A new multipart is
returned, containing the remaining parts.  No %options are defined yet,
although some may be specified, because this method overrules the
C<stripSignature> method for normal bodies.
=cut

sub stripSignature(@)
{	my $self  = shift;

	my @allparts = $self->parts;
	my @parts    = grep ! $_->body->mimeType->isSignature, @allparts;

	@allparts == @parts ? $self : (ref $self)->new(based_on => $self, parts => \@parts);
}

#--------------------
=section Access to the payload

=method preamble
Returns the preamble; the text before the first message part (before the
first real attachment).
The preamble is stored in a BODY object, and its encoding is taken
from the multipart header.
=cut

sub preamble() { $_[0]->{MMBM_preamble} }

=method epilogue
Returns the epilogue; the text after the last message part (after the
last real attachment).
The epilogue is stored in a BODY object, and its encoding is taken
from the general multipart header.
=cut

sub epilogue() { $_[0]->{MMBM_epilogue} }

=method parts [<'ALL'|'ACTIVE'|'DELETED'|'RECURSE'|$filter>]
Return all parts by default, or when ALL is specified.  P<ACTIVE> returns
the parts which are not flagged for deletion, as opposite to P<DELETED>.
P<RECURSE> descents into all nested multiparts to collect all parts.

You may also specify a code reference which is called for each nested
part.  The first argument will be the message part.  When the code
returns true, the part is incorporated in the return list.

=examples
  print "Number of attachments: ",
     scalar $message->body->parts('ACTIVE');

  foreach my $part ($message->body->parts) {
     print "Type: ", $part->get('Content-Type');
  }

=error unknown criterium $what to select parts.
Valid choices for part selections are P<ALL>, P<ACTIVE>, P<DELETED>,
P<RECURSE> or a code reference.  However, some other argument was passed.

=cut

sub parts(;$)
{	my $self  = shift;
	return @{$self->{MMBM_parts}} unless @_;

	my $what  = shift;
	my @parts = @{$self->{MMBM_parts}};

	  $what eq 'RECURSE' ? (map $_->parts('RECURSE'), @parts)
	: $what eq 'ALL'     ? @parts
	: $what eq 'DELETED' ? (grep  $_->isDeleted, @parts)
	: $what eq 'ACTIVE'  ? (grep !$_->isDeleted, @parts)
	: ref $what eq 'CODE'? (grep $what->($_), @parts)
	:    error __x"unknown criterium {what} to select parts.", what => $what;
}

=method part $index
Returns only the part with the specified $index.  You may use a negative
value here, which counts from the back in the list.  Parts which are
flagged to be deleted are included in the count.

=examples
  $message->body->part(2)->print;
  $body->part(1)->delete;

=cut

sub part($) { $_[0]->{MMBM_parts}[$_[1]] }

sub partNumberOf($)
{	my ($self, $part) = @_;
	my $msg   = $self->message or panic "multipart is not connected.";

	my $base  = $msg->isa('Mail::Message::Part') ? $msg->partNumber.'.' : '';

	my @parts = $self->parts('ACTIVE');
	foreach my $partnr (0..@parts)
	{	return $base.($partnr+1)
			if $parts[$partnr] == $part;
	}
	panic "multipart is not found or not active";
}

=method boundary [STRING]
Returns the boundary which is used to separate the parts in this
body.  If none was read from file, then one will be assigned.  With
STRING you explicitly set the boundary to be used.
=cut

sub boundary(;$)
{	my $self  = shift;
	my $mime  = $self->type;

	unless(@_)
	{	my $boundary = $mime->attribute('boundary');
		return $boundary if defined $boundary;
	}

	my $boundary = $_[0] // "boundary-".int rand(1000000);
	$self->type->attribute(boundary => $boundary);
}

sub toplevel() { my $msg = $_[0]->message; $msg ? $msg->toplevel : undef}

1;
