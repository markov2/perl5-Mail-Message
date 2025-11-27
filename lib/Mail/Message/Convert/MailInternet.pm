#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Convert::MailInternet;
use parent 'Mail::Message::Convert';

use strict;
use warnings;

use Log::Report   'mail-message';

use Mail::Internet ();
use Mail::Header   ();

use Mail::Message                 ();
use Mail::Message::Head::Complete ();
use Mail::Message::Body::Lines    ();

#--------------------
=chapter NAME

Mail::Message::Convert::MailInternet - translate Mail::Message to Mail::Internet vv

=chapter SYNOPSIS

  use Mail::Message::Convert::MailInternet;
  my $convert = Mail::Message::Convert::MailInternet->new;

  my Mail::Message  $msg    = Mail::Message->new;
  my Mail::Internet $intern = $convert->export($msg);

  my Mail::Internet $intern = Mail::Internet->new;
  my Mail::Message  $msg    = $convert->from($intern);

  use Mail::Box::Manager;
  my $mgr     = Mail::Box::Manager->new;
  my $folder  = $mgr->open(folder => 'Outbox');
  $folder->addMessage($intern);

=chapter DESCRIPTION

The Mail::Internet class of messages is very popular for all
kinds of message applications written in Perl.  However, the
format was developed when e-mail messages where still small and
attachments where rare; Mail::Message is much more flexible in
this respect.

=chapter METHODS

=section Converting

=method export $message, %options
Returns a new message object based on the information from
a Mail::Message object.  The $message specified is an
instance of a Mail::Message.

=examples
  my $convert = Mail::Message::Convert::MailInternet->new;
  my Mail::Message  $msg   = Mail::Message->new;
  my Mail::Internet $copy  = $convert->export($msg);

=error export message must be a Mail::Message, but is a {kind}.
=cut

sub export($@)
{	my ($thing, $message) = (shift, shift);

	$message->isa('Mail::Message')
		or error __x"export message must be a Mail::Message, but is a {kind}.", kind => ref $message;

	my $mi_head = Mail::Header->new;
	foreach my $field ($message->head->orderedFields)
	{	$mi_head->add($field->Name, scalar $field->foldedBody);
	}

	Mail::Internet->new(Header => $mi_head, Body => [ $message->body->lines ], @_);
}

=method from $object, %options
Returns a new Mail::Message object based on the information
from a Mail::Internet object.

=examples
  my $convert = Mail::Message::Convert::MailInternet->new;
  my Mail::Internet $msg  = Mail::Internet->new;
  my Mail::Message  $copy = $convert->from($msg);

=error converting from Mail::Internet but got a {class}.
=cut

my @pref_order = qw/From To Cc Subject Date In-Reply-To References Content-Type/;

sub from($@)
{	my ($thing, $mi) = (shift, shift);

	$mi->isa('Mail::Internet')
		or error __x"converting from Mail::Internet but got a {class}.", class => ref $mi;

	my $head = Mail::Message::Head::Complete->new;
	my $body = Mail::Message::Body::Lines->new(data => [ @{$mi->body} ]);

	my $mi_head = $mi->head;

	# The tags of Mail::Header are unordered, but we prefer some ordering.
	my %tags = map +(lc $_ => ucfirst $_), $mi_head->tags;
	my @tags;
	foreach (@pref_order)
	{	push @tags, $_ if delete $tags{lc $_};
	}
	push @tags, sort values %tags;

	foreach my $name (@tags)
	{	$head->add($name, $_) for $mi_head->get($name);
	}

	Mail::Message->new(head => $head, body => $body, @_);
}

1;
