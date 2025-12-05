#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::TransferEnc;
use parent 'Mail::Reporter';

use strict;
use warnings;

use Log::Report     'mail-message', import => [ qw/__x error/ ];

#--------------------
=chapter NAME

Mail::Message::TransferEnc - message transfer encoder/decoder

=chapter SYNOPSIS

  my Mail::Message $msg = ...;
  my $decoded = $msg->decoded;
  my $encoded = $msg->encode(transfer => 'base64');

=chapter DESCRIPTION

This class is the base for various encoders and decoders, which are
used during transport of the message.  These packages, and all which are
derived, are invoked by the message's M<Mail::Message::decoded()> and
M<Mail::Message::encode()> methods:

  my $message = $folder->message(3);
  my $decoded_body = $message->decoded;
  my $encoded_body = $message->encode(transfer => 'base64');

Rules for transfer encodings are specified in RFC4289.  The full list
of permissible content transfer encodings can be found at
L<https://www.iana.org/assignments/transfer-encodings/transfer-encodings.xhtml>

The following coders/decoders are currently supported (April 2025, the full
list at IANA):

=over 4
=item * Mail::Message::TransferEnc::Base64
C<base64> for binary information.

=item * Mail::Message::TransferEnc::SevenBit
C<7bit> for plain old ASCII characters only.

=item * Mail::Message::TransferEnc::EightBit
C<8bit> for extended character set data, not encoded.

=item * Mail::Message::TransferEnc::QuotedPrint
C<quoted-printable> encdoded extended character set data.

=back

=chapter METHODS

=cut

my %encoder = (
	'base64' => 'Mail::Message::TransferEnc::Base64',
	'7bit'   => 'Mail::Message::TransferEnc::SevenBit',
	'8bit'   => 'Mail::Message::TransferEnc::EightBit',
	'quoted-printable' => 'Mail::Message::TransferEnc::QuotedPrint',
);

#--------------------
=section The Encoder

=method create $type, %options
Create a new coder/decoder based on the required type.

=error no decoder for transfer encoding $type.
A decoder for the specified type of transfer encoding is not implemented.

=error decoder for transfer encoding $type does not work: $@
Compiling the required transfer encoding resulted in errors, which means
that the decoder can not be used.

=cut

sub create($@)
{	my ($class, $type) = (shift, shift);

	my $encoder = $encoder{lc $type}
		or error __x"no decoder for transfer encoding {type}.", type => $type;

	eval "require $encoder";
	$@ and error __x"decoder for transfer encoding {type} does not work:\n{error}", type => $type, error => $@;

	$encoder->new(@_);
}

=c_method addTransferEncoder $type, $class
Adds one new encoder to the list known by the Mail::Box suite.  The
$type is found in the message's header in the C<Content-Transfer-Encoding>
field.

=cut

sub addTransferEncoder($$)
{	my ($class, $type, $encoderclass) = @_;
	$encoder{lc $type} = $encoderclass;
	$class;
}

=method name
The name of the encoder.  Case is not significant.
=cut

sub name { $_[0]->notImplemented }

#--------------------
=section Encoding

=method check $body, %options
Check whether the body is correctly encoded.  If so, the body reference is
returned with the C<checked> flag set.  Otherwise, a new object is created
and returned.

=option  result_type  CLASS
=default result_type  <type of source body>
The type of the body to be produced, when the checker decides to return
modified data.

=cut

sub check($@) { $_[0]->notImplemented }

=method decode $body, %options
Use the encoder to decode the content of $body.  A new body is returned.

=option  result_type  CLASS
=default result_type  <type of source body>
The type of the body to be produced, when the decoder decides to return
modified data.
=cut

sub decode($@) { $_[0]->notImplemented }

=method encode $body, %options
Use the encoder to encode the content of $body.

=option  result_type  CLASS
=default result_type  <type of source body>
The type of the body to be produced, when the decoder decides to return
modified data.
=cut

sub encode($) { $_[0]->notImplemented }

#--------------------
=section Error handling

=cut

1;
