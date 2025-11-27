#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Box::Parser;
use parent 'Mail::Reporter';

use strict;
use warnings;

use Log::Report   'mail-message';

#--------------------
=chapter NAME

Mail::Box::Parser - reading and writing messages

=chapter SYNOPSIS

  # Not instatiatiated itself

=chapter DESCRIPTION

The C<Mail::Box::Parser> manages the parsing of folders.  Usually, you won't
need to know anything about this module, except the options which are
involved with this code.

There are currently three implementations of this module:

=over 4

=item * M<Mail::Box::Parser::C>
A fast parser written in C<C>.  This package is released as separate
module on CPAN, because the module distribution via CPAN can not
handle XS files which are not located in the root directory of the
module tree.  If a C compiler is available on your system, it will be
used automatically.

=item * Mail::Box::Parser::Perl
A slower parser when the message is in a file, like mbox, which only
uses plain Perl.  This module is a bit slower, and does less checking
and less recovery.

=item * Mail::Box::Parser::Lines
Useful when the message is already in memory.  When you plan to use this
yourself, you probably need to use Mail::Message::Construct::Read.
=back

=chapter METHODS

=c_method new %options

Create a parser object which can handle one file.  For
mbox-like mailboxes, this object can be used to read a whole folder.  In
case of MH-like mailboxes, each message is contained in a single file,
so each message has its own parser object.

=option  trusted BOOLEAN
=default trusted false
Is the input from the file to be trusted, or does it require extra
tests.  Related to M<Mail::Box::new(trusted)>.

=option  fix_header_errors BOOLEAN
=default fix_header_errors false
When header errors are detected, the parsing of the header will
be stopped.  Other header lines will become part of the body of
the message.  Set this flag to have the erroneous line added to
the previous header line.

=error Filename or handle required to create a parser.
A message parser needs to know the source of the message at creation.  These
sources can be a filename (string), file handle object, or GLOB.
See new(filename) and new(file).

=cut

sub new(@)
{	my $class = shift;

	  $class eq __PACKAGE__
	? $class->defaultParserType->new(@_)   # bootstrap right parser
	: $class->SUPER::new(@_);
}

sub init(@)
{	my ($self, $args) = @_;
	$self->SUPER::init($args);

	$self->{MBP_trusted}  = $args->{trusted};
	$self->{MBP_fix}      = $args->{fix_header_errors};
	$self->{MBP_seps}     = [];
	$self;
}

#--------------------
=section Attributes

=method fixHeaderErrors [BOOLEAN]
If set to true, parsing of a header will not stop on an error, but
attempt to add the erroneous this line to previous field.  Without BOOLEAN,
the current setting is returned.

=example
  $folder->parser->fixHeaderErrors(1);
  my $folder = $mgr->open('folder', fix_header_errors => 1);
=cut

sub fixHeaderErrors(;$)
{	my $self = shift;
	@_ ? ($self->{MBP_fix} = shift) : $self->{MBPL_fix};
}

=method trusted
Trust the source of the data: do not run additional tests.
=cut

sub trusted() { $_[0]->{MBP_trusted} }

=ci_method defaultParserType [$class]
Returns the parser to be used to parse all subsequent
messages, possibly first setting the parser using the optional argument.
Usually, the parser is autodetected; the C<C>-based parser will be used
when it can be, and the Perl-based parser will be used otherwise.

The $class argument allows you to specify a package name to force a
particular parser to be used (such as your own custom parser). You have
to C<use> or C<require> the package yourself before calling this method
with an argument. The parser must be a sub-class of C<Mail::Box::Parser>.
=cut

my $parser_type;

sub defaultParserType(;$)
{	my $class = shift;

	# Select the parser manually?
	if(@_)
	{	$parser_type = shift;
		return $parser_type if $parser_type->isa( __PACKAGE__ );
		panic "Parser $parser_type does not extend " . __PACKAGE__;
	}

	# Already determined which parser we want?
	$parser_type
		and return $parser_type;

	# Try to use C-based parser.
	eval 'require Mail::Box::Parser::C';
	$@ or return $parser_type = 'Mail::Box::Parser::C';

	# Fall-back on Perl-based parser.
	require Mail::Box::Parser::Perl;
	$parser_type = 'Mail::Box::Parser::Perl';
}

#--------------------
=section Parsing

=method readHeader
Read the whole message-header and return it as list of field-value
pairs.  Mind that some fields will appear more than once.

The first element will represent the position in the file where the
header starts.  The follows the list of header field names and bodies.

=example
  my ($where, @header) = $parser->readHeader;

