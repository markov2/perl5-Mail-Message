# This code is part of distribution Mail-Message.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Mail::Box::Parser::Perl;
use base 'Mail::Box::Parser';

use strict;
use warnings;

use Mail::Message::Field;
use List::Util 'sum';
use IO::File;

my $empty_line = qr/^\015?\012?$/;

=chapter NAME

Mail::Box::Parser::Perl - reading messages from file using Perl

=chapter SYNOPSIS

=chapter DESCRIPTION

The C<Mail::Box::Parser::Perl> implements parsing of messages
in Perl.  This may be a little slower than the C<C> based parser
M<Mail::Box::Parser::C>, but will also work on platforms where no C
compiler is available.

=chapter METHODS

=c_method new %options

=requires  filename FILENAME
The name of the file to be read.

=option  file FILE-HANDLE
=default file undef
Any C<IO::File> or C<GLOB> file-handle which can be used to read
the data from.  In case this option is specified, the C<filename> is
informational only.

=option  mode OPENMODE
=default mode C<'r'>
File-open mode, which defaults to C<'r'>, which means `read-only'.
See C<perldoc -f open> for possible modes.  Only applicable
when no C<file> is specified.

=cut

sub init(@)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    $self->{MBPP_mode}     = $args->{mode} || 'r';
    $self->{MBPP_filename} = $args->{filename} || ref $args->{file}
        or $self->log(ERROR => "Filename or handle required to create a parser."), return;

    $self->start(file => $args->{file});
    $self;
}

#----------------------
=section Attributes

=method filename
Returns the name of the file this parser is working on.

=method openMode
=method file
=cut

sub filename() { $_[0]->{MBPP_filename} }
sub openMode() { $_[0]->{MBPP_mode} }
sub file()     { $_[0]->{MBPP_file} }

#----------------------
=section Parsing

=method start %options
Start the parser by opening a file.

=option  file FILEHANDLE|undef
=default file undef
The file is already open, for instance because the data must be read
from STDIN.
=cut

sub start(@)
{   my ($self, %args) = @_;
    $self->openFile(%args) or return;
    $self->takeFileInfo;

    $self->log(PROGRESS => "Opened folder ".$self->filename." to be parsed");
    $self;
}

=method stop
Stop the parser, which will include a close of the file.  The lock on the
folder will not be removed (is not the responsibility of the parser).

=warning File $file changed during access.
When a message parser starts working, it takes size and modification time
of the file at hand.  If the folder is written, it checks whether there
were changes in the file made by external programs.

Calling M<Mail::Box::update()> on a folder before it being closed
will read these new messages.  But the real source of this problem is
locking: some external program (for instance the mail transfer agent,
like sendmail) uses a different locking mechanism as you do and therefore
violates your rights.

=cut

sub stop()
{   my $self = shift;
    $self->log(NOTICE  => "Close parser for file ".$self->filename);
    $self->closeFile;
}

=method restart %options
Restart the parser on a certain file, usually because the content has
changed.  The C<%options> are passed to M<openFile()>.
=cut

sub restart()
{   my $self     = shift;
    $self->closeFile;
    $self->openFile(@_) or return;
    $self->takeFileInfo;
    $self->log(NOTICE  => "Restarted parser for file ".$self->filename);
    $self;
}

=method fileChanged
Returns whether the file which is parsed has changed after the last
time takeFileInfo() was called.
=cut

sub fileChanged()
{   my $self = shift;
    my ($size, $mtime) = (stat $self->filename)[7,9];
    return 0 if !defined $size || !defined $mtime;
    $size != $self->{MBPP_size} || $mtime != $self->{MBPP_mtime};
}

=method filePosition [$position]
Returns the location of the next byte to be used in the file which is
parsed.  When a $position is specified, the location in the file is
moved to the indicated spot first.
=cut

sub filePosition(;$)
{   my $self = shift;
    @_ ? $self->file->seek(shift, 0) : $self->file->tell;
}

sub readHeader()
{   my $self  = shift;
    my $file  = $self->file;
    my @ret   = ($file->tell, undef);
    my $line  = $file->getline;

  LINE:
    while(defined $line)
    {   last LINE if $line =~ $empty_line;
        my ($name, $body) = split /\s*\:\s*/, $line, 2;

        unless(defined $body)
        {   $self->log(WARNING => "Unexpected end of header in ".$self->filename.":\n $line");

            if(@ret && $self->fixHeaderErrors)
            {   $ret[-1][1] .= ' '.$line;  # glue err line to previous field
                $line = $file->getline;
                next LINE;
            }
            else
            {   $file->seek(-length $line, 1);
                last LINE;
            }
        }

        length $body or $body = "\n";

        # Collect folded lines
        while($line = $file->getline)
        {   $line =~ m!^[ \t]! ? ($body .= $line) : last;
        }

        $body =~ s/\015//g;
        push @ret, [ $name, $body ];
    }

    $ret[1]  = $file->tell;
    @ret;
}

sub _is_good_end($)
{   my ($self, $where) = @_;

    # No seps, then when have to trust it.
    my $sep  = $self->activeSeparator // return 1;
    my $file = $self->file;
    my $here = $file->tell;
    $file->seek($where, 0) or return 0;

    # Find first non-empty line on specified location.
    my $line = $file->getline;
    $line    = $file->getline while defined $line && $line =~ $empty_line;

    # Check completed, return to old spot.
    $file->seek($here, 0);
    $line // return 1;

        substr($line, 0, length $sep) eq $sep
    && ($sep ne 'From ' || $line =~ m/ (?:19[6-9]|20[0-3])[0-9]\b/ );
}

sub readSeparator()
{   my $self  = shift;
    my $sep   = $self->activeSeparator // return ();
    my $file  = $self->file;
    my $start = $file->tell;

    my $line  = $file->getline;
    while(defined $line && $line =~ $empty_line)
    {   $start = $file->tell;
        $line  = $file->getline;
    }

    $line // return ();
    $line      =~ s/[\012\015]+$/\n/;

    substr($line, 0, length $sep) eq $sep
        and return ($start, $line);

    $file->seek($start, 0);
    ();
}

sub _read_stripped_lines(;$$)
{   my ($self, $exp_chars, $exp_lines) = @_;
    my $seps    = $self->separators;
    my $file    = $self->file;
    my $lines   = [];
    my $msgend;

    if(@$seps)
    {   
       LINE:
        while(1)
        {   my $where = $file->getpos;
            my $line  = $file->getline or last LINE;

            foreach my $sep (@$seps)
            {   substr($line, 0, length $sep) eq $sep or next;

                # Some apps fail to escape lines starting with From
                next if $sep eq 'From ' && $line !~ m/ 19[789][0-9]| 20[0-9][0-9]/;

                $file->setpos($where);
                $msgend = $file->tell;
                last LINE;
            }

            push @$lines, $line;
        }

        if(@$lines && $lines->[-1] =~ s/\015?\012\z//)
        {   # Keep an empty line to signal the existence of a preamble, but
            # remove a second.
            pop @$lines if @$seps==1 && @$lines > 1 && length($lines->[-1])==0;
        }
    }
    else # File without separators.
    {   $lines = ref $file eq 'Mail::Box::FastScalar' ? $file->getlines : [ $file->getlines ];
    }

    my $bodyend = $file->tell;
    if($self->stripGt)
    {   s/^\>(\>*From\s)/$1/ for @$lines;
    }

    unless($self->trusted)
    {   s/\015$// for @$lines;
        # input is read as binary stream (i.e. preserving CRLF on Windows).
        # Code is based on this assumption. Removal of CR if not trusted
        # conflicts with this assumption. [Markus Spann]
    }

    ($bodyend, $lines, $msgend);
}

sub _take_scalar($$)
{   my ($self, $begin, $end) = @_;
    my $file = $self->file;
    $file->seek($begin, 0);

    my $buffer;
    $file->read($buffer, $end-$begin);
    $buffer =~ s/\015//gr;
}

sub bodyAsString(;$$)
{   my ($self, $exp_chars, $exp_lines) = @_;
    my $file  = $self->file;
    my $begin = $file->tell;

    if(defined $exp_chars && $exp_chars>=0)
    {   # Get at once may be successful
        my $end = $begin + $exp_chars;

        if($self->_is_good_end($end))
        {   my $body = $self->_take_scalar($begin, $end);
            $body =~ s/^\>(\>*From\s)/$1/gm if $self->stripGt;
            return ($begin, $file->tell, $body);
        }
    }

    my ($end, $lines) = $self->_read_stripped_lines($exp_chars, $exp_lines);
    ($begin, $end, join('', @$lines));
}

sub bodyAsList(;$$)
{   my ($self, $exp_chars, $exp_lines) = @_;
    my $file  = $self->file;
    my $begin = $file->tell;

    my ($end, $lines) = $self->_read_stripped_lines($exp_chars, $exp_lines);
    ($begin, $end, $lines);
}

sub bodyAsFile($;$$)
{   my ($self, $out, $exp_chars, $exp_lines) = @_;
    my $file  = $self->file;
    my $begin = $file->tell;

    my ($end, $lines) = $self->_read_stripped_lines($exp_chars, $exp_lines);

    $out->print($_) for @$lines;
    ($begin, $end, scalar @$lines);
}

sub bodyDelayed(;$$)
{   my ($self, $exp_chars, $exp_lines) = @_;
    my $file  = $self->file;
    my $begin = $file->tell;

    if(defined $exp_chars)
    {   my $end = $begin + $exp_chars;

        if($self->_is_good_end($end))
        {   $file->seek($end, 0);
            return ($begin, $end, $exp_chars, $exp_lines);
        }
    }

    my ($end, $lines) = $self->_read_stripped_lines($exp_chars, $exp_lines);
    my $chars = sum(map length, @$lines);
    ($begin, $end, $chars, scalar @$lines);
}

=method openFile %options
[3.012] Open the file to be parsed.
=cut

sub openFile(%)
{   my ($self, %args) = @_;

    my $fh = $self->{MBPP_file} = $args{file} ||
        IO::File->new($self->filename, $args{mode} || $self->openMode)
        or return;

    $fh->binmode(':raw')
        if $fh->can('binmode') || $fh->can('BINMODE');

    $self->resetSeparators;
    $self;
}

=method closeFile
Close the file which was being parsed.
=cut

sub closeFile()
{   my $self = shift;
    $self->resetSeparators;

    my $file = delete $self->{MBPP_file} or return;
    $file->close;
    $self;
}

=method takeFileInfo
Capture some data about the file being parsed, to be compared later.
=cut

sub takeFileInfo()
{   my $self = shift;
    @$self{ qw/MBPP_size MBPP_mtime/ } = (stat $self->filename)[7,9];
}

#------------------------------------------
=section Error handling
=cut

#------------------------------------------
=section Cleanup
=cut

sub DESTROY
{   my $self = shift;
    $self->stop;
    $self->SUPER::DESTROY;
}

1;
