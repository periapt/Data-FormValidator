# This script tests validating keyts with multiple data
# Mark Stosberg 02/16/03 

use strict;
use lib ('.','../t');

$^W = 1;

print "1..5\n";

my $input_hash = { 
	single_value => ' Just One ',
	multi_values => [' One ', ' Big ', ' Happy ', ' Family '],
	re_multi_test => [qw/at the circus/],
	constraint_multi_test => [qw/12345 22234 oops/],
};


use Data::FormValidator;

my $input_profile = {
	required => [qw/single_value multi_values re_multi_test constraint_multi_test/],
	filters => [qw/trim/],
	field_filters => {
		single_value => 'lc',
		multi_values => 'uc',
	},
	field_filter_regexp_map => {
		'/_multi_test$/'      => 'ucfirst',
	},
	constraints => {
		constraint_multi_test => 'zip',
	},
};

my $validator = new Data::FormValidator({default => $input_profile});

my ($valids, $missings, $invalids, $unknowns);
eval{
  ($valids, $missings, $invalids, $unknowns) = $validator->validate($input_hash, 'default');
};

# Test that inconditional filters still work with single values
print "not " unless $valids->{single_value} eq 'just one';
print "ok 1\n";

# Test that inconditional filters work with multi values
print "not " unless lc $valids->{multi_values}->[0] eq lc 'one';
print "ok 2\n";

# Test that field filters work with multiple values
print "not " unless $valids->{multi_values}->[0] eq 'ONE';
print "ok 3\n";

# Test the filters applied to multiple values by RE work
print "not " unless $valids->{re_multi_test}->[0] eq 'At';
print "ok 4\n";

# If any of the values fail the constraint, the field becomes invalid
print "not " if $valids->{constraint_multi_test};
print "ok 5\n";

