use ExtUtils::MakeMaker;

require 5.016;

use IO::Handle;

my $VERSION = '3.018_002';

# This is an attempt to automatically convert you configuration parameters.
# More docs: https://github.com/markov2/perl5-OODoc/wiki/oodist-config

# Use command 'oodist' to produce your whole software release.
my $git      = "https://github.com/markov2/perl5-Mail-Message";
my $publish  = "../public_html/mail-message";
my $homepage = "http://perl.overmeer.net/CPAN/";

my %oodist   = (
	oodoc_version => 3.05,
	first_year    => 2001,
	email         => "markov\@cpan.org",

	include  => [
		'../MIME-Types',
 		'../Mail-Box',
 		'../Mail-Box-Parser-C',
 		'../Mail-Transport',
 		'../MailTools',
 		'../Object-Realize-Later',
 		'../User-Identity',
	],

	use      => [
	],

	parser   => {
		syntax         => 'markov',
		skip_links     => [
			'Mail::Box::Netzwert',
			'Mail::ListDetector',
		],
		pmhead         => undef,
	},

	tests    => {
	},

	release  => {
		publish        => "$publish/source",
	},

	raw      => {
		publish        => "$publish/raw",
	},

	generate => [
	  {
		# Add real pod to the releases
		format         => 'pod3',
		podtail        => undef,
	  },
 	  # You may add HTML formatters here.
 		  # You may add exporter configurations here.
	],
);

my %requires = (
	'Carp'           => 0,
	'Date::Format'   => 0,
	'Date::Parse'    => 0,
	'Encode'         => 2.26,
	'Encode::Alias'  => 0,
	'Fcntl'          => 0,
	'File::Basename' => 0,
	'File::Copy'     => 0,
	'File::Spec'     => 0.7,
	'File::Temp'     => 0,
	'IO::Scalar'     => 0,
	'IO::Lines'      => 0,
	'List::Util'     => 0,
	'Mail::Address'  => 2.17,
	'MIME::Base64'   => 0,
	'MIME::QuotedPrint' => 0,
	'MIME::Types'    => 1.004,
	'POSIX'          => 0,
	'Scalar::Util'   => 1.13,
	'Storable'       => 0,
	'Sys::Hostname'  => 0,
	'Time::HiRes'    => 1.51,
	'Time::Zone'     => 0,
	'URI'            => 1.23,
	'User::Identity' => 1.02,
);

my @optional = ( 
	[ 'Mail::Internet' => '2.01', distr => 'MailTools', reason  => <<'REASON' ],
Many existing e-mail applications use Mail::Internet objects.  If
you want automatic conversions for compatibility, you need this.
REASON

	[ 'MIME::Entity' => '3.0', distr  => 'MIME::Tools', reason  => <<'REASON' ],
MIME::Entity extends Mail::Internet messages with multipart handling
and composition.  Install this when you want compatibility with
distrs which are based on this kind of messages.
REASON

	[ 'HTML::TreeBuilder' => '3.13', reason => <<'REASON' ],
The tree builder is used by the HTML::Format* packages.
Version 3.12 is wrong, so you should install a newer version
if you want smart html conversions.
REASON

	[ 'HTML::FormatText' => '2.01', reason => <<'REASON' ],
Plug-in which converts HTML to Postscript or plain text.
REASON

	[ 'Net::Domain' => 0, reason => <<'REASON' ],
Better detection of full hostname.
REASON

	[ 'Mail::Transport' => '3.006', reason => <<'REASON' ],
Old Mail::Transport used GLOBs, which are not supported anymore.
REASON
);

foreach my $module (sort keys %prereq)
{   my $reqversion = $prereq{$module};
    eval "require $module";

    if($@ && $@ =~ m/^Can't locate /)
    {   print "    $module is not yet installed\n" }
    elsif($@)
    {   print "    $module produced an error:\n$@";
        push @errors, $module;
    }
    elsif($module->VERSION < $reqversion)
    {   print "    $module version ", $module->VERSION, " is outdated; requires $reqversion\n";
    }
    else
    {   print "    $module version ", $module->VERSION, " is ok (required is $reqversion)\n";
    }
}

if($errors)
{   die <<'FIX';
*** ERROR! You have to install @errors manually,
*** before you can retry to install MailBox.
FIX
    exit 1;
}

OPTIONAL:
foreach my $optional (sort {$a->[0] cmp $b->[0]} @optional)
{   my ($module, $version, %args) = @$optional;
    my $requirements = $args{requires} || sub {1};
    next unless $requirements->();

    if($module eq 'MIME::Entity')
    {   # work-around for awkward development situation at home,
        # where the VERSION string is not in the development pre-release.
        no warnings;
        eval "require Mail::Internet";
        unless($@)
        {   $Mail::Internet::VERSION ||= '2.00';
            $Mail::Field::VERSION    ||= '2.00';
            $Mail::Header::VERSION   ||= '2.00';
        }
    }

#   print "\n";
    eval "require $module";
    if($@)
    {   if($@ =~ m/^Can't locate /)
        {   print "**** Optional $module is not installed\n";
            next OPTIONAL;
        }

        print "**** Optional $module compilation failed:\n$@\n";
        # try reinstallation
    }
    elsif(eval '$module->VERSION($version)' && $@)
    {   my $error = $@ || '';
        $error =~ s/[\r\n]+$//;
        print "**** Optional $module too old: requires $version but is ",
            $module->VERSION,";$error\n";
    }
    else
    {   my $v = $module->VERSION;
        my $r = $v eq $version ? ''
              : $version eq 0  ? " (any version will do)"
              :                  " (at least $version required)";

        print "**** Found optional $module version $v$r\n";
        next OPTIONAL;
    }

    my $reason = $args{reason};
    $reason =~ s/^/     /gm;
    $reason =~ s/\A    /Use:/;
    print $reason;

    if(my $warn = $args{warning})
    {   $warn =~ s/^/     /gm;
        $warn =~ s/\A    /WARN/;
        print $warn;
    }
    my $distr = $args{distr} || $module;

    $prereq{$distr} = $version;
    print "     Added $distr version $version to the requirements\n";
}

WriteMakefile
	NAME       => 'Mail::Message',
	VERSION    => $VERSION,
	AUTHOR     => 'Mark Overmeer <markov@cpan.org>',
	ABSTRACT   => 'Processing MIME messages',
	LICENSE    => 'perl_5',

	META_MERGE => {
		'meta-spec' => { version => 2 },
		resources   => {
			repository => {
				type => 'git',
				url  => "$git.git",
				web  => $git,
			},
			bugtracker => {
				web  => "$git/issues",
			},
			homepage => $homepage,
			license  => [ 'http//dev.perl.org/licenses/' ],
		},
		prereqs => {
			runtime => {
				requires => \%requires,
			},
			develop => {
				requires => {
					'OODoc' => '3.00',
				},
			},
			test => {
				requires => {
					'Test::More' => 1.00,
					'Test::Pod'  => 1.00,
				},
			},
		},

		# You may use multiple set-ups, see "oodist --make"
		x_oodist => \%oodist,
	};
