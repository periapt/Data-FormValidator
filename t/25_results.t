use Test::More tests => 1;

use Data::FormValidator; 

my %FORM = (
	stick => 'big',
	speak  => 'softly',
);

my $results = Data::FormValidator->check(\%FORM, { required => 'stick' });

ok($results->valid('stick') eq 'big','using check() has class method');

