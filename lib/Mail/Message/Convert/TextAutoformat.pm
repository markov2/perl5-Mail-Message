#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Convert::TextAutoformat;
use base 'Mail::Message::Convert';

use strict;
use warnings;

use Text::Autoformat qw/autoformat/;

use Mail::Message::Body::String ();

#--------------------
=chapter NAME

Mail::Message::Convert::TextAutoformat - Reformat plain text messages

=chapter SYNOPSIS

  use Mail::Message::Convert::TextAutoformat;
  my $af = Mail::Message::Convert::TextAutoformat->new;

  my $beautified_body = $af->autoformatBody($body);

=chapter DESCRIPTION

Play trics with plain text, for instance bodies with type C<text/plain>
using Damian Conway's Text::Autoformat.

=chapter METHODS

=c_method new %options

=option  options \%af
=default options C<< +{ all => 1 } >>
The %af options to pass to Text::Autoformat function C<autoformat()>.
=cut

sub init($)
{	my ($self, $args)  = @_;
	$self->SUPER::init($args);

	$self->{MMCA_options} = $args->{autoformat} || +{ all => 1 };
	$self;
}

#--------------------
=section Converting

=method autoformatBody $body
Formats a single message body (a Mail::Message::Body object) into a new
body object using Text::Autoformat.

The body should have content type C<text/plain>, otherwise the output is
probably weird.
=cut

sub autoformatBody($)
{	my ($self, $body) = @_;
	(ref $body)->new(based_on => $body, data => autoformat($body->string, $self->{MMCA_options}));
}

1;
