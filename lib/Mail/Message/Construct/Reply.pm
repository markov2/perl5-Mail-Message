#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message;

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw/__x error info trace/ ];

use Mail::Message::Body::Multipart ();
use Mail::Address  ();

use Scalar::Util   qw/blessed/;

#--------------------
=chapter NAME

Mail::Message::Construct::Reply - reply to a Mail::Message

=chapter SYNOPSIS

  my Mail::Message $reply = $message->reply;
  my $quoted  = $message->replyPrelude($head->get('From'));

=chapter DESCRIPTION

Complex functionality on Mail::Message objects is implemented in
different files which are autoloaded.  This file implements the
functionality related to creating message replies.

=chapter METHODS

=section Constructing a message

=method reply %options

Start a reply to this message. Some of the header-lines of the original
message will be taken. A message-id will be assigned. Some header lines
will be updated to facilitate message-thread detection
(see Mail::Box::Thread::Manager).

You may reply to a whole message or a message part.  You may wish to
overrule some of the default header settings for the reply immediately,
or you may do that later with C<set> on the header.

Addresses may be specified as string, or a Mail::Address object, or as
array of Mail::Address objects.

All %options which are not listed below AND start with a capital, will
be added as additional headers to the reply message.

=option  body $body
=default body undef
Usually, the reply method can create a nice, sufficient message from the
source message's body.  In case you like more complicated reformatting,
you may also create a body yourself first, and pass this on to this
C<reply> method. Some of the other options to this method will be ignored
in this case.

=option  group_reply BOOLEAN
=default group_reply true
Will the people listed in the P<Cc> headers (those who received the
message where you reply to now) also receive this message as carbon
copy?

=option  include 'NO'|'INLINE'|'ATTACH'
=default include C<'INLINE'>
Must the message where this is a reply to be included in the message?
If C<NO> then not.  With C<INLINE> a reply body is composed. C<ATTACH>
will create a multi-part body, where the original message is added
after the specified body.  It is only possible to inline textual
messages, therefore binary or multipart messages will always be
enclosed as attachment.

=option  message_type CLASS
=default message_type Mail::Message
Create a message with the requested type.  By default, it will be a
Mail::Message.  This is correct, because it will be coerced into
the correct folder message type when it is added to that folder.

=option  max_signature INTEGER
=default max_signature C<10>
Passed to C<stripSignature> on the body as parameter C<max_lines>.  Only
effective for single-part messages.

=option  prelude $body|\@lines
=default prelude undef
The @lines which will be added before the quoted reply lines.  If nothing
is specified, the result of the M<replyPrelude()> method
is taken.  When undef is specified, no prelude will be added.

=option  postlude $body|\@lines
=default postlude undef
The @lines which to be added after the quoted reply lines.  Create a
body for it first.  This should not include the signature, which has its
own option.  The signature will be added after the postlude when the
reply is INLINEd.

=option  quote CODE|STRING
=default quote 'E<gt> '
Mangle the lines of an C<INLINE>d reply with CODE, or by prepending a
STRING to each line.  The routine specified by CODE is called when the
line is in C<$_>.

By default, C<'E<gt> '> is added before each line.  Specify undef to
disable quoting.  This option is processed after the body has been decoded.

=option  signature $body|$message
=default signature undef
The signature to be added in case of a multi-part reply.  The mime-type
of the signature body should indicate this is a used as such.  However,
in INLINE mode, the body will be taken, a line containing C<'-- '> added
before it, and added behind the epilogue.

=option  strip_signature REGEXP|STRING|CODE
=default strip_signature C<qr/^--\s/>
Remove the signature of the sender.  The value of this parameter is
passed to M<Mail::Message::Body::stripSignature(pattern)> unless the
source text is not included.  The signature is stripped from the message
before quoting.

When a multipart body is encountered, and the message is included to
ATTACH, the parts which look like signatures will be removed.  If only
one message remains, it will be the added as single attachment, otherwise
a nested multipart will be the result.  The value of this option does not
matter, as long as it is present.  See Mail::Message::Body::Multipart.

=option  To $body|$address|\@addresses
=default To <sender in current>
The destination of your message.  By default taken from the C<Reply-To>
field in the source message.  If that field is not present as well, the
P<From> line is scanned.  If they all fail, undef is returned by this
method: no reply message produced.

