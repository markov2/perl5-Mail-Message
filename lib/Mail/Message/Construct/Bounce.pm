# This code is part of distribution Mail-Message.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Mail::Message;

use strict;
use warnings;

use Mail::Message::Head::Complete;
use Mail::Message::Field;
use Carp         qw/croak/;

=chapter NAME

Mail::Message::Construct::Bounce - bounce a Mail::Message

=chapter SYNOPSIS

 $message->bounce(To => 'you')->send;

=chapter DESCRIPTION

Complex functionality on M<Mail::Message> objects is implemented in
different files which are autoloaded.  This file implements the
functionality related to bouncing messages off to other destinations.

B<Be warned:> bouncing messages was very common practice in the past,
but does not play well together with SPF spam protection.  Unless you
bounce messages which originate from inside your own infrastructure,
you may get the message rejected by the spam-filters of the receivers.
The way around it, is to implement ARC... which the MailBox suite did
not try (yet).

=chapter METHODS

=section Constructing a message

=method bounce [<$rg_object|%options>]

The program calling this method considers itself as an intermediate step
in the message delivery process; it therefore leaves a resent group
of header fields as trace.

When a message is received, the Mail Transfer Agent (MTA) adds a
C<Received> field to the header.  As %options, you may specify lines
which are added to the resent group of that received field.  C<Resent-*>
is prepended before the field-names automatically, unless already present.

You may also specify an instantiated M<Mail::Message::Head::ResentGroup> (RG)
object.  See M<Mail::Message::Head::ResentGroup::new()> for the available
options.  This is required if you want to add a new resent group: create
a new C<Received> line in the header as well.

If you are planning to change the body of a bounce message, don't!  Bounced
messages have the same message-id as the original message, and therefore
should have the same content (message-ids are universally unique).  If you
still insist, use M<Mail::Message::body()>.

=examples

 my $bounce = $folder->message(3)->bounce(To => 'you', Bcc => 'everyone');

 $bounce->send;
 $outbox->addMessage($bounce);

 my $rg     = Mail::Message::Head::ResentGroup->new(To => 'you',
    Received => 'from ... by ...');
 $msg->bounce($rg)->send;

=error Method bounce requires To, Cc, or Bcc
The message M<bounce()> method forwards a received message off to someone
else without modification; you must specified it's new destination.
If you have the urge not to specify any destination, you probably
are looking for M<reply()>. When you wish to modify the content, use
M<forward()>.

=cut

sub bounce(@)
{   my $self   = shift;
    my $bounce = $self->clone;
    my $head   = $bounce->head;

    if(@_==1 && ref $_[0] && $_[0]->isa('Mail::Message::Head::ResentGroup' ))
    {    $head->addResentGroup(shift);
         return $bounce;
    }

    my @rgs    = $head->resentGroups;
    my $rg     = $rgs[0];

    if(defined $rg)
    {   $rg->delete;     # Remove group to re-add it later: otherwise
        while(@_)        #   field order in header would be disturbed.
        {   my $field = shift;
            ref $field ? $rg->set($field) : $rg->set($field, shift);
        }
    }
    elsif(@_)
    {   $rg = Mail::Message::Head::ResentGroup->new(@_);
    }
    else
    {   $self->log(ERROR => "Method bounce requires To, Cc, or Bcc");
        return undef;
    }
 
    #
    # Add some nice extra fields.
    #

    $rg->set(Date => Mail::Message::Field->toDate)
        unless defined $rg->date;

    unless(defined $rg->messageId)
    {   my $msgid = $head->createMessageId;
        $rg->set('Message-ID' => "<$msgid>");
    }

    $head->addResentGroup($rg);

    #
    # Flag action to original message
    #

    $self->label(passed => 1);    # used by some maildir clients

    $bounce;
}

1;
