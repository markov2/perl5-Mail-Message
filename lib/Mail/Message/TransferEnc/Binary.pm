#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::TransferEnc::Binary;
use parent 'Mail::Message::TransferEnc';

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw// ];

#--------------------
=chapter NAME

Mail::Message::TransferEnc::Binary - encode/decode binary message bodies

=chapter SYNOPSIS

  my Mail::Message $msg = ...;
  my $decoded = $msg->decoded;
  my $encoded = $msg->encode(transfer => 'binary');

=chapter DESCRIPTION

Encode or decode message bodies for binary transfer encoding.  This is
totally no encoding.

=chapter METHODS

=cut

sub name() { 'binary' }

sub check($@)
{	my ($self, $body, %args) = @_;
	$body;
}

sub decode($@)
{	my ($self, $body, %args) = @_;
	$body->transferEncoding('none');
	$body;
}

sub encode($@)
{	my ($self, $body, %args) = @_;
	my @lines;

	my $changes = 0;
	foreach ($body->lines)
	{	$changes++ if s/[\000\013]//g;
		push @lines, $_;
	}

	unless($changes)
	{	$body->transferEncoding('none');
		return $body;
	}

	my $bodytype = $args{result_type} || ref($self->load);
	$bodytype->new(based_on => $body, transfer_encoding => 'none', data => \@lines);
}

1;