=option  From $body|$address|\@addresses
=default From <'to' in current>
Your identification, by default taken from the P<To> field of the
source message.

=option  Bcc $body|$address|\@addresses
=default Bcc undef
Receivers of blind carbon copies: their names will not be published to
other message receivers.

=option  Cc $body|$address|\@addresses
=default Cc <'cc' in current>
The carbon-copy receivers, by default a copy of the P<Cc> field of
the source message.

=option  Message-ID STRING
=default Message-ID <uniquely generated>
Supply a STRING as specific message-id for the reply.  By default, one is
generated for you.  If there are no angles around your id, they will be
added.

=option  Subject STRING|CODE
=default Subject M<replySubject()>
Force the subject line to the specific STRING, or the result of the
subroutine specified by CODE.  The subroutine will be called passing
the subject of the original message as only argument.  By default,
M<Mail::Message::replySubject()> is used.

=examples
  my $reply = $msg->reply(
    prelude         => "No spam, please!\n\n",
    postlude        => "\nGreetings\n",
    strip_signature => 1,
    signature       => $my_pgp_key,
    group_reply     => 1,
    'X-Extra'       => 'additional header',
  );

=error cannot include reply source as $kind.
Unknown alternative for the P<include> option of M<reply()>.  Valid
choices are C<NO>, C<INLINE>, and C<ATTACH>.
=cut

# tests in t/55reply1r.t, demo in the examples/ directory

sub reply(@)
{	my ($self, %args) = @_;

	my $body   = $args{body};
	my $strip  = !exists $args{strip_signature} || $args{strip_signature};
	my $include  = $args{include}   || 'INLINE';

	if($include eq 'NO')
	{	# Throw away real body.
		$body //= Mail::Message::Body->new(data => ["\n[The original message is not included]\n\n"]);
	}
	elsif($include eq 'INLINE' || $include eq 'ATTACH')
	{
		unless(defined $body)
		{	# text attachment
			$body = $self->body;
			$body = $body->part(0)->body if $body->isMultipart && $body->parts==1;
			$body = $body->nested->body  if $body->isNested;

			$body
			  = $strip && ! $body->isMultipart && !$body->isBinary
			  ? $body->decoded->stripSignature(pattern => $args{strip_signature}, max_lines => $args{max_signature})
			  : $body->decoded;
		}

		if($include eq 'INLINE' && $body->isMultipart) { $include = 'ATTACH' }
		elsif($include eq 'INLINE' && $body->isBinary)
		{	$include = 'ATTACH';
			$body    = Mail::Message::Body::Multipart->new(parts => [$body]);
		}

		if($include eq 'INLINE')
		{	my $quote = defined $args{quote} ? $args{quote} : exists $args{quote} ? undef : '> ';
			if(defined $quote)
			{	my $quoting = ref $quote ? $quote : sub { $quote . $_ };
				$body = $body->foreachLine($quoting);
			}
		}
	}
	else
	{	error __x"cannot include reply source as {kind}.", kind => $include;
	}

	#
	# Collect header info
	#

	my $mainhead = $self->toplevel->head;

	# Where it comes from
	my $from = delete $args{From};
	unless(defined $from)
	{	my @from = $self->to;
		$from    = \@from if @from;
	}

	# To whom to send
	my $to = delete $args{To} || $mainhead->get('reply-to') || $mainhead->get('from');
	defined $to or return;

	# Add Cc
	my $cc = delete $args{Cc};
	if(!defined $cc && $args{group_reply})
	{	my @cc = $self->cc;
		$cc    = [ $self->cc ] if @cc;
	}

	# Create a subject
	my $srcsub  = delete $args{Subject};
	my $subject
	  = ! defined $srcsub ? $self->replySubject($self->subject)
	  : ref $srcsub       ? $srcsub->($self->subject)
	  :    $srcsub;

	# Create a nice message-id
	my $msgid   = delete $args{'Message-ID'};
	$msgid      = "<$msgid>" if $msgid && $msgid !~ /^\s*\<.*\>\s*$/;

	# Thread information
	my $origid  = '<'.$self->messageId.'>';
	my $refs    = $mainhead->get('references');

	# Prelude
	my $prelude
	  = defined $args{prelude} ? $args{prelude}
	  : exists  $args{prelude} ? undef
	  :    [ $self->replyPrelude($to) ];

	$prelude     = Mail::Message::Body->new(data => $prelude)
		if defined $prelude && ! blessed $prelude;

	my $postlude = $args{postlude};
	$postlude    = Mail::Message::Body->new(data => $postlude)
		if defined $postlude && ! blessed $postlude;

	#
	# Create the message.
	#

	my $total;
	if($include eq 'NO') {$total = $body}
	elsif($include eq 'INLINE')
	{	my $signature = $args{signature};
		$signature    = $signature->body
			if defined $signature && $signature->isa('Mail::Message');

		$total = $body->concatenate($prelude, $body, $postlude, (defined $signature ? "-- \n$signature" : undef));
	}
	elsif($include eq 'ATTACH')
	{	my $intro = $prelude->concatenate($prelude, ["\n", "[Your message is attached]\n"], $postlude);
		$total = Mail::Message::Body::Multipart->new(parts => [ $intro, $body, $args{signature} ]);
	}

	my $msgtype = $args{message_type} || 'Mail::Message';
	my $reply   = $msgtype->buildFromBody(
		$total,
		From    => $from || 'Undisclosed senders:;',
		To      => $to,
		Subject => $subject,
		'In-Reply-To' => $origid,
		References    => ($refs ? "$refs $origid" : $origid),
	);

	my $newhead = $reply->head;
	$newhead->set(Cc  => $cc)  if $cc;
	$newhead->set(Bcc => delete $args{Bcc}) if $args{Bcc};
	$newhead->add($_ => $args{$_})
		for sort grep /^[A-Z]/, keys %args;

	# Ready
	trace "Reply created from $origid";
	$self->label(replied => 1);
	$reply;
}

