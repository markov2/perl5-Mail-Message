# This code is part of distribution Mail-Message.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Mail::Box::FastScalar;

use strict;
use warnings;
use integer;

=chapter NAME

Mail::Box::FastScalar - fast alternative to IO::Scalar

=chapter DESCRIPTION

Extremely fast L<IO::Scalar> replacement - >20x improvement in
C<getline()> and C<getlines()> methods.

Contributed by "Todd Richmond" (richmond@proofpoint.com)

=section Warnings

You cannot modify the original reference between calls unless you
C<$obj->seek(1, 0)> to reset the object - VERY rare usage case.

$/ must be undef or string - "" and \scalar unimplemented

=cut

sub new($)
{   my ($class, $ref) = @_;
    $$ref //= '';
    bless { ref => $ref, pos => 0 }, $class;
}

sub autoflush() {}
sub binmode()   {}
sub clearerr    { 0 }
sub flush()     {}
sub sync()      { 0 }
sub opened()    { $_[0]->{ref} }

sub open($) {
    my $self = $_[0];
    ${$_[1]} //= '';
    $self->{ref} = $_[1];
    $self->{pos} = 0;
}

sub close() { undef $_[0]->{ref} }

sub eof() {
    my $self = $_[0];
    $self->{pos} >= length ${$self->{ref}};
}

sub getc() {
    my $self = $_[0];
    substr(${$self->{ref}}, $self->{pos}++, 1);
}

sub print
{   my $self = shift;
    my $pos = $self->{pos};
    my $ref = $self->{ref};
    my $len = length($$ref);
    
    if ($pos >= $len)
    {   $$ref .= $_ for @_;
        $self->{pos} = length($$ref);
    }
    else
    {   my $buf = $#_ ? join('', @_) : $_[0];
        $len = length $buf;
        substr($$ref, $pos, $len) = $buf;
        $self->{pos} = $pos + $len;
    }

    1;
}

sub read($$;$)
{   my $self = $_[0];
    my $buf  = substr(${$self->{ref}}, $self->{pos}, $_[2]);
    $self->{pos} += $_[2];

    ($_[3] ? substr($_[1], $_[3]) : $_[1]) = $buf;
    length $buf;
}

sub sysread($$;$) { $_[0]->read(@_) }

sub seek($$)
{   my ($self, $delta, $whence) = @_;
    my $len    = length ${$self->{ref}};

       if ($whence == 0) { $self->{pos} = $delta }
    elsif ($whence == 1) { $self->{pos} += $delta }
    elsif ($whence == 2) { $self->{pos} = $len + $delta }
    else { return }

       if($self->{pos} > $len) { $self->{pos} = $len }
    elsif($self->{pos} < 0)    { $self->{pos} = 0 }

    1;
}

sub sysseek($$) { $_[0]->seek($_[1], $_[2]) }
sub setpos($)   { $_[0]->seek($_[1], 0) }
sub sref()      { $_[0]->{ref} }
sub getpos()    { $_[0]->{pos} }
sub tell()      { $_[0]->{pos} }

sub write($$;$)
{   my $self = $_[0];
    my $pos = $self->{pos};
    my $ref = $self->{ref};
    my $len = length $$ref;

    if($pos >= $len)
    {   $$ref .= substr($_[1], $_[3] || 0, $_[2]);
        $self->{pos} = length $$ref;
        $len = $self->{pos} -  $len;
    }
    else
    {   my $buf = substr($_[1], $_[3] || 0, $_[2]);
        $len    = length $buf;
        substr($$ref, $pos, $len) = $buf;
        $self->{pos} = $pos + $len;
    }

    $len;
}

sub syswrite($;$$) { $_[0]->write(@_) }

sub getline()
{   my $self = shift;
    my $ref  = $self->{ref};
    my $pos  = $self->{pos};

	my $idx;
    if( !defined $/ || ($idx = index($$ref, $/, $pos)) == -1)
    {   return if $pos >= length $$ref;
        $self->{pos} = length $$ref;
        return substr $$ref, $pos;
    }

    substr $$ref, $pos, ($self->{pos} = $idx + length($/)) - $pos;
}

sub getlines()
{   my $self = $_[0];
    my $ref = $self->{ref};
    my $pos = $self->{pos};

    my @lines;
    if(defined $/)
    {   my $idx;
        while(($idx = index($$ref, $/, $pos)) != -1)
        {   push @lines, substr($$ref, $pos, ($idx + 1) - $pos);
            $pos = $idx + 1;
        }
    }
    my $r = substr $$ref, $pos;
    push @lines, $r if length $r > 0;

    $self->{pos} = length $$ref;
    wantarray ? @lines : \@lines;
}

# Call OO, because this module might be extended
sub TIEHANDLE { defined $_[1] && UNIVERSAL::isa($_[1], __PACKAGE__) ? $_[1] : shift->new(@_) }
sub GETC      { shift->getc(@_) }
sub PRINT     { shift->print(@_) }
sub PRINTF    { shift->print(sprintf shift, @_) }
sub READ      { shift->read(@_) }
sub READLINE  { wantarray ? shift->getlines(@_) : shift->getline(@_) }
sub WRITE     { shift->write(@_) }
sub CLOSE     { shift->close(@_) }
sub SEEK      { shift->seek(@_) }
sub TELL      { shift->tell(@_) }
sub EOF       { shift->eof(@_) }

1;
