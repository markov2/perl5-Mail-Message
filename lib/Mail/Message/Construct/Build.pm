#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message;

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw/__x error info warning/ ];

use Mail::Message::Head::Complete  ();
use Mail::Message::Body::Lines     ();
use Mail::Message::Body::Multipart ();
use Mail::Message::Body::Nested    ();
use Mail::Message::Field           ();

use Mail::Address  ();
use Scalar::Util   qw/blessed/;

#--------------------
=chapter NAME

Mail::Message::Construct::Build - building a Mail::Message from components

=chapter SYNOPSIS

  my $msg1 = Mail::Message->build(
    From => 'me',
    data => "only two\nlines\n",
  );

  my $msg2 = Mail::Message->buildFromBody($body);

  Mail::Message->build(
    From     => 'me@myhost.com',
    To       => 'you@yourhost.com',
    Subject  => "Read our folder!",

    data     => \@lines,
    file     => 'folder.pdf',
  )->send(via => 'postfix');

=chapter DESCRIPTION

Complex functionality on Mail::Message objects is implemented in
different files which are autoloaded.  This file implements the
building of messages from various simpler components.

=chapter METHODS

=section Constructing a message

=c_method build [$message|$part|$body], @fields, %options

Simplified message object builder.  In case a $message or message $part is
specified, a new message is created with the same body to start with, but
new headers.  A $body may be specified as well.  However, there are more
ways to add data simply.

You may pass @fields as objects, even mixed with option PAIRS.  The
fields will be transmitted in the order they were created, so that
might be needed.

In the %options LIST, the keys which start with a capital are used
as header-lines.  Lower-cased fields are used for other purposes as
listed below.  Each field may be used more than once.  Pairs where the
value is undef are ignored.

If more than one P<data>, P<file>, and P<attach> is specified,
a multi-parted message is created.  Some C<Content-*> fields are
treated separately: to enforce the content lines of the produced
message body B<after> it has been created.  For instance, to explicitly
state that you wish a C<multipart/alternative> in stead of the default
C<multipart/mixed>.  If you wish to specify the type per datum, you need
to start playing with Mail::Message::Body objects yourself.

This C<build> method will use M<buildFromBody()> when the body object has
been constructed.  Together, they produce your message.

=option  data $text|\@lines
=default data undef
The $text for one part, specified as one string, or an ARRAY of @lines.
Each line, including the last, must be terminated by a newline.  This
argument is passed to M<Mail::Message::Body::new(data)> to construct one.

  data => [ "line 1\n", "line 2\n" ] # array of lines
  data => <<'TEXT'                   # string
 line 1
 line 2
 TEXT

=option  file $file|$fh|$io|\@files
=default file undef
Create a body where the data is read from the specified $file by name,
filehandle $fh, or $io object of type IO::Handle.  Also this body is used
to create a Mail::Message::Body. [2.119] You may even pass more
than one file at once: 'file' and 'files' option are equivalent.

  my $in = IO::File->new('/etc/passwd', 'r');

  file  => 'picture.jpg'              # filename
  file  => $fh                        # IO::File or GLOB
  files => [ 'picture.jpg', $fh ]

=option  files \@files
=default files C<[ ]>
Alias for option P<file>.

=option  attach $body|$part|$message|\@attach
=default attach undef
One attachment to the message.  Each attachment can be full $message,
a $part, or a $body.  Any $message will get encapsulated into a
C<message/rfc822> body.  You can specify many items (may be of different
types) at once.

  attach => $folder->message(3)->decoded  # body
  attach => $folder->message(3)           # message
  attach => [ $msg1, $msg2->part(6), $msg3->body ];

=option  head $head
=default head undef
Start with a prepared header, otherwise one is created.

=examples

  my $msg = Mail::Message->build(
    From    => 'me@home.nl',
    To      => Mail::Address->new('your name', 'you@yourplace.aq'),
    Cc      => 'everyone@example.com',
    Subject => "Let's talk",,
    $other_message->get('Bcc'),

    data   => [ "This is\n", "the first part of\n", "the message\n" ],
    file   => 'myself.gif',
    file   => 'you.jpg',
    attach => $signature,
  );

  my $msg = Mail::Message->build(
    To     => 'you',
    'Content-Type' => 'text/html',
    data   => "<html></html>",
  );

