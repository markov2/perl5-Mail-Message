#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Message::Body::File;
use parent 'Mail::Message::Body';

use strict;
use warnings;

use Log::Report   'mail-message';

use Mail::Box::Parser ();
use Mail::Message     ();

use Carp;
use File::Temp qw/tempfile/;
use File::Copy qw/copy/;
use Fcntl      qw/SEEK_END/;

#--------------------
=chapter NAME

Mail::Message::Body::File - body of a message temporarily stored in a file

=chapter SYNOPSIS

  See Mail::Message::Body

=chapter DESCRIPTION

The body (content) of a message can be stored in various ways.  In this
documentation you find the description of extra functionality you have
when a message is stored in a file.

Storing a whole message is a file is useful when the body is large.  Although
access through a file is slower, it is saving a lot of memory.

=chapter METHODS

=c_method new %options

=error Unable to read file $filename for message body file: $!
A Mail::Message::Body::File object is to be created from a named file, but
it is impossible to read that file to retrieve the lines within.  Therefore,
no copy to a temporary file can be made.

=error Cannot write to temporary body file $filename: $!
The message body is to be stored in a temporary file (probably because it is a
large body), but for the indicated reason, this file cannot be created.

=cut

sub _data_from_filename(@)
{	my ($self, $filename) = @_;

	open my $in, '<:raw', $filename
		or $self->log(ERROR => "Unable to read file $filename for message body file: $!"), return;

	my $file   = $self->tempFilename;
	open my $out, '>:raw', $file
		or $self->log(ERROR => "Cannot write to temporary body file $file: $!"), return;

	my $nrlines = 0;
	local $_;
	while(<$in>) { $out->print($_); $nrlines++ }
	$self->{MMBF_nrlines} = $nrlines;
	$self;
}

sub _data_from_filehandle(@)
{	my ($self, $fh) = @_;
	my $file    = $self->tempFilename;
	my $nrlines = 0;

	open my $out, '>:raw', $file
		or $self->log(ERROR => "Cannot write to temporary body file $file: $!"), return;

	local $_;
	while(<$fh>)
	{	$out->print($_);
		$nrlines++;
	}

	$self->{MMBF_nrlines} = $nrlines;
	$self;
}

sub _data_from_lines(@)
{	my ($self, $lines) = @_;
	my $file = $self->tempFilename;

	open my $out, '>:raw', $file
		or $self->log(ERROR => "Cannot write to $file: $!"), return;

	$out->print(@$lines);

	$self->{MMBF_nrlines} = @$lines;
	$self;
}

sub clone()
{	my $self  = shift;
	my $clone = ref($self)->new(based_on => $self);

	copy $self->tempFilename, $clone->tempFilename
		or return;

	$clone->{MMBF_nrlines} = $self->{MMBF_nrlines};
	$clone->{MMBF_size}    = $self->{MMBF_size};
	$self;
}

sub nrLines()
{	my $self    = shift;

	return $self->{MMBF_nrlines}
		if defined $self->{MMBF_nrlines};

	my $file    = $self->tempFilename;
	my $nrlines = 0;

	open my $in, '<:raw', $file
		or die "Cannot read from $file: $!\n";

	local $_;
	$nrlines++ while <$in>;

	$self->{MMBF_nrlines} = $nrlines;
}

sub size()
{	my $self = shift;

	return $self->{MMBF_size}
		if exists $self->{MMBF_size};

	my $size = eval { -s $self->tempFilename };

	$size   -= $self->nrLines
		if $Mail::Message::crlf_platform;   # remove count for extra CR's

	$self->{MMBF_size} = $size;
}

sub string()
{	my $self = shift;
	my $file = $self->tempFilename;

	open my $in, '<:raw', $file
		or die "Cannot read from $file: $!\n";

	join '', $in->getlines;
}

sub lines()
{	my $self = shift;
	my $file = $self->tempFilename;

	open my $in, '<:raw', $file
		or die "Cannot read from $file: $!\n";

	my $r = $self->{MMBF_nrlines} = [ $in->getlines ];
	wantarray ? @$r: $r;
}

sub file()
{	my $self = shift;
	open my($tmp), '<:raw', $self->tempFilename;
	$tmp;
}

sub print(;$)
{	my $self = shift;
	my $fh   = shift || select;

	my $file = $self->tempFilename;
	open my $in, '<:raw', $file
		or croak "Cannot read from $file: $!\n";

	$fh->print($_) while <$in>;
	$in->close;

	$self;
}

sub endsOnNewline()
{	my $self = shift;

	my $file = $self->tempFilename;
	open my $in, '<:raw', $file
		or croak "Cannot read from $file: $!\n";

	$in->seek(-1, SEEK_END);
	$in->read(my $char, 1);
	$char eq "\n" || $char eq "\r";
}

sub read($$;$@)
{	my ($self, $parser, $head, $bodytype) = splice @_, 0, 4;
	my $file = $self->tempFilename;

	open my $out, '>:raw', $file
		or die "Cannot write to $file: $!.\n";

	(my $begin, my $end, $self->{MMBF_nrlines}) = $parser->bodyAsFile($out, @_);
	$out->close;

	$self->fileLocation($begin, $end);
	$self;
}

#--------------------
=section Internals

=method tempFilename [$filename]
Returns the name of the temporary file which is used to store this body.
=cut

sub tempFilename(;$)
{	my $self = shift;

	  @_                     ? ($self->{MMBF_filename} = shift)
	: $self->{MMBF_filename} ? $self->{MMBF_filename}
	:                          ($self->{MMBF_filename} = (tempfile)[1]);
}

#--------------------
=section Error handling

=section Cleanup

=method DESTROY
The temporary file is automatically removed when the body is
not required anymore.
=cut

sub DESTROY { unlink $_[0]->tempFilename }

1;
