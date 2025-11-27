#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Convert::MimeEntity;
use parent 'Mail::Message::Convert';

use strict;
use warnings;

use Log::Report   'mail-message';

use MIME::Entity   ();
use MIME::Parser   ();

use Mail::Message  ();

#--------------------
=chapter NAME

Mail::Message::Convert::MimeEntity - translate Mail::Message to MIME::Entity vv

=chapter SYNOPSIS

  use Mail::Message::Convert::MimeEntity;
  my $convert = Mail::Message::Convert::MimeEntity->new;

  my Mail::Message $msg    = Mail::Message->new;
  my MIME::Entity  $entity = $convert->export($msg);

  my MIME::Entity  $entity = MIME::Entity->new;
  my Mail::Message $msg    = $convert->from($entity);

  use Mail::Box::Manager;
  my $mgr     = Mail::Box::Manager->new;
  my $folder  = $mgr->open(folder => 'Outbox');
  $folder->addMessage($entity);

=chapter DESCRIPTION

The MIME::Entity extends Mail::Internet message with multiparts
and more methods.  The Mail::Message objects are more flexible
in how the message parts are stored, and uses separate header and body
objects.

=chapter METHODS

=section Converting

=method export $message, [$parser]
Returns a new MIME::Entity message object based on the
information from the $message, which is a Mail::Message object.

You may want to supply your own $parser, which is a MIME::Parser
object, to change the parser flags.  Without a $parser object, one
is created for you, with all the default settings.

If undef is passed, in place of a $message, then an empty list is
returned.  When the parsing failes, then MIME::Parser throws an
exception.

=examples
  my $convert = Mail::Message::Convert::MimeEntity->new;
  my Mail::Message $msg  = Mail::Message->new;
  my MIME::Entity  $copy = $convert->export($msg);

=error export message must be a Mail::Message, but is a {class}.
=cut

sub export($$;$)
{	my ($self, $message, $parser) = @_;
	defined $message or return ();

	$message->isa('Mail::Message')
		or error __x"export message must be a Mail::Message, but is a {class}.", class => ref $message;

	$parser ||= MIME::Parser->new;
	$parser->parse($message->file);
}

=method from $mime_object
Returns a new Mail::Message object based on the information from
the specified MIME::Entity.  If the conversion fails, the undef
is returned.  If undef is passed in place of an OBJECT, then an
empty list is returned.

=examples
  my $convert = Mail::Message::Convert::MimeEntity->new;
  my MIME::Entity  $msg  = MIME::Entity->new;
  my Mail::Message $copy = $convert->from($msg);

=error converting from MIME::Entity but got a $class.
=cut

sub from($)
{	my ($self, $mime_ent) = @_;
	defined $mime_ent or return ();

	$mime_ent->isa('MIME::Entity')
		or error __x"converting from MIME::Entity but got a {class}.", class => ref $mime_ent;

	Mail::Message->read($mime_ent->as_string);
}

1;
