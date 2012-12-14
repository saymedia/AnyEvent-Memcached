#!/usr/bin/env perl -w

use strict;
use AnyEvent::Memcached;
use AnyEvent::Memcached::Hash::Consistent;
use Test::More tests => 2;

my @warn;
$SIG{__WARN__} = sub { push @warn, shift; };

my $memd = AnyEvent::Memcached->new(
    # Server doesn't matter for this test so just use 
    # hardcoded default memcached server.
    servers   => "127.0.0.1:21201",
    hasher    => 'AnyEvent::Memcached::Hash::Consistent',
);

is($memd->{_hasher}, 'AnyEvent::Memcached::Hash::Consistent', 
    'able to set custom hasher');

ok (!@warn, "No warnings were emitted" );