=warning Unexpected end of header in $source: $line
While parsing a message from the specified source (usually a file name),
the parser found a syntax error.  According to the MIME specification in the
RFCs, each header line must either contain a colon, or start with a blank
to indicate a folded field.  Apparently, this header contains a line which
starts on the first position, but not with a field name.

By default, parsing of the header will be stopped.  If there are more header
lines after the erroneous line, they will be added to the body of the message.
In case of M<new(fix_header_errors)> set, the parsing of the header will be continued.
The erroneous line will be added to the preceding field.
=cut

sub readHeader()    { $_[0]->notImplemented }

=method bodyAsString [$chars, [$lines]]
Try to read one message-body from the file.  Optionally, the predicted number
of CHARacterS and/or $lines to be read can be supplied.  These values may be
undef and may be wrong.

Returned is a list of three scalars: the location in the file
where the body starts, where the body ends, and the string containing the
whole body.
=cut

sub bodyAsString() { $_[0]->notImplemented }

=method bodyAsList [$chars, [$lines]]
Try to read one message-body from the file.  Optionally, the predicted number
of CHARacterS and/or $lines to be read can be supplied.  These values may be
undef and may be wrong.

The return is a list of scalars, each containing one line (including
line terminator), preceded by two integers representing the location
in the file where this body started and ended.
=cut

sub bodyAsList() { $_[0]->notImplemented }

=method bodyAsFile $fh [$chars, [$lines]]
Try to read one message-body from the file, and immediately write
it to the specified file-handle.  Optionally, the predicted number
of CHARacterS and/or $lines to be read can be supplied.  These values may be
undef and may be wrong.

The return is a list of three scalars: the location of the body (begin
and end) and the number of lines in the body.
=cut

sub bodyAsFile() { $_[0]->notImplemented }

=method bodyDelayed [$chars, [$lines]]
Try to read one message-body from the file, but the data is skipped.
Optionally, the predicted number of CHARacterS and/or $lines to be skipped
can be supplied.  These values may be undef and may be wrong.

The return is a list of four scalars: the location of the body (begin and
end), the size of the body, and the number of lines in the body.  The
number of lines may be undef.
=cut

sub bodyDelayed() { $_[0]->notImplemented }

=method lineSeparator
Returns the character or characters which are used to separate lines
in the folder file.  This is based on the first line of the file.
UNIX systems use a single LF to separate lines.  Windows uses a CR and
a LF.  Mac uses CR.

=cut

sub lineSeparator() { $_[0]->{MBP_linesep} }

=method stop
Stop the parser.
=cut

sub stop() { }
sub filePosition() { undef }

#--------------------
=subsection Administering separators
The various "separators" methods are used by Mail::Message::Body::Multipart
to detect parts, and for the file based mailboxes to flag where the new message
starts.

=method readSeparator %options
Read the currently active separator (the last one which was pushed).  The
line (or undef) is returned.  Blank-lines before the separator lines
are ignored.

The return are two scalars, where the first gives the location of the
separator in the file, and the second the line which is found as
separator.  A new separator is activated using M<pushSeparator()>.
=cut

sub readSeparator() { $_[0]->notImplemented }

=method pushSeparator STRING|Regexp
Add a boundary line.  Separators tell the parser where to stop reading.
A famous separator is the C<From>-line, which is used in Mbox-like
folders to separate messages.  But also parts (I<attachments>) is a
message are divided by separators.

The specified STRING describes the start of the separator-line.  The
Regexp can specify a more complicated format.
=cut

sub pushSeparator($)
{	my ($self, $sep) = @_;
	unshift @{$self->{MBP_seps}}, $sep;
	$self->{MBP_strip_gt}++ if $sep eq 'From ';
	$self;
}

=method popSeparator
Remove the last-pushed separator from the list which is maintained by the
parser.  This will return undef when there is none left.
=cut

sub popSeparator()
{	my $self = shift;
	my $sep  = shift @{$self->{MBP_seps}};
	$self->{MBP_strip_gt}-- if $sep eq 'From ';
	$sep;
}

=method separators
=method activeSeparator
=method resetSeparators
=method stripGt
=cut

sub separators()      { $_[0]->{MBP_seps} }
sub activeSeparator() { $_[0]->separators->[0] }
sub resetSeparators() { $_[0]->{MBP_seps} = []; $_[0]->{MBP_strip_gt} = 0 }
sub stripGt           { $_[0]->{MBP_strip_gt} }

#--------------------
=section Error handling
=cut

#--------------------
=section Cleanup
=cut

1;
