use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Data::FormValidator',
    'VERSION_FROM' => './lib/Data/FormValidator.pm', # finds $VERSION
	'PREREQ_PM' => {
		'Test'	=> 0,
	}
);