=ci_method replySubject STRING

Create a subject for a message which is a reply for this one.  This routine
tries to count the level of reply in subject field, and transform it into
a standard form.  Please contribute improvements.

=examples

  subject                 --> Re: subject
  Re: subject             --> Re[2]: subject
  Re[X]: subject          --> Re[X+1]: subject
  subject (Re)            --> Re[2]: subject
  subject (Forw)          --> Re[2]: subject
  <blank>                 --> Re: your mail

=cut

# tests in t/35reply1rs.t

sub replySubject($)
{	my ($thing, $subject) = @_;
	$subject     = 'your mail' unless defined $subject && length $subject;
	my @subject  = split /\:/, $subject;
	my $re_count = 1;

	# Strip multiple Re's from the start.

	while(@subject)
	{	last if $subject[0] =~ /[A-QS-Za-qs-z][A-DF-Za-df-z]/;

		for(shift @subject)
		{	while( /\bRe(?:\[\s*(\d+)\s*\]|\b)/g )
			{	$re_count += ($1 // 1);
			}
		}
	}

	# Strip multiple Re's from the end.

	if(@subject)
	{	for($subject[-1])
		{	$re_count++ while s/\s*\(\s*(re|forw)\W*\)\s*$//i;
		}
	}

	# Create the new subject string.

	my $text = (join ':', @subject) || 'your mail';
	s/^\s+//, s/\s+$// for $text;

	$re_count==1 ? "Re: $text" : "Re[$re_count]: $text";
}


=method replyPrelude [STRING|$field|$address|\@addrs|\@fields]
Produces a LIST of lines (usually only one), which will preceed the
quoted body of the message.  STRING must comply to the RFC822 email
address specification, and is usually the content of a C<To> or C<From>
header line.  If a $field is given, the field's body must be
compliant.  Without argument --or when the argument is undef-- a
slightly different line is produced.

In case an ARRAY of @addrs or @fields is passed, the first one is taken.
This simplified situations where multiple addresses are a allowed.

=example characteristic example of the output

  On Thu Oct 13 04:54:34 1995, him@example.com wrote:

=cut

sub replyPrelude($)
{	my ($self, $who) = @_;
	$who = $who->[0] if ref $who eq 'ARRAY';

	my $user
	  = ! defined $who                    ? undef
	  : ! blessed $who                    ? (Mail::Address->parse($who))[0]
	  : $who->isa('Mail::Message::Field') ? ($who->addresses)[0]
	  :    $who;

	my $from = blessed $user && $user->isa('Mail::Address') ? ($user->name || $user->address || $user->format) : 'someone';
	my $time = gmtime $self->timestamp;
	"On $time, $from wrote:\n";
}

1;
