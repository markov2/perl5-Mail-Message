#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Field::DKIM;
use base 'Mail::Message::Field::Structured';

use warnings;
use strict;

use URI      ();

#--------------------
=chapter NAME

Mail::Message::Field::DKIM - message header field for dkim signatures

=chapter SYNOPSIS

  my $f = Mail::Message::Field->new('DKIM-Signature' => '...');

  my $g = Mail::Message::Field->new('DKIM-Signature');
  $g->add...

=chapter DESCRIPTION

Decode the information contained in a DKIM header.  You can also
construct DKIM-Signature headers this way.  However, verification
and signing is not yet implemented.

This implementation is based on RFC6376.

=chapter METHODS

=section Constructors

=c_method new $data

=default attributes <ignored>

=cut

sub init($)
{	my ($self, $args) = @_;
	$self->{MMFD_tags} = +{ v => 1, a => 'rsa-sha256' };

	$self->SUPER::init($args);
	$self;
}

sub parse($)
{	my ($self, $string) = @_;
	my $tags = $self->{MMFD_tags};

	foreach (split /\;/, $string)
	{	m/^\s*([a-z][a-z0-9_]*)\s*\=\s*([\s\x21-\x7E]+?)\s*$/is or next;
		# tag-values stay unparsed (for now)
		$self->addTag($1, $2);
	}

	(undef, $string) = $self->consumeComment($string);
	$self;
}

sub produceBody()
{	my $self = shift;
}

#--------------------
=section Access to the content

=cut

=method addAttribute ...
Attributes are not supported here.

=error No attributes for DKIM headers
Is is not possible to add attributes to this field.
=cut

sub addAttribute($;@)
{	my $self = shift;
	$self->log(ERROR => 'No attributes for DKIM headers.');
	$self;
}

=method addTag $name, $value|@values
Add a tag to the set.  When the tag already exists, it is replaced.
Names are (converted to) lower-case.  When multiple values are given,
they will be concatenated with a blank (and may get folded there later)

=cut

sub addTag($$)
{	my ($self, $name) = (shift, lc shift);
	$self->{MMFD_tags}{$name} = join ' ', @_;
	$self;
}

=method tag $name
Returns the value for the named tag.
=cut

sub tag($) { $_[0]->{MMFD_tags}{lc $_[1]} }


#--------------------
=subsection DKIM-Signature tags
The tag methods return the tag-value content without any validation
or modification.  For many situations, the actual content does not
need (expensive) validation and interpretation.

=method tagVersion
Signature header syntax version (usually 1)

=method tagAlgorithm
Signature algorithm.  Should be rsa-sha(1|256): check before use. Required.

=method tagSignData

=method tagSignature
Message signature in base64, with whitespaces removed. Required.

=method tagC14N
The canonicalization method used.  Defaults to 'simple/simple'.

=method tagDomain
The sub-domain (SDID) which claims responsibility for this signature. Required.

=method tagSignedHeaders
The colon separated list of headers which need to be included in the
signature.  Required.

=method tagAgentID
The Agent or User Identifier (AUID).  Defaults to C<@$domain>

=method tagBodyLength
The number of octets which where used to calculate the hash.  By default,
the whole body was used.

=method tagQueryMethods
A colon-separated list of method which can be used to retrieve the
public key.  The default is "dns/txt" (currently the only valid option)

=method tagSelector
The selector subdividing the domain tag.  Required.

=method tagTimestamp
When the signature was created in UNIX-like seconds (since 1970).  Recommended.

=method tagExpires
The timestamp when the signature will expire.  Recommended.

=method tagExtract
Some headers from the original message packed together.

=cut

sub tagAlgorithm() { $_[0]->tag('a') }
sub tagSignData()  { $_[0]->tag('b') }
sub tagSignature() { $_[0]->tag('bh') }
sub tagC14N()      { $_[0]->tag('c') }
sub tagDomain()    { $_[0]->tag('d') }
sub tagSignedHeaders() { $_[0]->tag('h') }
sub tagAgentID()   { $_[0]->tag('i') }
sub tagBodyLength(){ $_[0]->tag('l') }
sub tagQueryMethods()  { $_[0]->tag('q') }
sub tagSelector()  { $_[0]->tag('s') }
sub tagTimestamp() { $_[0]->tag('t') }
sub tagExpires()   { $_[0]->tag('x') }
sub tagVersion()   { $_[0]->tag('v') }
sub tagExtract()   { $_[0]->tag('z') }

#--------------------
=section Error handling
=cut

1;
