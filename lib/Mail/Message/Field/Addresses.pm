#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Field::Addresses;
use parent 'Mail::Message::Field::Structured';

use strict;
use warnings;

use Log::Report   'mail-message';

use Mail::Message::Field::AddrGroup ();
use Mail::Message::Field::Address   ();

use List::Util      qw/first/;

#--------------------
=chapter NAME

Mail::Message::Field::Addresses - Fields with e-mail addresses

=chapter SYNOPSIS

  my $cc = Mail::Message::Field::Full->new('Cc');
  my $me = Mail::Message::Field::Address->parse('"Test" <test@mail.box>')
     or die;

  my $other = Mail::Message::Field::Address->new(phrase => 'Other',
        address => 'other@example.com')
     or die;

  $cc->addAddress($me);
  $cc->addAddress($other, group => 'them');
  $cc->addAddress(phrase => 'third', address => 'more@any.museum',
    group => 'them');

  my $group = $cc->addGroup(name => 'collegues');
  $group->addAddress($me);
  $group->addAddress(phrase => "You", address => 'you@example.com');

  my $msg = Mail::Message->build(Cc => $cc);
  print $msg->string;

  my $g  = Mail::Message::Field::AddrGroup->new(...);
  $cc->addGroup($g);

=chapter DESCRIPTION

All header fields which contain e-mail addresses only.  Not all address
fields have the same possibilities, but they are all parsed the same:
you never know how broken the applications are which produce those
messages.

When you try to create constructs which are not allowed for a certain
kind of field, you will be warned.

RFC5322 did allow address groups for "To" and "Cc", but not to be used
in (amongst other) "From" and "Sender" fields.  This restriction got
lifted by RFC6854 (2013).  L<https://www.rfc-editor.org/rfc/rfc6854>

=chapter METHODS

=c_method new
=default attributes <ignored>
=cut

# what is permitted for each field.

my $address_list = +{ groups => 1, multi => 1 };
my $mailbox_list = +{ multi => 1 };
my $mailbox      = +{ };

my %accepted     = (  # defaults to $address_list
	from   => $mailbox_list,
	sender => $mailbox,
);

sub init($)
{	my ($self, $args) = @_;

	$self->{MMFF_groups}   = [];

	my $def = lc $args->{name} =~ s/^resent\-//r;
	$self->{MMFF_defaults} = $accepted{$def} || $address_list;

	my ($body, @body);
	if($body = $args->{body})
	{	@body = ref $body eq 'ARRAY' ? @$body : ($body);
		@body or return ();
	}

	if(@body > 1 || ref $body[0])
	{	$self->addAddress($_) for @body;
		delete $args->{body};
	}

	$self->SUPER::init($args) or return;
	$self;
}

#--------------------
=section Access to the content

=method addAddress [$address], %options
Add an $address to the field.  The addresses are organized in groups.  If no
group is specified, the default group is taken to store the address in.  If
no $address is specified, the option must be sufficient to create a
Mail::Message::Field::Address from.  See the %options of
M<Mail::Message::Field::Address::new()>.

=option  group STRING
=default group C<''>

=cut

sub addAddress(@)
{	my $self  = shift;
	my $email = @_ && ref $_[0] ? shift : undef;
	my %args  = @_;
	my $group = delete $args{group} // '';

	$email  //= Mail::Message::Field::Address->new(%args);

	my $set = $self->group($group) // $self->addGroup(name => $group);
	$set->addAddress($email);
	$email;
}

=method addGroup $group|%options
Add a group of addresses to this field.  A $group can be specified, which
is a Mail::Message::Field::AddrGroup object, or one is created for you
using the %options.  The group is returned.

=option  name STRING
=default name C<''>

=cut

sub addGroup(@)
{	my $self  = shift;
	my $group = @_ == 1 ? shift : Mail::Message::Field::AddrGroup->new(@_);
	push @{$self->{MMFF_groups}}, $group;
	$group;
}

=method group $name
Returns the group of addresses with the specified $name, or undef
if it does not exist.  If $name is undef, then the default groep
is returned.
=cut

sub group($)
{	my ($self, $name) = @_;
	$name //= '';
	first { lc($_->name) eq lc($name) } $self->groups;
}

=method groups
Returns all address groups which are defined in this field.  Each
element is a Mail::Message::Field::AddrGroup object.
=cut

sub groups() { @{ $_[0]->{MMFF_groups}} }

=method groupNames
Returns a list with all group names which are defined.
=cut

sub groupNames() { map $_->name, $_[0]->groups }

=method addresses
Returns a list with all addresses defined in any group of addresses:
all addresses which are specified on the line.  The addresses are
Mail::Message::Field::Address objects.

=example
  my @addr = $field->addresses;

=cut

