shift(@ARGV) if $ARGV[0] eq 'Build'; # accomodate with CPAN autoinstall
use Module::Build;

Module::Build->new(
	module_name => 'Data::FormValidator',
	license => 'perl',
	requires => {
		'Test'		  => 0,
		'Test::More'  => 0,
	},
)->create_build_script;

