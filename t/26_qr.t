# Testing new support for 'qr'. -mls

use Test::More tests => 5;

use Data::FormValidator; 

my %FORM = (
	stick 	=> 'big',
	speak 	=> 'softly',

	bad_email  => 'oops',
	good_email => 'great@domain.com',

	'short_name' => 'tim',
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
		optional => 'short_name',
		constraints => {
			bad_email => {
				name => 'start_with_oop',		
				constraint => qr/^oop/,
			},

		},
		msgs => {
			constraints => {
				'start_with_oop' => 'testing named qr constraints',
			}

		},
	});

ok ($results->valid('stick') eq 'big','using qr for regexp quoting');
ok ($results->valid('good_email'), 'expected to pass constraint');
ok ($results->invalid('bad_email'),  'expected to fail constraint');
ok ($results->valid('short_name') eq 'Tim', 'field_filter_regexp_map');

my $msgs = $results->msgs;
like($msgs->{bad_email},qr/testing named/, 'named qr constraints');

