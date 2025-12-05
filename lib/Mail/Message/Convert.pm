#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Convert;
use parent 'Mail::Reporter';

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw// ];

#--------------------
=chapter NAME

Mail::Message::Convert - conversions between message types

=chapter SYNOPSIS

Available methods are very converter-specific.

=chapter DESCRIPTION

This class is the base for various message (and message parts) converters.

=section Converters between message objects
Internally, the M<Mail::Message::coerce()> is called when foreign objects
are used where message objects are expected.  That method will automatically
create the converting objects, and re-use them.

=over 4
=item * Mail::Message::Convert::MailInternet
Converts the simple Mail::Internet messages into Mail::Message
objects.

=item * Mail::Message::Convert::MimeEntity
Converts the more complicated MIME::Entity messages into
Mail::Message objects.

=item * Mail::Message::Convert::EmailSimple
Converts Email::Simple messages into Mail::Message objects.

=back

=section Other converters

=over 4

=item * Mail::Message::Convert::Html
Plays tricks with HTML/XMHTML without help of external modules.

=item * Mail::Message::Convert::HtmlFormatText
Converts HTML body objects to plain text objects using the
HTML::FormatText module.

=item * Mail::Message::Convert::HtmlFormatPS
Converts HTML body objects to Postscript objects using the
HTML::FormatPS module.

=item * Mail::Message::Convert::TextAutoformat
Converts a text message into text using Text::Autoformat.

=back

=chapter METHODS

=c_method new %options

=option  fields $name|$regex|\@names|\@regexes
=default fields <see description>

Select the fields of a header which are to be handled.  Other
fields will not be used.  The value of this option is passed to
M<Mail::Message::Head::Complete::grepNames()> whenever converters feel
a need for header line selection.
By default, the C<To>, C<From>, C<Cc>, C<Bcc>, C<Date>, C<Subject>, and their
C<Resent-> counterparts will be selected.  Specify an empty list to get all
fields.
=cut

sub init($)
{	my ($self, $args) = @_;
	$self->SUPER::init($args);

	$self->{MMC_fields} = $args->{fields} || qr#^(Resent\-)?(To|From|Cc|Bcc|Subject|Date)\b#i;
	$self;
}

#--------------------
=section Converting

=method selectedFields $head

Returns a list of fields to be included in the format.  The list is
an ordered selection of the fields in the actual header, and filtered
through the information as specified with M<new(fields)>.

=cut

sub selectedFields($)
{	my ($self, $head) = @_;
	$head->grepNames($self->{MMC_fields});
}

#--------------------
=section Error handling

=cut

1;
