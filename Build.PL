use Module::Build;

Module::Build->new(
	module_name => 'Data::FormValidator',
	license => 'perl',
	requires => {
		'Test'		  => 0,
		'Test::More'  => 0,
	},
	sign=>1,
)->create_build_script;

