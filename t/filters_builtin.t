use Test::More qw/no_plan/;
use Data::FormValidator::Filters (qw/:filters/);
use strict;

{ 
    my $comma_splitter = FV_split(',');
    is_deeply( $comma_splitter->('a,b'), [qw/a b/], "FV_split with two values");
    is_deeply( $comma_splitter->('a'), [qw/a/], "FV_split with one value");
    is_deeply( $comma_splitter->(),undef, "FV_split with no values");
}


is( filter_dollars('There is $0.11e money in here somewhere'),
   '0.11', 
   "filter_dollars works as expected");

TODO: {
    local $TODO = 'all these broken filters need to be dealt with.';
    is( filter_dollars('0.111'),
      '0.11', 
      "filter_dollars removes trailing numbers");

    is( filter_neg_integer('9-'),
        'a9-', 
        "filter_neg_integer should leave string without a negative integer alone.");

    is( filter_pos_integer('a9+'),
        '9', 
        "filter_pos_integer should care which side a + is on.");

    is( filter_integer('a9+'),
        '9', 
        "filter_integer should care which side a + is on.");

    is( filter_decimal('1,000.23'),
        '1000.23', 
        "filter_decimal should handle commas correctly");

    is( filter_pos_decimal('1,000.23'),
        '1000.23', 
        "filter_pos_decimal should handle commas correctly");

    is( filter_neg_decimal('-1,000.23'),
        '-1000.23', 
        "filter_neg_decimal should handle commas correctly");
}
