#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Convert::EmailSimple;
use parent 'Mail::Message::Convert';

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw/__x error/ ];

use Mail::Internet  ();
use Mail::Header    ();
use Email::Simple   ();

use Mail::Message                 ();
use Mail::Message::Head::Complete ();
use Mail::Message::Body::Lines    ();

#--------------------
=chapter NAME

Mail::Message::Convert::EmailSimple - translate Mail::Message to Email::Simple vv

=chapter SYNOPSIS

  use Mail::Message::Convert::EmailSimple;
  my $convert = Mail::Message::Convert::EmailSimple->new;

  my Mail::Message $msg    = Mail::Message->new;
  my Email::Simple $intern = $convert->export($msg);

  my Email::Simple $intern = Mail::Internet->new;
  my Mail::Message $msg    = $convert->from($intern);

  use Mail::Box::Manager;
  my $mgr     = Mail::Box::Manager->new;
  my $folder  = $mgr->open(folder => 'Outbox');
  $folder->addMessage($intern);

=chapter DESCRIPTION

The Email::Simple class is one of the base objects used by the
large set of Email* modules, which implement many e-mail needs
which are also supported by MailBox.  You can use this class to
gradularly move from a Email* based implementation into a MailBox
implementation.

The internals of this class are far from optimal.  The conversion
does work (thanks to Ricardo Signes), but is expensive in time
and memory usage.  It could easily be optimized.

=chapter METHODS

=section Converting

=method export $message, %options
Returns a new Email::Simple object based on the information from
a Mail::Message object.  The $message specified is an
instance of a Mail::Message.

=examples
  my $convert = Mail::Message::Convert::EmailSimple->new;
  my Mail::Message  $msg   = Mail::Message->new;
  my Mail::Internet $copy  = $convert->export($msg);

=error export message must be a Mail::Message, but is a $class.
=cut

sub export($@)
{	my ($thing, $message) = @_;

	$message->isa('Mail::Message')
		or error __x"export message must be a Mail::Message, but is a {class}.", class => ref $message;

	Email::Simple->new($message->string);
}

=method from $object, %options
Returns a new Mail::Message object based on the information from
an Email::Simple.

=examples
  my $convert = Mail::Message::Convert::EmailSimple->new;
  my Mail::Internet $msg  = Mail::Internet->new;
  my Mail::Message  $copy = $convert->from($msg);

=error converting from Email::Simple but got a $class.
=cut

sub from($@)
{	my ($thing, $email) = (shift, shift);

	$email->isa('Email::Simple')
		or error __x"converting from Email::Simple but got a {class}.", class => ref $email;

	Mail::Message->read($email->as_string);
}

1;
