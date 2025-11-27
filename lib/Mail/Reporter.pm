#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Reporter;

use strict;
use warnings;

use Log::Report     'mail-message';

use Scalar::Util    qw/dualvar blessed/;

#--------------------
=chapter NAME

Mail::Reporter - base-class and error reporter for Mail::Box

=chapter SYNOPSIS

=chapter DESCRIPTION

The C<Mail::Reporter> class is the base class for all classes, except
Mail::Message::Field::Fast because it would become slow...  This
base class is used during initiation of the objects.

=chapter METHODS

The C<Mail::Reporter> class is the base for nearly all other
objects.  It can store and report problems, and contains the general
constructor M<new()>.

=section Constructors

=c_method new %options
This is the base constructor for all modules, (as long as there is
no need for another base object)
=cut

sub new(@)
{	my $class = shift;
	(bless +{}, $class)->init( +{@_} );
}

sub init($) { shift }

#--------------------
=section Attributes
=cut

#--------------------
=section Error handling

=method notImplemented

=error class $package does not implement method $method.
Fatal error: the specific $package (or one of its superclasses) does not
implement this method where it should. This message means that some other
related classes do implement this method however the class at hand does
not.  Probably you should investigate this and probably inform the author
of the package.
=cut

sub notImplemented(@)
{	my $self    = shift;
	my $package = ref $self || $self;
	my $sub     = (caller 1)[3];

	error __x"class {package} does not implement method {method}.", class => $package, method => $sub;
}

=method AUTOLOAD
By default, produce a nice warning if the sub-classes cannot resolve
a method.
=cut

sub AUTOLOAD(@)
{	my $thing   = shift;
	our $AUTOLOAD;
	my $class  = ref $thing || $thing;
	my $method = $AUTOLOAD =~ s/^.*\:\://r;

	panic "method $method() is not defined for a $class.";
}

#--------------------
=section Cleanup

=method DESTROY
Cleanup the object.
=cut

sub DESTROY { $_[0] }

1;
