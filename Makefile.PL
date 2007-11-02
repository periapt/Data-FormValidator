use 5.008; # patches to fix tests failing on 5.6 are welcome. 
use ExtUtils::MakeMaker;
WriteMakefile
(
          'NAME' => 'Data::FormValidator',
          'VERSION_FROM' => 'lib/Data/FormValidator.pm',
          'PREREQ_PM' => {
                           'Date::Calc' => '5',
                           'File::MMagic' => '1.17',
                           'Image::Size' => '0',
                           'MIME::Types' => '1.005',
                           'Perl6::Junction' => '1.1',
                           'Regexp::Common' => '0',
                           'Scalar::Util' => '0',
                           'Test::More' => '0',
                           'overload' => '0'
                         },
          'INSTALLDIRS' => 'site',
          'PL_FILES' => {}
        )
;
