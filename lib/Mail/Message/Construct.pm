#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message;

use strict;
use warnings;

use Log::Report   'mail-message', import => [ qw// ];

#--------------------
=chapter NAME

Mail::Message::Construct - extends the functionality of a Mail::Message

=chapter SYNOPSIS

  # See Mail::Message

=chapter DESCRIPTION

Complex functionality on Mail::Message objects is implemented in
different files which are autoloaded.  This file implements the
functionality related to creating message replies.

The following constructors are available:
=over 4
=item Mail::Message::Construct::Bounce
=item Mail::Message::Construct::Build
=item Mail::Message::Construct::Forward
=item Mail::Message::Construct::Read
=item Mail::Message::Construct::Rebuild
=item Mail::Message::Construct::Reply
=item Mail::Message::Construct::Text
=back

=chapter METHODS

=method AUTOLOAD

When an unknown method is called on this message, this may mean that
not all code is compiled.  For performance reasons, most of the
complex activities on messages are dynamically loaded from other
packages.  An error will be produced when loading does not help resolving
the requested method.

=cut

our %locations = (
	bounce             => 'Bounce',

	build              => 'Build',
	buildFromBody      => 'Build',

	forward            => 'Forward',
	forwardNo          => 'Forward',
	forwardInline      => 'Forward',
	forwardAttach      => 'Forward',
	forwardEncapsulate => 'Forward',
	forwardSubject     => 'Forward',
	forwardPrelude     => 'Forward',
	forwardPostlude    => 'Forward',

	read               => 'Read',

	rebuild            => 'Rebuild',

	reply              => 'Reply',
	replySubject       => 'Reply',
	replyPrelude       => 'Reply',

	string             => 'Text',
	lines              => 'Text',
	file               => 'Text',
	printStructure     => 'Text',
);

sub AUTOLOAD(@)
{	my $self  = shift;
	our $AUTOLOAD;
	my $call = $AUTOLOAD =~ s/.*\:\://gr;

	if(my $mod = $locations{$call})
	{	eval "require Mail::Message::Construct::$mod";
		die $@ if $@;
		return $self->$call(@_);
	}

	our @ISA;                    # produce error via Mail::Reporter
	$call = "${ISA[0]}::$call";
	$self->$call(@_);
}

1;