=error only build() Mail::Message's; they are not in a folder yet.
You may wish to construct a message to be stored in a some kind
of folder, but you need to do that in two steps.  First, create a
normal Mail::Message, and then add it to the folder.  During this
M<Mail::Box::addMessage()> process, the message will get M<coerce()>-d
into the right message type, adding storage information and the like.

=warning skipped unknown key '$key' in build.
=cut

sub build(@)
{	my $class = shift;

	! $class->isa('Mail::Box::Message')
		or error __x"only build() Mail::Message's; they are not in a folder yet.";

	my @parts
	  = ! blessed $_[0] ? ()
	  : $_[0]->isa('Mail::Message')       ? shift
	  : $_[0]->isa('Mail::Message::Body') ? shift
	  :    ();

	my ($head, @headerlines);
	my ($type, $transfenc, $dispose, $descr, $cid, $lang);
	while(@_)
	{	my $key = shift;

		if(blessed $key && $key->isa('Mail::Message::Field'))
		{	my $name = $key->name;
			   if($name eq 'content-type')        { $type    = $key }
			elsif($name eq 'content-transfer-encoding') { $transfenc = $key }
			elsif($name eq 'content-disposition') { $dispose = $key }
			elsif($name eq 'content-description') { $descr   = $key }
			elsif($name eq 'content-language')    { $lang    = $key }
			elsif($name eq 'content-id')          { $cid     = $key }
			else { push @headerlines, $key }
			next;
		}

		my $value = shift // next;

		my @data;

		if($key eq 'head')
		{	$head = $value }
		elsif($key eq 'data')
		{	@data = Mail::Message::Body->new(data => $value) }
		elsif($key eq 'file' || $key eq 'files')
		{	@data = map Mail::Message::Body->new(file => $_), ref $value eq 'ARRAY' ? @$value : $value;
		}
		elsif($key eq 'attach')
		{	foreach my $c (ref $value eq 'ARRAY' ? @$value : $value)
			{	defined $c or next;
				push @data, blessed $c && $c->isa('Mail::Message') ? Mail::Message::Body::Nested->new(nested => $c) : $c;
			}
		}
		elsif($key =~ m/^content\-(type|transfer\-encoding|disposition|language|description|id)$/i )
		{	my $k     = lc $1;
			my $field = Mail::Message::Field->new($key, $value);
			   if($k eq 'type')        { $type    = $field }
			elsif($k eq 'disposition') { $dispose = $field }
			elsif($k eq 'description') { $descr   = $field }
			elsif($k eq 'language')    { $lang    = $field }
			elsif($k eq 'id')          { $cid     = $field }
			else                     { $transfenc = $field }
		}
		elsif($key =~ m/^[A-Z]/)
		{	push @headerlines, $key, $value }
		else
		{	warning __x"skipped unknown key '{key}' in build.", key => $key;
		}

		push @parts, grep defined, @data;
	}

	my $body
	  = @parts==0 ? Mail::Message::Body::Lines->new
	  : @parts==1 ? $parts[0]
	  :    Mail::Message::Body::Multipart->new(parts => \@parts);

	# Setting the type explicitly, only after the body object is finalized
	$body->type($type)           if defined $type;
	$body->disposition($dispose) if defined $dispose;
	$body->description($descr)   if defined $descr;
	$body->language($lang)       if defined $lang;
	$body->contentId($cid)       if defined $cid;
	$body->transferEncoding($transfenc) if defined $transfenc;

	$class->buildFromBody($body, $head, @headerlines);
}

=c_method buildFromBody $body, [$head], $headers
Shape a message around a $body.  Bodies have information about their
content in them, which is used to construct a header for the message.
You may specify a $head object which is pre-initialized, or one is
created for you (also when $head is undef).
Next to that, more $headers can be specified which are stored in that
header.

Header fields are added in order, and before the header lines as
defined by the body are taken.  They may be supplied as key-value
pairs or Mail::Message::Field objects.  In case of a key-value
pair, the field's name is to be used as key and the value is a
string, address (Mail::Address object), or array of addresses.

A C<Date>, C<Message-Id>, and C<MIME-Version> field are added unless
supplied.

=examples

  my $type = Mail::Message::Field->new('Content-Type', 'text/html',
    'charset="us-ascii"');

  my @to   = (
    Mail::Address->new('Your name', 'you@example.com'),
    'world@example.info',
  );

  my $msg  = Mail::Message->buildFromBody($body,
    From => 'me@example.nl',
    To   => \@to,
    $type,
  );

