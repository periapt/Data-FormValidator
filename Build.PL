shift(@ARGV) if $ARGV[0] eq 'Build'; # accomodate with CPAN autoinstall
use Module::Build;

my $class = Module::Build->subclass(
	 class => 'Data::FormValidator::Builder',
	 code => q{
	 	sub ACTION_dist {
			my $self = shift;
			`perldoc -t lib/Data/FormValidator.pm>README`;
			$self->SUPER::ACTION_dist;
	 	}
 	},
);


$class->new(
	module_name => 'Data::FormValidator',
	license => 'perl',
	requires => {
		'Image::Size' 	 => 0,
		'Test::More'  	 => 0,
		'Date::Calc'	 => 0,
		'File::MMagic'   => 1.17,
		'MIME::Types'	 => 1.005,
		'Regexp::Common' => 0 
	},
)->create_build_script;

