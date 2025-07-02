# This code is part of distribution Mail-Message.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Mail::Message::Body;
use base 'Mail::Reporter';

use strict;
use warnings;
use utf8;

use Carp;
use MIME::Types    ();
use File::Basename 'basename';
use Encode         qw/find_encoding from_to encode_utf8/;
use List::Util     qw/first/;

use Mail::Message::Field        ();
use Mail::Message::Field::Full  ();

# http://www.iana.org/assignments/character-sets
use Encode::Alias;
define_alias(qr/^unicode-?1-?1-?utf-?([78])$/i => '"UTF-$1"');  # rfc1642

my $mime_types;

=chapter NAME

Mail::Message::Body::Encode - organize general message encodings

=chapter SYNOPSIS

 my Mail::Message $msg = ...;
 my $decoded = $msg->decoded;
 my $encoded = $msg->encode(mime_type => 'image/gif',
     transfer_encoding => 'base64');

 my $body = $msg->body;
 my $decoded = $body->decoded;
 my $encoded = $body->encode(transfer_encoding => '7bit');

=chapter DESCRIPTION

Manages the message's body encodings and decodings on request of the
main program.  This package adds functionality to the M<Mail::Message::Body>
class when the M<decoded()> or M<encode()> method is called.

Four types of encodings are handled (in the right order)

=over 4

=item * eol encoding

Various operating systems have different ideas about how to encode the
line termination.  UNIX uses a LF character, MacOS uses a CR, and
Windows uses a CR/LF combination.  Messages which are transported over
Internet will always use the CRLF separator.

=item * transfer encoding

Messages transmitted over Internet have to be plain ASCII.  Complicated
characters and binary files (like images and archives) must be encoded
during transmission to an ASCII representation.

The implementation of the required encoders and decoders is found in
the M<Mail::Message::TransferEnc> set of packages.  The related
manual page lists the transfer encodings which are supported.

=item * mime-type translation

NOT IMPLEMENTED YET

=item * charset conversion

=back

=chapter METHODS
=cut

#------------------
=section Attributes

=method charsetDetectAlgorithm [CODE|undef|METHOD]
[3.013] When a body object does not specify its character-set, but that
detail is required, then it gets autodetected.  The default algorithm is
implemented in M<charsetDetect()>.  You may change this default algorithm,
or pass option C<charset_detect> for each call to M<encode()>.

When you call this method with an explicit C<undef>, you reset the default.
(Without parameter) the current algorithm (CODE or method name) is
returned.
=cut

sub charsetDetectAlgorithm(;$)
{   my $self = shift;
    $self->{MMBE_det} = shift if @_;
    $self->{MMBE_det} || 'charsetDetect';
}

#------------------
=section Constructing a body

=method encode %options
Encode (translate) a M<Mail::Message::Body> into a different format.
See the DESCRIPTION above.  Options which are not specified will not trigger
conversions.

=option  charset CHARSET|'PERL'
=default charset C<PERL>
Only applies when the mime_type is textual.

