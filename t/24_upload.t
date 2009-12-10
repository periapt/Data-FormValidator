#########################

use Test::More tests => 14;
BEGIN { use_ok('Data::FormValidator::Constraints::Upload') };

#########################

%ENV = (
	%ENV,
          'SCRIPT_NAME' => '/test.cgi',
          'SERVER_NAME' => 'perl.org',
          'HTTP_CONNECTION' => 'TE, close',
          'REQUEST_METHOD' => 'POST',
          'SCRIPT_URI' => 'http://www.perl.org/test.cgi',
          'CONTENT_LENGTH' => '2986',
          'SCRIPT_FILENAME' => '/home/usr/test.cgi',
          'SERVER_SOFTWARE' => 'Apache/1.3.27 (Unix) ',
          'HTTP_TE' => 'deflate,gzip;q=0.3',
          'QUERY_STRING' => '',
          'REMOTE_PORT' => '1855',
          'HTTP_USER_AGENT' => 'Mozilla/5.0 (compatible; Konqueror/2.1.1; X11)',
          'SERVER_PORT' => '80',
          'REMOTE_ADDR' => '127.0.0.1',
          'CONTENT_TYPE' => 'multipart/form-data; boundary=xYzZY',
          'SERVER_PROTOCOL' => 'HTTP/1.1',
          'PATH' => '/usr/local/bin:/usr/bin:/bin',
          'REQUEST_URI' => '/test.cgi',
          'GATEWAY_INTERFACE' => 'CGI/1.1',
          'SCRIPT_URL' => '/test.cgi',
          'SERVER_ADDR' => '127.0.0.1',
          'DOCUMENT_ROOT' => '/home/develop',
          'HTTP_HOST' => 'www.perl.org'
);

use CGI;
open(IN,'<t/upload_post_text.txt') || die 'missing test file';

*STDIN = *IN;
$q = new CGI;

use Data::FormValidator;
my $default = {
		required=>[qw/hello_world 100x100_gif 300x300_gif/],
		validator_packages=> 'Data::FormValidator::Constraints::Upload',
		constraints => {
			'hello_world' => {
				constraint_method => 'file_format',
				params=>[],
			},
			'100x100_gif' => [
				{
					constraint_method => 'file_format',
					params=>[],
				},
				{
					constraint_method => 'file_max_bytes',
					params=>[],
				}
			],
			'300x300_gif' => {
				constraint_method => 'file_max_bytes',
				params => [\100],
			},
		},
	};

my $dfv = Data::FormValidator->new({ default => $default});
my ($valid,$missing,$invalid);
eval {
	($valid,$missing,$invalid) = $dfv->validate($q, 'default');
};
warn $@ unless ok(not $@);


# Test to make sure hello world failes because it's the wrong type
ok((grep {/hello_world/} @$invalid), 'expect format failure');


# Make sure 100x100 passes because it's the right type and size
ok(exists $valid->{'100x100_gif'});

ok($valid->{'100x100_gif_info'}->{extension}, 'setting extension in valid hash ');
ok($valid->{'100x100_gif_info'}->{mime_type}, 'setting mime_type in valid hash');

# 300x300 should fail because it's too big
ok((grep {'300x300'} @$invalid), 'max_bytes');

ok($valid->{'100x100_gif_info'}->{bytes}>0, 'setting bytes in valid hash');


# Revalidate to usefully re-use the same fields
my $profile_2  = {
	required=>[qw/hello_world 100x100_gif 300x300_gif/],
	validator_packages=> 'Data::FormValidator::Constraints::Upload',
	constraints => {
		'100x100_gif' => {
			constraint_method => 'image_max_dimensions',
			params => [\200,\200],
		},
		'300x300_gif' => {
			constraint_method => 'image_max_dimensions',
			params => [\200,\200],
		},
	},
};

$dfv = Data::FormValidator->new({ profile_2 => $profile_2});
($valid,$missing,$invalid) = $dfv->validate($q, 'profile_2');

ok(exists $valid->{'100x100_gif'}, 'expecting success with max_dimensions');
ok((grep {'300x300'} @$invalid), 'expecting failure with max_dimensions');

ok($valid->{'100x100_gif_info'}->{width}>0, 'setting width in valid hash');
ok($valid->{'100x100_gif_info'}->{width}>0, 'setting height in valid hash');

# Now test trying constraint_regxep_map
my $profile_3  = {
	required=>[qw/hello_world 100x100_gif 300x300_gif/],
	validator_packages=> 'Data::FormValidator::Constraints::Upload',
	constraint_regexp_map => {
		'/[13]00x[13]00_gif/'	=> {
			constraint_method => 'image_max_dimensions',
			params => [\200,\200],
		}
	}
};

$dfv = Data::FormValidator->new({ profile_3 => $profile_3});
($valid,$missing,$invalid) = $dfv->validate($q, 'profile_3');

ok(exists $valid->{'100x100_gif'}, 'expecting success with max_dimensions using constraint_regexp_map');
ok((grep {'300x300'} @$invalid), 'expecting failure with max_dimensions using constraint_regexp_map');

