
use strict;

$^W = 1;

print "1..3\n";

use Data::FormValidator;

my $input_profile = {
		       required => [ qw( email_1  email_ok) ],
		       optional => ['filled','not_filled'],
		       constraint_regexp_map => {
				      '/^email/'  => "email",
			   },
			   constraints => {
				 not_filled   => 'phone',
			   },
				missing_optional_valid => 1,	   
			};

my $validator = new Data::FormValidator({default => $input_profile});

my $input_hashref = {
   email_1  => 'invalidemail',
   email_ok => 'mark@stosberg.com', 
   filled  => 'dog',
   not_filled => '',
   should_be_unknown => 1, 
};

my ($valids, $missings, $invalids, $unknowns);

eval{
  ($valids, $missings, $invalids, $unknowns) = $validator->validate($input_hashref, 'default');
};
#use Data::Dumper; warn Dumper   ($valids, $missings, $invalids, $unknowns);

if($@){
  print "not ";
}
print "ok 1\n";

# "not_filled" should appear valids now. 
unless (exists $valids->{'not_filled'}){
  print "not ";
}
print "ok 2\n";

# "should_be_unknown" should be still be unknown
unless ($unknowns->[0] eq 'should_be_unknown') {
	print "not ";
}
print "ok 3";

