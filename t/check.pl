use common::sense;
use lib::abs '../lib';
use Test::More;
use AnyEvent::Impl::Perl;
use AnyEvent 5;
use AnyEvent::Socket;
use AnyEvent::Memcached;

our $testaddr;
our $noreply;
my ($host,$port) = split ':',$testaddr;$host ||= '127.0.0.1'; # allow *_SERVER=:port
$testaddr = join ':', $host,$port;

alarm 10;
my $cv;$cv = AE::cv { $cv->send; };
#my $cv = AnyEvent->condvar;
#$cv->begin(sub { $cv->send });

my $memd;
$cv->begin;
my $cg;$cg = tcp_connect $host,$port, sub {
	undef $cg;
	@_ or plan skip_all => "No memcached instance running at $testaddr\n";
	diag "testing $testaddr";
	require Test::NoWarnings;Test::NoWarnings->import;
	plan tests => 21+1;

	$memd = AnyEvent::Memcached->new(
		servers   => [ $testaddr ],
		cv        => $cv,
		debug     => 0,
		noreply   => $noreply,
		namespace => "AE::Memd::t/$$/" . (time() % 100) . "/",
	);

	isa_ok($memd, 'AnyEvent::Memcached');
#=for rem
	$memd->set("key1", "val1", cb => sub {
		ok(shift,"set key1 as val1") or diag "  Error: @_";
		$memd->get("key1", cb => sub {
			is(shift, "val1", "get key1 is val1") or diag "  Error: @_";
			$memd->add("key1", "val-replace", cb => sub {
				ok(! shift, "add key1 properly failed");
				$memd->add("key2", "val2", cb => sub {
					ok(shift, "add key2 as val2");
					$memd->get("key2", cb => sub {
						is(shift, "val2", "get key2 is val2") or diag "@_";
						$memd->replace("key2", "val-replace", cb => sub {
							ok(shift, "replace key2 as val-replace");
							$memd->get("key2", cb => sub {
								is(shift, "val-replace", "get key2 is val-replace") or diag "@_";
								
								
								
								$memd->rget('1','0', cb => sub {
									my ($r,$e) = @_;
									
									if (!$e) {
										$memd->set("key3", "val3", cb => sub {
											ok(shift,"set key3 as val3");
											$memd->rget('key2','key3', cb => sub { # +left, +right
												my $r = shift;
												is( $r->{ 'key2' }, 'val-replace', 'rget[].key2' );
												is( $r->{ 'key3' }, 'val3', 'rget[].key3' );
											});
											$memd->rget('key2','key3', '+right' => 0, cb => sub {
												my $r = shift;
												is( $r->{ 'key2' }, 'val-replace', 'rget[).key2' );
												ok(! exists $r->{ 'key3' }, '!rget[).key3' );
											});
											$memd->rget('key2','key3', '+left' => 0, cb => sub {
												my $r = shift;
												ok(! exists $r->{ 'key2' }, '!rget(].key2' );
												is( $r->{ 'key3' }, 'val3', 'rget(].key3' );
											});
										});
									} else {
										like( $e, qr/rget not supported/, 'rget fails' );
										SKIP: { skip "Have no rget",6 }
									}
								});
								
							});
						});
					});
				});
				$memd->delete("key1", cb => sub {
					ok(shift, "delete key1");
					$memd->get("key1", cb => sub {
						ok(! shift, "get key1 properly failed");
					});
					
				});
			});
		});
	});
#=cut
	$memd->replace("key-noexist", "bogus", cb => sub {
		ok(!shift , "replace key-noexist properly failed");
	});
	my $need;
	$memd->set("ikey", $need = 3, cb => sub {
		ok(shift,"set ikey as 3") or diag "  Error: @_";
		#$memd->incr(ikey => 1, noreply => 1) and warn("norply ok"), ++$need;
		$memd->incr(ikey => 1, cb => sub {
			++$need;
			my $igot = shift;
			is $igot, $need, 'incr ikey = '.$igot or diag "  Error: @_";
			$need = $igot-2;
			#$memd->decr(ikey => 2, noreply => 1);# or $need -= 2;
			$memd->decr(ikey => 2, cb => sub {
				my $dgot = shift;
				is $dgot, $need, 'decr ikey = '.$dgot or diag "  Error: @_";
				$memd->get('ikey', cb => sub {
					diag "get after incr/decr = ".shift;
				});
			});
		});
	});

	$cv->end; #connect
}, sub { 1 };

$cv->recv;
$memd->destroy();