=cut

sub buildFromBody(@)
{	my ($class, $body) = (shift, shift);

	my $head;
	if(blessed $_[0] && $_[0]->isa('Mail::Message::Head')) { $head = shift }
	else
	{	defined $_[0] or shift;   # explicit undef as head
		$head = Mail::Message::Head::Complete->new;
	}

	while(@_)
	{	if(blessed $_[0]) { $head->add(shift) }
		else              { $head->add(shift, shift) }
	}

	my $message = $class->new(head => $head);
	$message->body($body);

	# be sure the message-id is actually stored in the header.
	defined $head->get('message-id')   or $head->add('Message-Id' => '<'.$message->messageId.'>');
	defined $head->get('Date')         or $head->add(Date => Mail::Message::Field->toDate);
	defined $head->get('MIME-Version') or $head->add('MIME-Version' => '1.0'); # required by rfc2045

	$message;
}

#--------------------
=chapter DETAILS

=section Building a message

=subsection Rapid building

Most messages you need to construct are relatively simple.  Therefore,
this module provides a method to prepare a message with only one method
call: M<build()>.

=subsection Compared to MIME::Entity::build()

The C<build> method in MailBox is modelled after the C<build> method
as provided by MIMETools, but with a few simplifications:

=over 4
=item When a keys starts with a capital, than it is always a header field
=item When a keys is lower-cased, it is always something else
=item You use the real field-names, not abbreviations
=item All field names are accepted
=item You may specify field objects between key-value pairs
=item A lot of facts are auto-detected, like content-type and encoding
=item You can create a multipart at once
=back

Hum, reading the list above... what is equivalent?  L<MIME::Entity> is
not that simple after all!  Let's look at an example from MIME::Entity's
manual page:

  ### Create the top-level, and set up the mail headers:
  $top = MIME::Entity->build(
    Type     => "multipart/mixed",
    From     => 'me@myhost.com',
    To       => 'you@yourhost.com',
    Subject  => "Hello, nurse!",
  );

  ### Attachment #1: a simple text document:
  $top->attach(Path=>"./testin/short.txt");

  ### Attachment #2: a GIF file:
  $top->attach(
    Path        => "./docs/mime-sm.gif",
    Type        => "image/gif",
    Encoding    => "base64",
  );

  ### Attachment #3: text we'll create with text we have on-hand:
  $top->attach(Data => $contents);

The MailBox equivalent could be

  my $msg = Mail::Message->build(
    From     => 'me@myhost.com',
    To       => 'you@yourhost.com',
    Subject  => "Hello, nurse!",

    file     => "./testin/short.txt",
    file     => "./docs/mime-sm.gif",
    data     => $contents,
  );

One of the simplifications is that MIME::Types is used to lookup
the right content type and optimal transfer encoding.  Good values
for content-disposition and such are added as well.

=subsection build, starting with nothing

See M<build()>.

=subsection buildFromBody, body becomes message

See M<buildFromBody()>.

=subsection The Content-* fields

The various C<Content-*> fields are not as harmless as they look.  For
instance, the "Content-Type" field will have an effect on the default
transfer encoding.

When a message is built this way:

  my $msg = Mail::Message->build(
    'Content-Type' => 'video/mpeg3',
    'Content-Transfer-Encoding' => 'base64',
    'Content-Disposition' => 'attachment',
    file => '/etc/passwd',
  );

then first a C<text/plain> body is constructed (MIME::Types does not
find an extension on the filename so defaults to C<text/plain>), with
no encoding.  Only when that body is ready, the new type and requested
encodings are set.  The content of the body will get base64 encoded,
because it is requested that way.

What basically happens is this:

  my $head = ...other header lines...;
  my $body = Mail::Message::Body::Lines->new(file => '/etc/passwd');
  $body->type('video/mpeg3');
  $body->transferEncoding('base64');
  $body->disposition('attachment');
  my $msg  = Mail::Message->buildFromBody($body, $head);

A safer way to construct the message is:

  my $body = Mail::Message::Body::Lines->new(
    file              => '/etc/passwd',
    mime_type         => 'video/mpeg3',
    transfer_encoding => 'base64',
    disposition       => 'attachment',
  );

  my $msg  = Mail::Message->buildFromBody(
    $body,
    ...other header lines...
  );

In the latter program, you will immediately start with a body of
the right type.
=cut

1;
