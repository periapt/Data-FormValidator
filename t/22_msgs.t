use Test::More tests => 15;
use strict;

use Data::FormValidator;

my $simple_profile = {
	required => [qw/req_1 req_2/],
	optional  => [qw/opt_1/],
	constraints => {
		req_1 => 'email'
	},
	msgs=>{},
};

my $simple_data = {
	req_1 => 'not_an_email',
};	

my $prefix_profile = {
	required => [qw/req_1 req_2/],
	optional  => [qw/opt_1/],
	constraints => {
		req_1 => 'email'
	},
	msgs=>{ prefix=>'' },
};

my $input_profile = {
		       required => [ qw(admin prefork sleep rounds) ],
		       constraints => {
				       admin => "email",
				       prefork => sub {
						my $val = shift;
						if ($val =~ /^\d$/) {
							if ($val > 1 and $val <9) { 
								return $val;
							}
						}
						return 0;
				       },
					   sleep => [
							{
								name => 'min',
								constraint => sub { 
									my $val = shift;
									if ($val > 0) {
										return $val;
									} else {
										return 0;
									}
								}
							},
							{
								name => 'max',
								constraint => sub { 
									my $val = shift;
									if ($val < 11) {
										return $val;
									} else {
										return 0;
									}
								}
							}
						],
						rounds => [
							{
								name => 'min',
								constraint => sub { 
									my $val = shift;
									if ($val > 19) {
										return $val;
									} else {
										return 0;
									}
								}
							},
							{
								name => 'max',
								constraint => sub { 
									my $val = shift;
									if ($val < 101) {
										return $val;
									} else {
										return 0;
									}
								}
							}
						]
				      },
					  msgs => {
						  invalid => {
							  field => {
								  admin => 'invalid email address',
								  sleep => {
									  max => 'needs to be lesser than 11',
									  min => 'needs to be greater than 0'
								  },
								  rounds => 'needs to be a number between 20 and 100'
							  },
							  default => 'contains an invalid value'
						  },
						  format => 'ERROR: %s', 
						  prefix => 'error_',
					  }
			};

my $validator = new Data::FormValidator({
		simple  => $simple_profile,
		default => $input_profile,
		prefix  => $prefix_profile,
	});

my $input_hashref = {admin=> 'invalidemail', prefork=> 9, sleep => 11, rounds=>8};

my ($valids, $missings, $invalids, $unknowns) = ({},[],{},[]);
eval{
	($valids, $missings, $invalids, $unknowns) = $validator->validate($simple_data, 'simple');
};
ok (not $@);

# testing simple msg definition, both invalid and missing should be returned as hashes
ok (ref $invalids eq 'HASH', 'invalid fields returned as hash in simple case'); 
ok (ref $missings eq 'HASH', 'missing fields returned as hash in simple case'); 


like ($invalids->{req_1}, qr/Invalid/, 'default invalid message');
like ($missings->{req_2}, qr/Missing/, 'default missing message');
like ($invalids->{req_1}, qr/span/,    'default formatting');


# testing single constraints and single error case
eval{
	($valids, $missings, $invalids, $unknowns) = $validator->validate($input_hashref, 'default');
};
ok (not $@);

ok ($invalids->{error_sleep}->[0]->{constraint} eq 'max', 'multiple constraints constraint definition');
ok (length $invalids->{error_sleep}->[0]->{msg}, 'multiple constraints msg definition');

ok (length $invalids->{error_rounds}, 'multiple constraints with one message');	

like($invalids->{error_rounds}, qr/ERROR/, 'overriding formatting'),


eval{
	($valids, $missings, $invalids, $unknowns) = $validator->validate($simple_data, 'prefix');
};
warn $@ unless ok (not $@);
	
ok(defined $invalids->{err_req_1}, 'using default prefix');
ok(scalar keys %$invalids == 1, 'size of invalids hash');
ok(scalar keys %$missings == 1, 'size of missings hash');

