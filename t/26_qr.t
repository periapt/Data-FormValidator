# Testing new support for 'qr'. -mls

use Test::More tests => 6;

use Data::FormValidator; 

my %FORM = (
	stick 	=> 'big',
	speak 	=> 'softly',

	bad_email  => 'doops',
	good_email => 'great@domain.com',

	'short_name' => 'tim',

	'not_oops'	=> 'hoops',

	'untainted_with_qr' => 'Slimy', 
);

my $results = Data::FormValidator->check(\%FORM, { 
		required_regexp => qr/stick/,
		optional_regexp => '/_email$/',
		constraint_regexp_map => {
			qr/email/ => 'email',

		},
		field_filter_regexp_map => {
			qr/_name$/ => 'ucfirst',
		},
		optional => [qw/short_name not_oops untainted_with_qr/],
		constraints => {
			not_oops => {
				name => 'start_with_oop',		
				constraint => qr/^oop/,
			},
			untainted_with_qr => qr/(Slim)/,

		},
		msgs => {
			constraints => {
				'start_with_oop' => 'testing named qr constraints',
			}

		},
		untaint_constraint_fields => [qw/untainted_with_qr/],
	});

ok ($results->valid('stick') eq 'big','using qr for regexp quoting');
ok ($results->valid('good_email'), 'expected to pass constraint');
ok ($results->invalid('bad_email'),  'expected to fail constraint');
is($results->valid('short_name'),'Tim', 'field_filter_regexp_map');

my $msgs = $results->msgs;
like($msgs->{not_oops},qr/testing named/, 'named qr constraints');

is($results->valid('untainted_with_qr'),'Slim', 'untainting with qr');