If the CHARSET is explicitly specified (for instance C<iso-8859-10>, then
the data is being interpreted as raw bytes (blob), not as text.  However, in
case of C<PERL>, it is considered to be an internal representation of
characters (either latin1 or Perl's utf8 --not the same as utf-8--, you should
not want to know).

This setting overrules the charset attribute in the mime_type FIELD.

=option  mime_type STRING|FIELD
=default mime_type undef
Convert into the specified mime type, which can be specified as STRING
or FIELD.  The FIELD is a M<Mail::Message::Field>-object, representing a
C<Content-Type> mime header.  The STRING must be valid content for such
header, and will be converted into a FIELD object.

The FIELD may contain attributes.  Usually, it has a C<charset> attribute,
which explains the CHARSET of the content after content transfer decoding.
The C<charset> option will update/add this attribute.  Otherwise (hopefully
in rare cases) the CHARSET will be auto-detected when the body gets
decoded.

=option  result_type CLASS
=default result_type <same as source>
The type of body to be created when the body is changed to fulfill the request
on re-coding.  Also the intermediate stages in the translation process (if
needed) will use this type. CLASS must extend M<Mail::Message::Body>.

=option  transfer_encoding STRING|FIELD
=default transfer_encoding undef

=option  charset_detect CODE
=default charset_detect <built-in>
[3.013] When the body does not contain an explicit charset specification,
then the RFC says it is C<us-ascii>.  In reality, this is not true:
it is just an unknown character set. This often happens when text files
are included as attachment, for instance a footer attachment.

When you want to be smarter than the default charset detector, you can
provide your own function for this parameter.  The function will get
the transfer-decoded version of this body.  You can change the default
globally via M<charsetDetectAlgorithm()>.

=warning No decoder defined for transfer encoding $name.
The data (message body) is encoded in a way which is not currently understood,
therefore no decoding (or recoding) can take place.

=warning No encoder defined for transfer encoding $name.
The data (message body) has been decoded, but the required encoding is
unknown.  The decoded data is returned.

=warning Charset $name is not known
The encoding or decoding of a message body encounters a character set which
is not understood by Perl's M<Encode> module.

=cut

sub _char_enc($)
{   my ($self, $charset) = @_;
    return undef if !$charset || $charset eq 'PERL';

    my $enc = find_encoding $charset
        or $self->log(WARNING => "Charset `$charset' is not known.");

    $enc;
}

sub encode(@)
{   my ($self, %args) = @_;

    my $bodytype  = $args{result_type} || ref $self;

    ### The content type

    my $type_from = $self->type;
    my $type_to   = $args{mime_type} || $type_from->clone->study;
    $type_to = Mail::Message::Field::Full->new('Content-Type' => $type_to)
        unless ref $type_to;

    ### Detect specified transfer-encodings

    my $transfer = $args{transfer_encoding} || $self->transferEncoding->clone;
    $transfer    = Mail::Message::Field->new('Content-Transfer-Encoding' => $transfer)
        unless ref $transfer;

    my $trans_was = lc $self->transferEncoding;
    my $trans_to  = lc $transfer;

    ### Detect specified charsets

    my $is_text = $type_from =~ m!^text/!i;
    my ($char_was, $char_to, $from, $to);
    if($is_text)
    {   $char_was = $type_from->attribute('charset');  # sometimes missing
        $char_to  = $type_to->attribute('charset');    # usually missing

        if(my $charset = delete $args{charset})
        {   # Explicitly stated output charset
            if(!$char_to || $char_to ne $charset)
            {   $char_to = $charset;
                $type_to->attribute(charset => $char_to);
            }
        }
        elsif(!$char_to && $char_was)
        {   # By default, do not change charset
            $char_to = $char_was;
            $type_to->attribute(charset => $char_to);
        }

        if($char_to && $trans_to ne 'none' && $char_to eq 'PERL')
        {   # We cannot leave the body into the 'PERL' charset when transfer-
            # encoding is applied.
            $self->log(WARNING => "Transfer-Encoding `$trans_to' requires "
              . "explicit charset, defaulted to utf-8");
            $char_to = 'utf-8';
        }

        $from = $self->_char_enc($char_was);
        $to   = $self->_char_enc($char_to);

        if($from && $to)
        {   if($char_was ne $char_to && $from->name eq $to->name)
            {   # modify source charset into a different alias
                $type_from->attribute(charset => $char_to);
                $char_was = $char_to;
                $from     = $to;
            }

            return $self
                if $trans_was eq $trans_to && $char_was eq $char_to;
        }
    }
    elsif($trans_was eq $trans_to)
    {   # No changes needed;
        return $self;
    }

    ### Apply transfer-decoding

    my $decoded;
    if($trans_was eq 'none')
    {   $decoded = $self }
    elsif(my $decoder = $self->getTransferEncHandler($trans_was))
    {   $decoded = $decoder->decode($self, result_type => $bodytype) }
    else
    {   $self->log(WARNING =>
           "No decoder defined for transfer encoding $trans_was.");
        return $self;
    }

    ### Apply character-set recoding

    my $recoded;
    if($is_text)
    {   unless($char_was)
        {   # When we do not know the character-sets, try to auto-detect
            my $auto = $args{charset_detect} || $self->charsetDetectAlgorithm;
            $char_was = $decoded->$auto;
            $from     = $self->_char_enc($char_was);
            $decoded->type->attribute(charset => $char_was);

            unless($char_to)
            {   $char_to = $char_was;
                $type_to->attribute(charset => $char_to);
                $to      = $from;
            }
        }

        my $new_data
          = $to   && $char_was eq 'PERL' ? $to->encode($decoded->string)
          : $from && $char_to  eq 'PERL' ? $from->decode($decoded->string)
          : $to && $from && $char_was ne $char_to ? $to->encode($from->decode($decoded->string))
          : undef;

        $recoded
          = $new_data
          ? $bodytype->new(based_on => $decoded, data => $new_data,
               mime_type => $type_to, checked => 1)
          : $decoded;
    }
    else
    {   $recoded = $decoded;
    }

    ### Apply transfer-encoding

    my $trans;
    if($trans_to ne 'none')
    {   $trans = $self->getTransferEncHandler($trans_to)
           or $self->log(WARNING =>
               "No encoder defined for transfer encoding `$trans_to'.");
    }

    my $encoded = defined $trans
      ? $trans->encode($recoded, result_type => $bodytype)
      : $recoded;

    $encoded;
}

=method charsetDetect %options
[3.013] This is tricky.  It is hard to detect whether the body originates from the
program, or from an external source.  And what about a database database?
are those octets or strings?
Please read L<Mail::Message::Body/Autodetection of character-set>.

=option  external BOOLEAN
=default external <false>
Do only consider externally valid character-sets, implicitly: C<PERL> is not
an acceptable answer.
=cut

sub charsetDetect(%)
{   my ($self, %args) = @_;
    my $text = $self->string;

    # Flagged as UTF8, so certainly created by the Perl program itself:
    # the content is not octets.
    if(utf8::is_utf8($text))
    {   $args{external} or return 'PERL';
        $text = encode_utf8 $text;
    }

    # Only look for normal characters, first 1920 unicode characters
    # When there is any octet in 'utf-encoding'-space, but not an
    # legal utf8, than it's not utf8.
    #XXX Use the fact that cp1252 does not define (0x81, 0x8d, 0x8f, 0x90, 0x9d) ?
    return 'utf-8'
        if $text =~ m/[\0xC0-\xDF][\x80-\xBF]/   # 110xxxxx, 10xxxxxx
        && $text !~ m/[\0xC0-\xFF][^\0x80-\xBF]/
        && $text !~ m/[\0xC0-\xFF]\z/;

    # Produce 'us-ascii' when it suffices: it is the RFC compliant
    # default charset.
    $text =~ m/[\x80-\xFF]/ ? 'cp1252' : 'us-ascii';
}

=method check

Check the content of the body not to include illegal characters.  Which
characters are considered illegal depends on the encoding of this body.

A body is returned which is checked.  This may be the body where this
method is called upon, but also a new object, when serious changes had
to be made.  If the check could not be made, because the decoder is not
defined, then C<undef> is returned.

=cut

sub check()
{   my $self     = shift;
    return $self if $self->checked;
    my $eol      = $self->eol;

    my $encoding = $self->transferEncoding->body;
    return $self->eol($eol)
       if $encoding eq 'none';

    my $encoder  = $self->getTransferEncHandler($encoding);

    my $checked
      = $encoder
      ? $encoder->check($self)->eol($eol)
      : $self->eol($eol);

    $checked->checked(1);
    $checked;
}

=method encoded %options

Encode the body to a format what is acceptable to transmit or write to
a folder file.  This returns the body where this method was called
upon when everything was already prepared, or a new encoded body
otherwise.  In either case, the body is checked.

=option  charset_detect CODE
=default charset_detect <the default>
See M<charsetDetectAlgorithm()>.
=cut

sub encoded(%)
{   my ($self, %args) = @_;
    my $mime    = $self->mimeType;

	if($mime->isBinary)
    {   return $self->transferEncoding eq 'none'
          ? $self->encode(transfer_encoding => $mime->encoding)
          : $self->check;
    }

    my $charset = my $old_charset = $self->charset || '';
    if(!$charset || $charset eq 'PERL')
    {   my $auto = $args{charset_detect} || $self->charsetDetectAlgorithm;
        $charset = $self->$auto(external => 1);
    }

    my $enc_was = $self->transferEncoding;
	my $enc     = $enc_was eq 'none' ? $mime->encoding : $enc_was;

    $enc_was eq $enc && $old_charset eq $charset
      ? $self->check
      : $self->encode(transfer_encoding => $enc, charset => $charset);
}

=method eol ['CR'|'LF'|'CRLF'|'NATIVE']
Returns the character (or characters) which are used to separate lines
within this body.  When a kind of separator is specified, the body is
translated to contain the specified line endings.

=example
 my $body = $msg->decoded->eol('NATIVE');
 my $char = $msg->decoded->eol;

=warning Unknown line terminator $eol ignored
=cut

my $native_eol = $^O =~ m/^win/i ? 'CRLF' : $^O =~ m/^mac/i ? 'CR' : 'LF';

sub eol(;$)
{   my $self = shift;
	my $old_eol = $self->{MMBE_eol} ||= $native_eol;
    @_ or return $old_eol;

    my $eol  = shift;
	$eol     = $native_eol if $eol eq 'NATIVE';

	$eol ne $old_eol || !$self->checked
    	or return $self;

    my $lines = $self->lines;
	
	my $wrong
      = $eol eq 'CRLF' ? first { !/\015\012$/ } @$lines
      : $eol eq 'CR'   ? first { !/\015$/ } @$lines
      : $eol eq 'LF'   ? first { /\015\012$|\015$/ } @$lines
      : ($self->log(WARNING => "Unknown line terminator $eol ignored"), 1);

	$wrong
		or return $self;

	my $expect = $eol eq 'CRLF' ? "\015\012" : $eol eq 'CR' ? "\015" : "\012";
	my @new    = map s/[\015\012]+$/$expect/r, @$lines;
    (ref $self)->new(based_on => $self, eol => $eol, data => \@new);
}

=method unify $body

Unify the type of the given $body objects with the type of the called
body.  C<undef> is returned when unification is impossible.  If the
bodies have the same settings, the $body object is returned unchanged.

Examples:

 my $bodytype = Mail::Message::Body::Lines;
 my $html  = $bodytype->new(mime_type=>'text/html', data => []);
 my $plain = $bodytype->new(mime_type=>'text/plain', ...);

 my $unified = $html->unify($plain);
 # $unified is the data of plain translated to html (if possible).

=cut

sub unify($)
{   my ($self, $body) = @_;
    return $self if $self==$body;

    my $mime     = $self->type;
    my $transfer = $self->transferEncoding;

    my $encoded  = $body->encode
      ( mime_type         => $mime
      , transfer_encoding => $transfer
      );

    # Encode makes the best of it, but is it good enough?

    my $newmime     = $encoded->type;
    return unless $newmime  eq $mime;
    return unless $transfer eq $encoded->transferEncoding;
    $encoded;
}

#------------------------------------------

=section About the payload

=method isBinary

Returns true when the un-encoded message is binary data.  This information
is retrieved from knowledge provided by M<MIME::Types>.

=cut

sub isBinary()
{   my $self = shift;
    $mime_types ||= MIME::Types->new(only_complete => 1);
    my $type = $self->type                    or return 1;
    my $mime = $mime_types->type($type->body) or return 1;
    $mime->isBinary;
}
 
=method isText
Returns true when the un-encoded message contains printable
text.
=cut

sub isText() { not shift->isBinary }

=method dispositionFilename [$directory]
Various fields are searched for C<filename> and C<name> attributes.  Without
$directory, the name found will be returned unmodified.

When a $directory is given, a filename is composed.  For security reasons,
only the basename of the found name gets used and many potentially
dangerous characters removed.  If no name was found, or when the found
name is already in use, then an unique name is generated.

Don't forget to read RFC6266 section 4.3 for the security aspects in your
email application.
=cut

sub dispositionFilename(;$)
{   my $self = shift;
    my $raw;

    my $field;
    if($field = $self->disposition)
    {   $field = $field->study if $field->can('study');
        $raw   = $field->attribute('filename')
              || $field->attribute('file')
              || $field->attribute('name');
    }

    if(!defined $raw && ($field = $self->type))
    {   $field = $field->study if $field->can('study');
        $raw   = $field->attribute('filename')
              || $field->attribute('file')
              || $field->attribute('name');
    }

    my $base;
    if(!defined $raw || !length $raw) {}
    elsif(index($raw, '?') >= 0)
    {   eval 'require Mail::Message::Field::Full';
        $base = Mail::Message::Field::Full->decode($raw);
    }
    else
    {   $base = $raw;
    }

    return $base
        unless @_;

    my $dir      = shift;
    my $filename = '';
    if(defined $base)   # RFC6266 section 4.3, very safe
    {   $filename = basename $base;
        for($filename)
        {   s/\s+/ /g;  s/ $//; s/^ //;
            s/[^\w .-]//g;
        }
    }

	my ($filebase, $ext) = length $filename && $filename =~ m/(.*)\.([^.]+)/
      ? ($1, $2) : (part => ($self->mimeType->extensions)[0] || 'raw');

    my $fn = File::Spec->catfile($dir, "$filebase.$ext");

    for(my $unique = 1; -e $fn; $unique++)
    {   $fn = File::Spec->catfile($dir, "$filebase-$unique.$ext");
    }

	$fn;
}

#------------------------------------------

=section Internals

=method getTransferEncHandler $type
Get the transfer encoder/decoder which is able to handle $type, or return
undef if there is no such handler.
=cut

my %transfer_encoder_classes =
 ( base64  => 'Mail::Message::TransferEnc::Base64'
 , binary  => 'Mail::Message::TransferEnc::Binary'
 , '8bit'  => 'Mail::Message::TransferEnc::EightBit'
 , 'quoted-printable' => 'Mail::Message::TransferEnc::QuotedPrint'
 , '7bit'  => 'Mail::Message::TransferEnc::SevenBit'
 );

my %transfer_encoders;   # they are reused.

sub getTransferEncHandler($)
{   my ($self, $type) = @_;

    return $transfer_encoders{$type}
        if exists $transfer_encoders{$type};   # they are reused.

    my $class = $transfer_encoder_classes{$type};
    return unless $class;

    eval "require $class";
    confess "Cannot load $class: $@\n" if $@;

    $transfer_encoders{$type} = $class->new;
}

=ci_method addTransferEncHandler $name, <$class|$object>
Relate the NAMEd transfer encoding to an OBJECTs or object of the specified
$class.  In the latter case, an object of that $class will be created on the
moment that one is needed to do encoding or decoding.

The $class or $object must extend M<Mail::Message::TransferEnc>.  It will
replace existing class and object for this $name.

Why aren't you contributing this class to MailBox?

=cut

sub addTransferEncHandler($$)
{   my ($this, $name, $what) = @_;

    my $class;
    if(ref $what)
    {   $transfer_encoders{$name} = $what;
        $class = ref $what;
    }
    else
    {   delete $transfer_encoders{$name};
        $class = $what;
    }

    $transfer_encoder_classes{$name} = $class;
    $this;
}

1;
