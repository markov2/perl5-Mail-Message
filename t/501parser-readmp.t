#!/usr/bin/env perl
#
# Test the reading from file of message bodies which are multiparts
#

use strict;
use warnings;

use Mail::Message;
use Mail::Message::Test;

use Test::More;
use IO::File;

#
# From scalar
#

my $msg1 = Mail::Message->read("Subject: hello world\n\nbody1\nbody2\n");
ok(defined $msg1);
is(ref $msg1, 'Mail::Message');
ok(defined $msg1->head);
isa_ok($msg1->head, 'Mail::Message::Head');

my $body1 = $msg1->body;
ok(defined $body1);
isa_ok($body1, 'Mail::Message::Body');
ok(!$body1->isDelayed);

cmp_ok(@$body1, "==", 2);
is($body1->[0], "body1\n");
is($body1->[1], "body2\n");
is($msg1->subject, 'hello world');
ok($msg1->messageId);
ok($msg1->get('message-id'));

#
# From ref scalar
#

my $scalar = "Subject: hello world\n\nbody1\nbody2\n";
my $msg2 = Mail::Message->read(\$scalar);
ok(defined $msg2);
is(ref $msg2, 'Mail::Message');
ok(defined $msg2->head);
isa_ok($msg2->head, 'Mail::Message::Head');

my $body2 = $msg2->body;
ok(defined $body2);
isa_ok($body2, 'Mail::Message::Body');
ok(!$body2->isDelayed);

cmp_ok(@$body2, "==", 2);
is($body2->[0], "body1\n");
is($body2->[1], "body2\n");
is($msg2->subject, 'hello world');
ok($msg2->messageId);
ok($msg2->get('message-id'));

#
# From array
#

my $array = [ "Subject: hello world\n", "\n", "body1\n", "body2\n" ];
my $msg3 = Mail::Message->read($array);
ok(defined $msg3);
is(ref $msg3, 'Mail::Message');
ok(defined $msg3->head);
isa_ok($msg3->head, 'Mail::Message::Head');

my $body3 = $msg3->body;
ok(defined $body3);
isa_ok($body3, 'Mail::Message::Body');
ok(!$body3->isDelayed);

cmp_ok(@$body3, "==", 2);
is($body3->[0], "body1\n");
is($body3->[1], "body2\n");
is($msg3->subject, 'hello world');
ok($msg3->messageId);
ok($msg3->get('message-id'));

#
# From file handle
#

open OUT, '>', 'tmp' or die $!;
print OUT $scalar;
close OUT;

my $in = IO::File->new('tmp', 'r');
ok(defined $in);
my $msg5 = Mail::Message->read($in);
$in->close;

ok(defined $msg5);
is(ref $msg5, 'Mail::Message');
ok(defined $msg5->head);
isa_ok($msg5->head, 'Mail::Message::Head');

my $body5 = $msg5->body;
ok(defined $body5);
isa_ok($body5, 'Mail::Message::Body');
ok(!$body5->isDelayed);

cmp_ok(@$body5, "==", 2);
is($body5->[0], "body1\n");
is($body5->[1], "body2\n");
is($msg5->subject, 'hello world');
ok($msg5->messageId);
ok($msg5->get('message-id'));

unlink 'tmp';

done_testing;