sub addresses() { map $_->addresses, $_[0]->groups }

=method addAttribute ...
Attributes are not supported for address fields.

=error No attributes for address fields.
Is is not possible to add attributes to address fields: it is not permitted
by the RFCs.
=cut

sub addAttribute($;@)
{	my $self = shift;
	$self->log(ERROR => 'No attributes for address fields.');
	$self;
}

#--------------------
=section Parsing
=cut

sub parse($)
{	my ($self, $string) = @_;
	my ($group, $email) = ('', undef);
	$string =~ s/\s+/ /gs;

  ADDRESS:
	while(1)
	{	(my $comment, $string) = $self->consumeComment($string);
		my $start_length = length $string;

		if($string =~ s/^\s*\;//s ) { $group = ''; next ADDRESS }  # end group
		if($string =~ s/^\s*\,//s ) { next ADDRESS}               # end address

		(my $email, $string) = $self->consumeAddress($string);
		if(defined $email)
		{	# Pattern starts with e-mail address
			($comment, $string) = $self->consumeComment($string);
			$email->comment($comment) if defined $comment;
		}
		else
		{	# Pattern not plain address
			my $real_phrase = $string =~ m/^\s*\"/;
			my @words;

			# In rfc2822 obs-phrase, we can have more than one word with
			# comments inbetween.
		WORD:
			while(1)
			{	(my $word, $string) = $self->consumePhrase($string);
				defined $word or last;

				push @words, $word if length $word;
				($comment, $string) = $self->consumeComment($string);

				if($string =~ s/^\s*\://s )
				{	$group = $word;
					# even empty groups must appear
					$self->addGroup(name => $group) unless $self->group($group);
					next ADDRESS;
				}
			}
			my $phrase = @words ? join ' ', @words : undef;

			my $angle;
			if($string =~ s/^\s*\<([^>]*)\>//s) { $angle = $1 }
			elsif($real_phrase)
			{	$self->log(WARNING => "Ignore unrelated phrase `$1'")
					if $string =~ s/^\s*\"(.*?)\r?\n//;
				next ADDRESS;
			}
			elsif(defined $phrase)
			{	($angle = $phrase) =~ s/\s+/./g;
				undef $phrase;
			}

			($comment, $string) = $self->consumeComment($string);

			# remove obsoleted route info.
			return 1 unless defined $angle;
			$angle =~ s/^\@.*?\://;

			($email, $angle) = $self->consumeAddress($angle, phrase => $phrase, comment => $comment);
		}

		$self->addAddress($email, group => $group) if defined $email;
		return 1 if $string =~ m/^\s*$/s;

		# Do not get stuck on illegal characters
		last if $start_length == length $string;
	}

	$self->log(WARNING => 'Illegal part in address field '.$self->Name. ": $string\n");

	0;
}

sub produceBody()
{	my @groups = sort {$a->name cmp $b->name} shift->groups;

	@groups     or return '';
	@groups > 1 or return $groups[0]->string;

	my $plain = $groups[0]->name eq '' && $groups[0]->addresses ? (shift @groups)->string.',' : '';
	join ' ', $plain, (map $_->string, @groups);
}

=method consumeAddress STRING, %options
Try to destilate address information from the STRING.   Returned are
an address B<object> and the left-over string.  If no address was found,
the first returned value is undef.
=cut

sub consumeAddress($@)
{	my ($self, $string, @options) = @_;

	my ($local, $shorter, $loccomment);
	if($string =~ s/^\s*"((?:\\.|[^"])*)"\s*\@/@/)
	{	# local part is quoted-string rfc2822
		($local, $shorter) = ($1, $string);
		$local =~ s/\\"/"/g;
	}
	else
	{	($local, $shorter, $loccomment) = $self->consumeDotAtom($string);
		$local =~ s/\s//g if defined $local;
	}

	defined $local && $shorter =~ s/^\s*\@//
		or return (undef, $string);

	(my $domain, $shorter, my $domcomment) = $self->consumeDomain($shorter);
	defined $domain
		or return (undef, $string);

	# loccomment and domcomment ignored
	my $email = Mail::Message::Field::Address->new(username => $local, domain => $domain, @options);
	($email, $shorter);
}

=method consumeDomain STRING
Try to get a valid domain representation from STRING.  Returned are the
domain string as found (or undef) and the rest of the string.
=cut

sub consumeDomain($)
{	my ($self, $string) = @_;

	return ($self->stripCFWS($1), $string)
		if $string =~ s/\s*(\[(?:[^[]\\]*|\\.)*\])//;

	my ($atom, $rest, $comment) = $self->consumeDotAtom($string);
	$atom =~ s/\s//g if defined $atom;
	($atom, $rest, $comment);
}

#--------------------
=section Error handling
=cut

1;
