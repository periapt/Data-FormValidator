
use strict;

$^W = 1;

print "1..4\n";

use Data::FormValidator;

my $input_profile = {
		       required => [ qw( email_1  email_ok) ],
		       optional => 'extra',
		       constraint_regexp_map => {
				      '/^email/'  => "email",
				   }
			};

my $validator = new Data::FormValidator({default => $input_profile});

my $input_hashref = {
   email_1  => 'invalidemail',
   email_ok => 'mark@stosberg.com', 
   extra    => 'unrelated field',
};

my ($valids, $missings, $invalids, $unknowns);

eval{
  ($valids, $missings, $invalids, $unknowns) = $validator->validate($input_hashref, 'default');
};
if($@){
  print "not ";
}
print "ok 1\n";

unless ($invalids->[0] eq 'email_1'){
  print "not ";
}
print "ok 2\n";

unless ($valids->{'email_ok'}) {
   print "not ";
}
print "ok 3\n";

unless ($valids->{'extra'}) {
   print "not "; 
}
print "ok 4\n";
