# Integration with Regexp::Common;

use Test::More tests => 9;

use Data::FormValidator; 

my %FORM = (
	bad_ip  => '127 0 0 1',
	good_ip => '127.0.0.1',
);

my $results;

eval {
$results = Data::FormValidator->check(\%FORM, { 
		required => [qw/good_ip bad_ip/],
		constraint_regexp_map => {
			qr/_ip$/ => 'RE_net_IPv4',

		}
	});
};
warn $@ unless ok((not $@), 'runtime errors');
ok($results->valid->{good_ip}, 'good ip'); 
ok($results->invalid->{bad_ip}, 'bad ip'); 


$results = Data::FormValidator->check(\%FORM, { 
		untaint_all_constraints => 1,
		required => [qw/good_ip bad_ip/],
		constraint_regexp_map => {
			qr/_ip$/ => 'RE_net_IPv4',

		}
	});


warn $@ unless ok((not $@), 'runtime errors');
ok($results->valid->{good_ip}, 'good ip with tainting'); 
ok($results->invalid->{bad_ip}, 'bad ip with tainting'); 

# Test passing flags
$results = Data::FormValidator->check(\%FORM, { 
		required => [qw/good_ip bad_ip/],
		constraint_regexp_map => {
			qr/_ip$/ => {
				constraint => 'RE_net_IPv4_dec',
				params => [ \'-sep'=> \' ' ],
			}
		}
	});


warn $@ unless ok((not $@), 'runtime errors');
# Here we are trying passing a parameter which should reverse
# the notion of which one expect to succeed.
ok($results->valid->{bad_ip}, 'expecting success with params'); 
ok($results->invalid->{good_ip}, 'expecting failure with params'); 



