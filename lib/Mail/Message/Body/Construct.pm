#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Body;
# Mail::Message::Body::Construct adds functionality to Mail::Message::Body

use strict;
use warnings;

use Log::Report   'mail-message';

use Scalar::Util  qw/blessed/;

use Mail::Message::Body::String ();
use Mail::Message::Body::Lines  ();

#--------------------
=chapter NAME

Mail::Message::Body::Construct - adds functionality to Mail::Message::Body

=chapter SYNOPSIS

=chapter DESCRIPTION

This package adds complex functionality to the Mail::Message::Body
class.  This functions less often used, so many programs will not
compile this package.

=chapter METHODS

=section Constructing a body

=method foreachLine CODE

Create a new body by performing an action on each of its lines.  If none
of the lines change, the current body will be returned, otherwise a new
body is created of the same type as the current.

The CODE refers to a subroutine which is called, where C<$_> contains
body's original line.  DO NOT CHANGE C<$_>!!!  The result of the routine
is taken as new line.  When the routine returns undef, the line will be
skipped.

=examples

  my $content  = $msg->decoded;
  my $reply    = $content->foreachLine( sub { '> '.$_ } );
  my $rev      = $content->foreachLine( sub { reverse } );

  sub filled() { length $_ > 1 ? $_ : undef }
  my $nonempty = $content->foreachLine( \&filled );

  my $WRONG    = $content->foreachLine( sub { s/a/A/ } );
  my $right    = $content->foreachLine( sub { s/a/A/r });

=cut

sub foreachLine($)
{	my ($self, $code) = @_;
	my $changes = 0;
	my @result;

	foreach ($self->lines)
	{	my $becomes = $code->();
		if(defined $becomes)
		{	push @result, $becomes;
			$changes++ if $becomes ne $_;
		}
		else { $changes++ }
	}

	$changes ? (ref $self)->new(based_on => $self, data => \@result) : $self;
}

=method concatenate @components
Concatenate the textual content of a LIST of elements into one new body.
The resulting body object is based on the callee, which may itself not
be included in the result.

Specify a list of text @components.  Each component can be
=over 4
=item * a message (Mail::Message, the body of the message is used),
=item * a plain body (Mail::Message::Body),
=item * undef (which will be skipped),
=item * a scalar (which is split into lines), or
=item * an array of scalars (each providing one line).
=back

=examples
  # all arguments are Mail::Message::Body's.
  my $sum = $body->concatenate($preamble, $body, $epilogue, "-- \n" , $sig);

=error cannot concatenate element $which
=cut

sub concatenate(@)
{	my $self = shift;
	return $self if @_==1;

	my @unified;
	foreach (grep defined, @_)
	{	push @unified,
			  ! ref $_          ? $_
			: ref $_ eq 'ARRAY' ? @$_
			: $_->isa('Mail::Message')       ? $_->body->decoded
			: $_->isa('Mail::Message::Body') ? $_->decoded
			: 	error(__x"cannot concatenate element {which}", which => $_);
	}

	(ref $self)->new(
		based_on  => $self,
		mime_type => 'text/plain',
		data      => join('', @unified),
	);
}

=method attach @messages, %options
Make a multipart containing this body and the specified @messages. The
options are passed to the constructor of the multi-part body.  If you
need more control, create the multi-part body yourself.  At least
take a look at Mail::Message::Body::Multipart.

The message-parts will be coerced into a Mail::Message::Part, so you
may attach Mail::Internet or MIME::Entity objects if you want --see
M<Mail::Message::coerce()>.  A new body with attached messages is
returned.

=examples

  my $pgpkey = Mail::Message::Body::File->new(file => 'a.pgp');
  my $msg    = Mail::Message->buildFromBody($message->decoded->attach($pgpkey));

  # The last message of the $multi multiparted body becomes a coerced $entity.
  my $entity  = MIME::Entity->new;
  my $multi   = $msg->body->attach($entity);

  # Now create a new message
  my $msg     = Mail::Message->new(head => ..., body => $multi);

=cut

sub attach(@)
{	my $self  = shift;

	my @parts;
	push @parts, shift while @_ && blessed $_[0];
	@parts or return $self;

	unshift @parts, $self->isNested ? $self->nested : $self->isMultipart ? $self->parts : $self;

	@parts==1 ? $parts[0] : Mail::Message::Body::Multipart->new(parts => \@parts, @_);
}

=method stripSignature %options

Strip the signature from the body.  The body must already be decoded
otherwise the wrong lines may get stripped.  Returned is the stripped
version body, and in list context also the signature, encapsulated in
its own body object.  The signature separator is the first line of the
returned signature body.

The signature is added by the sender to tell about him- or herself.
It is superfluous in some situations, for instance if you want to create
a reply to the person's message you do not need to include that signature.

If the body had no signature, the original body object is returned,
and undef for the signature body.

=option  result_type CLASS
=default result_type <same as current>
The type of body to be created for the stripped body (and maybe also to
contain the stripped signature)

=option  pattern REGEX|STRING|CODE
=default pattern C<qr/^--\s?$/>
Which pattern defines the line which indicates the separator between
the message and the signature.  In case of a STRING, this is matched
to the beginning of the line, and REGEX is a full regular expression.

In case of CODE, each line (from last to front) is passed to the
specified subroutine as first argument.  The subroutine must return
TRUE when the separator is found.

=option  max_lines INTEGER|undef
=default max_lines C<10>
The maximum number of lines which can be the length of a signature.
Specify undef to remove the limit.

=examples

  my $start = $message->decoded;
  my $start = $body->decoded;

  my $stripped = $start->stripSignature;

  my ($stripped, $sign) = $start->stripSignature
      (max_lines => 5, pattern => '-*-*-');

=cut

# tests in t/51stripsig.t

sub stripSignature($@)
{	my ($self, %args) = @_;

	return $self if $self->mimeType->isBinary;

	my $p       = $args{pattern};
	my $pattern = ! defined $p ? qr/^--\s?$/
				: ! ref $p     ? qr/^\Q$p/
				:    $p;

	my $lines   = $self->lines;   # no copy!
	my $stop    = defined $args{max_lines} ? @$lines - $args{max_lines}
				: exists $args{max_lines}  ? 0
				:    @$lines-10;

	$stop = 0 if $stop < 0;
	my ($sigstart, $found);

	if(ref $pattern eq 'CODE')
	{	for($sigstart = $#$lines; $sigstart >= $stop; $sigstart--)
		{	$pattern->($lines->[$sigstart]) or next;
			$found = 1;
			last;
		}
	}
	else
	{	for($sigstart = $#$lines; $sigstart >= $stop; $sigstart--)
		{	$lines->[$sigstart] =~ $pattern or next;
			$found = 1;
			last;
		}
	}

	$found or return $self;

	my $bodytype = $args{result_type} || ref $self;
	my $stripped = $bodytype->new(based_on => $self, data => [ @$lines[0..$sigstart-1] ]);

	wantarray or return $stripped;

	my $sig      = $bodytype->new(based_on => $self, data => [ @$lines[$sigstart..$#$lines] ]);
	($stripped, $sig);
}

1;
