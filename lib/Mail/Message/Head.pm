#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Head;
use parent 'Mail::Reporter';

use strict;
use warnings;

use Log::Report   'mail-message';

use Mail::Message::Head::Complete;
use Mail::Message::Field::Fast;

use Scalar::Util   qw/weaken/;

#--------------------
=chapter NAME

Mail::Message::Head - the header of one message

=chapter SYNOPSIS

  my $head = Mail::Message::Head->new;
  $head->add('From: me@localhost');
  $head->add(From => 'me@localhost');
  $head->add(Mail::Message::Field->new(From => 'me'));
  my $subject = $head->get('subject');
  my @rec = $head->get('received');
  $head->delete('From');

=chapter DESCRIPTION

C<Mail::Message::Head> MIME headers are part of Mail::Message messages,
which are grouped in Mail::Box folders.

A long list of standard MIME header fields with definitions can be found
in RFC4021 (L<https://www.rfc-editor.org/rfc/rfc4021.html>) and its
updates RFC5322 and RFC6854.

B<ATTENTION!!!> most functionality about e-mail headers is described
in Mail::Message::Head::Complete, which is a matured header object.
Other kinds of headers will be translated to that type when time comes.

On this page, the general methods which are available on any header are
described.  Read about differences in the sub-class specific pages.

=chapter OVERLOADED

=overload "" stringifaction
The header, when used as string, will format as if
M<Mail::Message::Head::Complete::string()> was called, so return a
nicely folder full header.  An exception is made for Carp, which will
get a simplified string to avoid unreadible messages from C<croak>
and C<confess>.

=example using a header object as string

  print $head;     # implicit stringification by print
  $head->print;    # the same

  print "$head";   # explicit stringication

=overload bool true/false

When the header does not contain any lines (which is illegal, according
to the RFCs), false is returned.  In all other cases, a true value is
produced.

=cut

use overload
	qq("") => 'string_unless_carp',
	bool   => 'isEmpty';

# To satisfy overload in static resolving.
sub toString() { $_[0]->load->toString }
sub string()   { $_[0]->load->string }

sub string_unless_carp()
{	my $self = shift;
	(caller)[0] eq 'Carp' or return $self->toString;

	my $class = ref $self =~ s/^Mail::Message/MM/r;
	"$class object";
}

#--------------------
=chapter METHODS

=section Constructors

=c_method new %options

Create a new message header object.  The object will store all the
fields of a header.  When you get information from the header, it
will be returned to you as Mail::Message::Field objects, although
the fields may be stored differently internally.

If you try to instantiate a Mail::Message::Head, you will automatically
be upgraded to a Mail::Message::Head::Complete --a full head.

=option  modified BOOLEAN
=default modified false

=option  field_type CLASS
=default field_type Mail::Message::Field::Fast
The type of objects that all the fields will have.  This must be
an extension of Mail::Message::Field.

=option  message $message
=default message undef
The $message where this header belongs to.  Usually, this is not known
at creation of the header, but sometimes it is.  If not, call the
M<message()> method later to set it.
=cut

sub new(@)
{	my $class = shift;
	$class eq __PACKAGE__ ? Mail::Message::Head::Complete->new(@_) : $class->SUPER::new(@_);
}

sub init($)
{	my ($self, $args) = @_;
	$self->SUPER::init($args);

	$self->message($args->{message}) if defined $args->{message};
	$self->{MMH_field_type} = $args->{field_type} if $args->{field_type};
	$self->{MMH_fields}     = {};
	$self->{MMH_order}      = [];
	$self->{MMH_modified}   = $args->{modified} || 0;
	$self;
}

=c_method build [PAIR|$field]-LIST
A fast way to construct a header with many lines.
The PAIRs are C<(name, content)> pairs of the header, but it is also possible
to pass Mail::Message::Field objects.   A
Mail::Message::Head::Complete header is created by simply calling
M<Mail::Message::Head::Complete::build()>, and then each field
is added.  Double field names are permitted.

=examples
  my $subject = Mail::Message::Field->new(Subject => 'xyz');

  my $head = Mail::Message::Head->build(
    From     => 'me@example.com',
    To       => 'you@anywhere.aq',
    $subject,
    Received => 'one',
    Received => 'two',
  );

  print ref $head;
   # -->  Mail::Message::Head::Complete
=cut

sub build(@)
{	shift;
	Mail::Message::Head::Complete->build(@_);
}

#--------------------
=section The header

=method isDelayed
Headers may only be partially read, in which case they are called delayed.
This method returns true if some header information still needs to be
read. Returns false if all header data has been read.
Will never trigger completion.
=cut

sub isDelayed { 1 }

=method modified [BOOLEAN]
Sets the modified flag to BOOLEAN.  Without value, the current setting is
returned, but in that case you can better use M<isModified()>.
Changing this flag will not trigger header completion.

=examples
  $head->modified(1);
  if($head->modified) { ... }
  if($head->isModified) { ... }
=cut

sub modified(;$)
{	my $self = shift;
	return $self->isModified unless @_;
	$self->{MMH_modified} = shift;
}

=method isModified
Returns whether the header has been modified after being read.

=examples
  if($head->isModified) { ... }
=cut

sub isModified() { $_[0]->{MMH_modified} }

=method isEmpty
Are there any fields defined in the current header?  Be warned that
the header will not be loaded for this: delayed headers will return
true in any case.
=cut

sub isEmpty { scalar keys %{ $_[0]->{MMH_fields}} }

=method message [$message]
Get (after setting) the message where this header belongs to.
This does not trigger completion.
=cut

sub message(;$)
{	my $self = shift;
	if(@_)
	{	$self->{MMH_message} = shift;
		weaken($self->{MMH_message});
	}

	$self->{MMH_message};
}

=method orderedFields
Returns the fields ordered the way they were read or added.
=cut

sub orderedFields() { grep defined, @{ $_[0]->{MMH_order}} }

=method knownNames
Like M<Mail::Message::Head::Complete::names()>, but only returns the known
header fields, which may be less than C<names> for header types which are
partial.  C<names()> will trigger completion, where C<knownNames()> does not.
=cut

sub knownNames() { keys %{ $_[0]->{MMH_fields}} }

#--------------------
=section Access to the header

=method get $name, [$index]
Get the data which is related to the field with the $name.  The case of the
characters in $name does not matter.

If there is only one data element defined for the $name, or if there is an
$index specified as the second argument, only the specified element will be
returned. If the field $name matches more than one header the return value
depends on the context. In LIST context, all values will be returned in
the order they are read. In SCALAR context, only the last value will be
returned.

=examples

  my $head = Mail::Message::Head->new;
  $head->add('Received: abc');
  $head->add('Received: xyz');
  $head->add('Subject: greetings');

  my @rec_list   = $head->get('Received');
  my $rec_scalar = $head->get('Received');
  print ",@rec_list,$rec_scalar,"     # ,abc xyz, xyz,
  print $head->get('Received', 0);    # abc
  my @sub_list   = $head->get('Subject');
  my $sub_scalar = $head->get('Subject');
  print ",@sub_list,$sub_scalar,"     # ,greetings, greetings,
=cut

sub get($;$)
{	my $known = shift->{MMH_fields};
	my $value = $known->{lc(shift)};
	my $index = shift;

	if(defined $index)
	{	return ! defined $value   ? undef
		  : ref $value eq 'ARRAY' ? $value->[$index]
		  : $index == 0           ? $value
		  :    undef;
	}

	if(wantarray)
	{	return ! defined $value   ? ()
		  : ref $value eq 'ARRAY' ? @$value
		  :    ($value);
	}

	    ! defined $value      ? undef
	  : ref $value eq 'ARRAY' ? $value->[-1]
	  :    $value;
}

sub get_all(@) { my @all = shift->get(@_) }   # compatibility, force list
sub setField($$) {shift->add(@_)} # compatibility

=method study $name, [$index]
Like M<get()>, but puts more effort in understanding the contents of the
field.  M<Mail::Message::Field::study()> will be called for the field
with the specified FIELDNAME, which returns Mail::Message::Field::Full
objects. In scalar context only the last field with that name is returned.
When an $index is specified, that element is returned.
=cut

sub study($;$)
{	my $self = shift;
	return map $_->study, $self->get(@_)
		if wantarray;

	my $got  = $self->get(@_);
	defined $got ? $got->study : undef;
}

#--------------------
=section About the body

=method guessBodySize
Try to estimate the size of the body of this message, but without parsing
the header or body.  The result might be undef or a few percent of
the real size.  It may even be very far of the real value, that's why
this is a guess.
=cut

=method isMultipart
Returns whether the body of the related message is a multipart body.
May trigger completion, when the C<Content-Type> field is not defined.
=cut

sub isMultipart()
{	my $type = $_[0]->get('Content-Type', 0);
	$type && scalar $type->body =~ m[^multipart/]i;
}

#--------------------
=section Internals

=method read $parser
Read the header information of one message into this header structure.  This
method is called by the folder object (some Mail::Box sub-class), which
passes the $parser as an argument.
=cut

sub read($)
{	my ($self, $parser) = @_;

	my @fields = $parser->readHeader;
	@$self{ qw/MMH_begin MMH_end/ } = (shift @fields, shift @fields);

	my $type   = $self->{MMH_field_type} // 'Mail::Message::Field::Fast';

	$self->addNoRealize( $type->new(@$_) ) for @fields;
	$self;
}

=method addOrderedFields $fields
=cut

#  Warning: fields are added in addResentGroup() as well!
sub addOrderedFields(@)
{	my $order = shift->{MMH_order};
	foreach (@_)
	{	push @$order, $_;
		weaken( $order->[-1] );
	}
	@_;
}

=method load
Be sure that the header is loaded.  This returns the loaded header
object.
=cut

sub load($) { $_[0] }

=method fileLocation
Returns the location of the header in the file, as a pair begin and end.  The
begin is the first byte of the header.  The end is the first byte after
the header.
=cut

sub fileLocation()
{	my $self = shift;
	@$self{ qw/MMH_begin MMH_end/ };
}

=method moveLocation $distance
Move the registration of the header in the file.
=cut

sub moveLocation($)
{	my ($self, $dist) = @_;
	$self->{MMH_begin} -= $dist;
	$self->{MMH_end}   -= $dist;
	$self;
}

=method setNoRealize $field
Set a field, but avoid the loading of a possibly partial header as set()
does.  This method does not test the validity of the argument, nor flag the
header as changed.  This does not trigger completion.
=cut

sub setNoRealize($)
{	my ($self, $field) = @_;

	my $known = $self->{MMH_fields};
	my $name  = $field->name;

	$self->addOrderedFields($field);
	$known->{$name} = $field;
	$field;
}

=method addNoRealize $field
Add a field, like M<Mail::Message::Head::Complete::add()> does, but
avoid the loading of a possibly partial header.  This method does not
test the validity of the argument, nor flag the header as changed.
This does not trigger completion.
=cut

sub addNoRealize($)
{	my ($self, $field) = @_;

	my $known = $self->{MMH_fields};
	my $name  = $field->name;

	$self->addOrderedFields($field);

	if(defined $known->{$name})
	{	if(ref $known->{$name} eq 'ARRAY') { push @{$known->{$name}}, $field }
		else { $known->{$name} = [ $known->{$name}, $field ] }
	}
	else
	{	$known->{$name} = $field;
	}

	$field;
}

#--------------------
=section Error handling

=chapter DETAILS

=section Ordered header fields

Many Perl implementations make a big mistake by disturbing the order
of header fields.  For some fields (especially the I<resent groups>,
see Mail::Message::Head::ResentGroup) the order shall be
maintained.

MailBox will keep the order of the fields as they were found in the
source.  When your add a new field, it will be added at the end.  If
your replace a field with a new value, it will stay in the original
order.

=section Head class implementation

The header of a MIME message object contains a set of lines, which are
called I<fields> (by default represented by Mail::Message::Field
objects).  Dependent on the situation, the knowledge about the fields can
be in one of three situations, each represented by a sub-class of this
module:

=over 4

=item * Mail::Message::Head::Complete

In this case, it is sure that all knowledge about the header is available.
When you M<get()> information from the header and it is not there, it will
never be there.

=item * Mail::Message::Head::Subset

There is no certainty whether all header lines are known (probably not).  This
may be caused as result of reading a fast index file, as described in
Mail::Box::MH::Index.  The object is automatically transformed
into a Mail::Message::Head::Complete when all header lines must be known.

=item * Mail::Message::Head::Partial

A partial header is like a subset header: probably the header is incomplete.
The means that you are not sure whether a M<get()> for a field fails because
the field is not a part of the message or that it fails because it is not
yet known to the program.  Where the subset header knows where to get the
other fields, the partial header does not know it.  It cannot hide its
imperfection.

=item * Mail::Message::Head::Delayed

In this case, there is no single field known.  Access to this header will
always trigger the loading of the full header.

=back

=section Subsets of header fields

Message headers can be quite large, and therefore MailBox provides
simplified access to some subsets of information.  You can grab these
sets of fields together, create and delete them as group.

On the moment, the following sets are defined:

=over 4
=item * Mail::Message::Head::ResentGroup
A I<resent group> is a set of fields which is used to log one step
in the transmission of the message from the original sender to the
destination.

Each step adds a set of headers to indicate when the message was received
and how it was forwarded (without modification).  These fields are
best created using M<Mail::Message::bounce()>.

=item * Mail::Message::Head::ListGroup
Fields which are used to administer and log mailing list activity.  Mailing
list software has to play trics with the original message to be able to
get the reply on that message back to the mailing list.  Usually a large
number of lines are added.

=item * Mail::Message::Head::SpamGroup
A set of fields which contains header fields which are produced by
spam detection software.  You may want to remove these fields when
you store a message for a longer period of time.
=back

=cut

1;
