#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message;

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw/__x error warning/ ];

use Mail::Box::Parser::Lines ();

use Scalar::Util  qw/blessed/;

#--------------------
=chapter NAME

Mail::Message::Construct::Read - read a Mail::Message from a file handle

=chapter SYNOPSIS

  my $msg1 = Mail::Message->read(\*STDIN);
  my $msg2 = Mail::Message->read(\@lines);

=chapter DESCRIPTION

When complex methods are called on a C<Mail::Message> object, this package
is autoloaded to support the reading of messages directly from any file
handle.

=chapter METHODS

=section Constructing a message

=c_method read $fh|$text|\$text|\@lines, %options

Read a message from a $fh, $text string, reference to a text string, or an
ARRAY of @lines.  Most %options are passed to the M<new()> of the message
which is created, but a few extra are defined.

Please have a look at M<build()> and M<buildFromBody()> before thinking about
this C<read> method.  Use this C<read> only when you have a file-handle
like STDIN to parse from, or some external source of message lines.
When you already have a separate set of head and body lines, then C<read>
is certainly B<not> your best choice.

Some people use this method in a procmail script: the message arrives
at stdin, so we only have a filehandle.  In this case, you are stuck
with this method.  The message is preceded by a line which can be used
as message separator in mbox folders.  See the example how to handle
that one.

This method will remove C<Status> and C<X-Status> fields when they appear
in the source, to avoid the risk that these fields accidentally interfere
with your internal administration, which may have security implications.

=option  strip_status_fields BOOLEAN
=default strip_status_fields true
Remove the C<Status> and C<X-Status> fields from the message after
reading, to lower the risk that received messages from external
sources interfere with your internal administration.  If you want
fields not to be stripped (you would like to disable the stripping)
you probably process folders yourself, which is a Bad Thing!

=option  body_type $type
=default body_type undef
Force a body $type (any specific extension of the Mail::Message::Body class)
to be used to store the message content.  Multipart and nested message parts
pick their own type.

=option  trusted BOOLEAN
=default trusted true

=option  seekable BOOLEAN
=default seekable false
Indicate that a seekable file-handle has been passed. In this case, we
can use the Mail::Box::Parser::Perl parser which reads messages
directly from the input stream.

=option  parser_class $type
=default parser_class undef
Enforce a certain parser $type to be used, which must be an extension of
the Mail::Box::Parser class otherwise taken.

=examples

  my $msg1 = Mail::Message->read(\*STDIN);
  my $msg2 = Mail::Message->read(\@lines);
  $folder->addMessages($msg1, $msg2);

  my $msg3 = Mail::Message->read(<<MSG);
  Subject: hello world
  To: you@example.com
                       # warning: empty line required !!!
  Hi, greetings!
  MSG

  # procmail example
  my $fromline = <STDIN>;
  my $msg      = Mail::Message->read(\*STDIN);
  my $coerced  = $mboxfolder->addMessage($msg);
  $coerced->fromLine($fromline);

=error cannot read message from a $source.
=cut

sub _scalar2lines($)
{	my $lines = [ split /^/, ${$_[0]} ];
#   pop @$lines if @$lines && ! length $lines->[-1];
	$lines;
}

sub read($@)
{	# try avoiding copy of large strings
	my ($class, undef, %args) = @_;
	my $trusted      = exists $args{trusted} ? $args{trusted} : 1;
	my $strip_status = exists $args{strip_status_fields} ? delete $args{strip_status_fields} : 1;
	my $body_type    = $args{body_type};
	my $pclass       = $args{parser_class};

	my $parser;
	my $ref     = ref $_[1];

	if($args{seekable})
	{	$parser = ($pclass // 'Mail::Box::Parser::Perl')
			->new(%args, filename => "file ($ref)", file => $_[1], trusted => $trusted);
	}
	else
	{	my ($source, $lines);
		if(!$ref)
		{	$source = 'scalar';
			$lines  = _scalar2lines \$_[1];
		}
		elsif($ref eq 'SCALAR')
		{	$source = 'ref scalar';
			$lines  = _scalar2lines $_[1];
		}
		elsif($ref eq 'ARRAY')
		{	$source = 'array of lines';
			$lines  = $_[1];
		}
		elsif($ref eq 'GLOB' || (blessed $_[1] && $_[1]->isa('IO::Handle')))
		{	$source = "file ($ref)";
			local $/ = undef;   # slurp
			$lines  = _scalar2lines \$_[1]->getline;
		}
		else
		{	error __x"cannot read message from a {source}.", source => $_[1]/$ref;
			return undef;
		}

		$parser = ($pclass // 'Mail::Box::Parser::Lines')
			->new(%args, source => $source, lines => $lines, trusted => $trusted);

		$body_type = 'Mail::Message::Body::Lines';
	}

	my $self = $class->new(%args);
	$self->readFromParser($parser, $body_type);
	$parser->stop;

	my $head = $self->head;
	$head->set('Message-ID' => '<'.$self->messageId.'>') unless $head->get('Message-ID');

	$head->delete('Status', 'X-Status')
		if $strip_status;

	$self;
}

1;
