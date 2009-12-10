#
#    FormValidator.pm - Object that validates form input data.
#
#    This file is part of FormValidator.
#
#    Author: Francis J. Lacoste <francis.lacoste@iNsu.COM>
#
#    Copyright (C) 1999 Francis J. Lacoste, iNsu Innovations
#    Parts Copyright 1996-1999 by Michael J. Heins <mike@heins.net>
#    Parts Copyright 1996-1999 by Bruce Albrecht  <bruce.albrecht@seag.fingerhut.com>
#
#    Parts of this module are based on work by
#    Bruce Albrecht, <bruce.albrecht@seag.fingerhut.com> contributed to
#    MiniVend.
#
#    Parts also based on work by Michael J. Heins <mikeh@minivend.com>
#
#    Numerous changes by Mark Stosberg <mark@summersault.com>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms same terms as perl itself.
#
package Data::FormValidator;

use vars qw( $VERSION );

BEGIN {
    ($VERSION) = '$Revision: 1.3 $' =~ /Revision: ([\d.]+)/;
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(
          filter_trim
          filter_strip
          filter_digit
          filter_alphanum
          filter_integer
          filter_pos_integer
          filter_neg_integer
          filter_decimal
          filter_pos_decimal
          filter_neg_decimal
          filter_dollars
          filter_phone
          filter_sql_wildcard
          filter_quotemeta
          filter_lc
          filter_uc
          filter_ucfirst
	valid_email
	valid_state_or_province
	valid_state
	valid_province
	valid_zip_or_postcode
	valid_postcode
	valid_zip
	valid_phone
	valid_american_phone
	valid_cc_number
	valid_cc_exp
	valid_cc_type
);

%EXPORT_TAGS = (
    filters => [qw/
          filter_trim
          filter_strip
          filter_digit
          filter_alphanum
          filter_integer
          filter_pos_integer
          filter_neg_integer
          filter_decimal
          filter_pos_decimal
          filter_neg_decimal
          filter_dollars
          filter_phone
          filter_sql_wildcard
          filter_quotemeta
          filter_lc
          filter_uc
          filter_ucfirst/],
    validators => [qw/
	valid_email
	valid_state_or_province
	valid_state
	valid_province
	valid_zip_or_postcode
	valid_postcode
	valid_zip
	valid_phone
	valid_american_phone
	valid_cc_number
	valid_cc_exp
	valid_cc_type
/],
);

use strict;
use Carp; # generate better errors with more context
=pod

=head1 NAME

Data::FormValidator - Validates user input (usually from an HTML form) based
on input profile.

=head1 SYNOPSIS

In an HTML::Empberl page:

    use Data::FormValidator;

    my $validator = new Data::FormValidator( "/home/user/input_profiles.pl" );
    my ( $valid, $missing, $invalid, $unknown ) = $validator->validate(  \%fdat, "customer_infos" );

=head1 DESCRIPTION

Data::FormValidator's main aim is to make the tedious coding of input
validation expressible in a simple format and to let the programmer focus
on more interesting tasks.

When you are coding a web application one of the most tedious though
crucial tasks is to validate user's input (usually submitted by way of
an HTML form). You have to check that each required fields is present
and that some fields have valid data. (Does the phone input looks like a
phone number? Is that a plausible email address? Is the YY state
valid? etc.) For a simple form, this is not really a problem but as
forms get more complex and you code more of them this task becames
really boring and tedious.

Data::FormValidator lets you define profiles which declare the
required fields and their format. When you are ready to validate the
user's input, you tell Data::FormValidator the profile to apply to the
user data and you get the valid fields, the name of the fields which
are missing. An array is returned listing which fields are valid,
missing, invalid and unknown in this profile.

You are then free to use this information to build a nice display to
the user telling which fields that he forgot to fill.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $profile_file	= shift;
    my $profiles	= undef;

    if ( ref $profile_file ) {
	# Profile already passed as an hash reference.
	$profiles	= $profile_file;
	$profile_file	= undef;
    }

    bless { profile_file => $profile_file,
	    profiles	 => $profiles,
	  }, $class;
}

=pod

=head1 INPUT PROFILE SPECIFICATION

To create a Data::FormValidator, use the following :

    my $validator = new Data::FormValidator( $input_profile );

Where $input_profile may either be an hash reference to an input
profiles specification or a file that will be evaluated at runtime to
get a hash reference to an input profiles specification.

The input profiles specification is an hash reference where each key
is the name of the input profile and each value is another hash
reference which contains the actual profile elements. If the input
profile is specified as a file name, the profiles will be reread each
time that the disk copy is modified.

Here is an example of a valid input profiles specification :

    {
	customer_infos => {
	    optional     =>
		[ qw( company fax country password password_confirmation) ],
	    required     =>
		[ qw( fullname phone email address) ],
            required_regexp => '/city|state|zipcode/',
            optional_regexp => '/_province$/',
	    constraints  =>
		{
		    email	=> "email",
		    fax		=> "american_phone",
		    phone	=> "american_phone",
		    zipcode	=> '/^\s*\d{5}(?:[-]\d{4})?\s*$/',
		    state	=> "state",
		},
	    constraint_regexp_map => {
		'/_postcode$/'	=> 'postcode',
		'/_province$/'  => 'province,		      
	    },			      
            dependency_groups  => {
                password_group => [qw/password password_confirmation/]
            }
	    defaults => {
		country => "USA",
	    },
	},
	customer_billing_infos => {
	     optional	    => [ "cc_no" ],
	     dependencies   => {
		"cc_no" => [ qw( cc_type cc_exp ) ],
	     },
	     constraints => {
		cc_no      => {  constraint  => "cc_number",
				 params	     => [ qw( cc_no cc_type ) ],
				},
		cc_type	=> "cc_type",
		cc_exp	=> "cc_exp",
	      }
	    filters       => [ "trim" ],
	    field_filters => { cc_no => "digit" },
	},
    }

Notice that a number of components take anonymous arrays as their values. In any of
these places, you can simply use a string if you only need to specify one value. For example,
instead of

    filters => [ 'trim' ]

you can simply say

    filters => 'trim'

The following are the valid fields for an input specification :

=over

=item required

This is an array reference which contains the name of the fields which
are required. Any fields in this list which are not present in the
user input will be reported as missing.

=item optional

This is an array reference which contains the name of optional fields.
These are fields which MAY be present and if they are, they will be
check for valid input. Any fields not in optional or required list
will be reported as unknown.

=item required_regexp

This is a regular expression used to specify additional fieds which are
required. For example, if you wanted all fields names that begin with I<user_> 
to be required, you could use the regular expression, /^user_/

=item optional_regexp

This is a regular expression used to specify additional fieds which are
optional. For example, if you wanted all fields names that begin with I<user_> 
to be optional, you could use the regular expression, /^user_/

=item dependencies

This is an hash reference which contains dependencies information.
This is for the case where one optional fields has other requirements.
For example, if you enter your credit card number, the field cc_exp
and cc_type should also be present. Any fields in the dependencies
list that is missing when the target is present will be reported as
missing.

=item dependency_groups

This is a hash reference which contains information about groups of 
interdependent fields. The keys are arbitrary names that you create and
the values are references to arrays of the field names in each group. For example,
perhaps you want both the password and password_confirmation field to be required
if either one of them is filled in.  

=item defaults

This is a hash reference which contains defaults which should be
substituted if the user hasn't filled the fields. Key is field name
and value is default value which will be returned in the list of valid
fields.

=item filters

This is a reference to an array of filters that will be applied to ALL
optional or required fields. This can be the name of a built-in filter
(trim,digit,etc) or an anonymous subroutine which should take one parameter, 
the field value and return the (possibly) modified value.

=item field_filters

This is a reference to an hash which contains reference to array of
filters which will be applied to specific input fields. The key of the
hash is the name of the input field and the value is a reference to an
array of filters, the same way the filters parameter works.

=item constraints

This is a reference to an hash which contains the constraints that
will be used to check whether or not the field contains valid data.
Constraints can be either the name of a builtin constraint function
(see below), a perl regexp or an anonymous subroutine which will check
the input and return true or false depending on the input's validity.

The constraint function takes one parameter, the input to be validated
and returns true or false. It is possible to specify the parameters
that will be passed to the subroutine. For that, use an hash reference
which contains in the I<constraint> element, the anonymous subroutine
or the name of the builtin and in the I<params> element the name of
the fields to pass a parameter to the function. (Don't forget to
include the name of the field to check in that list!) For an example,
look at the I<cc_no> constraint example.

=item constraint_regexp_map

This is a hash reference where the keys are the regular expressions to
use and the values are the constraints to apply. Used to apply
constraints to fields that match a regular expression.  For example,
you could check to see that all fields that end in "_postcode" are
valid Canadian postal codes by using the key '_postcode$' and the
value "postcode".

=back

=cut

sub load_profiles {
    my $self = shift;

    my $file = $self->{profile_file};
    return unless $file;

    die "No such file: $file\n" unless -f $file;
    die "Can't read $file\n"	unless -r _;

    my $mtime = (stat _)[9];
    return if $self->{profiles} and $self->{profiles_mtime} <= $mtime;

    $self->{profiles} = do $file;
    die "Input profiles didn't return an hash ref\n"
      unless ref $self->{profiles} eq "HASH";

    $self->{profiles_mtime} = $mtime;
}

=pod

=head1 VALIDATING INPUT

    my( $valids, $missings, $invalids, $unknowns ) =
	$validator->validate( \%fdat, "customer_infos" );

To validate input you use the validate() method. This method takes two
parameters :

=over

=item data

Contains an hash which should correspond to the form input as
submitted by the user. This hash is not modified by the call to validate.

=item profile

Can be either a name which will be used to lookup the corresponding profile
in the input profiles specification, or it can be an hash reference to the
input profile which should be used.

=back

This method returns a 4 elements array. 

=over

=item valids

This is an hash reference to the valid fields which were submitted in
the data. The data may have been modified by the various filters specified.

=item missings

This is a reference to an array which contains the name of the missing
fields. Those are the fields that the user forget to fill or filled
with space. These fields may comes from the I<required> list or the
I<dependencies> list.

=item invalids

This is a reference to an array which contains the name of the fields
which failed their constraint check.

=item unknowns

This is a list of fields which are unknown to the profile. Whether or
not this indicates an error in the user input is application
dependant.

=back

=cut

sub validate {
    my ( $self, $data, $name ) = @_;

    my $profile;
    if ( ref $name ) {
	$profile = $name;
    } else {
	$self->load_profiles;
	$profile = $self->{profiles}{$name};
	die "No such profile $name\n" unless $profile;
    }
    die "Invalid input profile\n" unless ref $profile eq "HASH";

    # Copy data and assumes that all is valid
    my %valid	    = %$data;
    my @missings    = ();
    my @invalid	    = ();
    my @unknown	    = ();

     # Apply inconditional filters
    foreach my $filter (_arrayify($profile->{filters})) {
		if (defined $filter) {
			# Qualify symbolic references
			$filter = ref $filter ? $filter : "filter_" . $filter;
			foreach my $field ( keys %valid ) {
				no strict 'refs';
				$valid{$field} = $filter->( $valid{$field} );
			}
		}	
    }

    # Apply specific filters
    while ( my ($field,$filters) = each %{$profile->{field_filters} }) {
		foreach my $filter ( _arrayify($filters)) {
			if (defined $filter) {
				# Qualify symbolic references
				$filter = ref $filter ? $filter : "filter_" . $filter;
				no strict 'refs';
		
				$valid{$field} = $filter->( $valid{$field} );
			}	
		}
    }   

    my %required    = map { $_ => 1 } _arrayify($profile->{required});
    my %optional    = map { $_ => 1 } _arrayify($profile->{optional});

    # loop through and add fields to %required and %optional based on regular expressions   
    my $required_re = eval 'sub { $_[0] =~ '. $profile->{required_regexp} . '}' if $profile->{required_regexp};
    die "Error compiling regular expression $required_re: $@" if $@;

    my $optional_re = eval 'sub { $_[0] =~ '. $profile->{optional_regexp} . '}' if $profile->{optional_regexp};
    die "Error compiling regular expression $optional_re: $@" if $@;

    foreach my $k (keys %valid) {
       if ($required_re && $required_re->($k)) {
		  $required{$k} =  1;
       }
       
       if ($optional_re && $optional_re->($k)) {
		  $optional{$k} =  1;
       }
    }

    # Remove all empty fields
    foreach my $field ( keys %valid ) {
	delete $valid{$field} unless length $valid{$field};
    }

    # Check if the presence of some fields makes other optional
    # fields required.
    while ( my ( $field, $deps) = each %{$profile->{dependencies}} ) {
	if ( $valid{$field} ) {
	    foreach my $dep ( _arrayify($deps) ) {
		$required{$dep} = 1;
	    }
	}
    }

    # check dependency groups
    # the presence of any member makes them all required
    foreach my $group (values %{ $profile->{dependency_groups} }) {
       my $require_all = 0;
       foreach my $field (_arrayify($group)) {
	  $require_all = 1 if $valid{$field};
       }
       if ($require_all) {
	  map { $required{$_} = 1 } _arrayify($group); 
       }
    }

    # Find unknown
    @unknown =
      grep { not (exists $optional{$_} or exists $required{$_} ) } keys %valid;
    # and remove them from the list
    foreach my $field ( @unknown ) {
	delete $valid{$field};
    }

    # Fill defaults
    while ( my ($field,$value) = each %{$profile->{defaults}} ) {
	$valid{$field} = $value unless exists $valid{$field};
    }

    # Check for required fields
    foreach my $field ( keys %required ) {
	push @missings, $field unless exists $valid{$field};
    }

    # add in the constraints from the regexp map 
    foreach my $k (keys %valid) {
       foreach my $re (keys %{ $profile->{constraint_regexp_map} }) {
	  if ($k =~ /$re/) {
	      $profile->{constraints}{$k} = $profile->{constraint_regexp_map}{$re}; 
	  }
       }
    }

    # Check constraints
    while ( my ($field,$constraint_spec) = each %{$profile->{constraints}} ) {
	my ($constraint,@params);
	if ( ref $constraint_spec eq "HASH" ) {
	    $constraint = $constraint_spec->{constraint};
	    foreach my $fname ( _arrayify($constraint_spec->{params})  ) {
		push @params, $valid{$fname};
	    }
	} else {
	    $constraint = $constraint_spec;
	    @params     = ( $valid{$field} );
	}
	next unless exists $valid{$field};

	unless ( ref $constraint ) {
	    # Check for regexp constraint
	    if ( $constraint =~ m@^\s*(/.+/|m(.).+\2)[cgimosx]*\s*$@ ) {
		my $sub = eval 'sub { $_[0] =~ '. $constraint . '}';
		die "Error compiling regular expression $constraint: $@" if $@;
		$constraint = $sub;
		# Cache for next use
		if ( ref $constraint_spec eq "HASH" ) {
		    $constraint_spec->{constraint} = $sub;
		} else {
		    $profile->{constraints}{$field} = $sub;
		}
	    } else {
		# Qualify symbolic reference
		$constraint = "valid_" . $constraint;
	    }
	}
	no strict 'refs';

	unless ( $constraint->( @params ) ) {
	    delete $valid{$field};
	    push @invalid, $field;
	}
    }
    return ( \%valid, \@missings, \@invalid, \@unknown );
}

# takes string or array ref as input
# returns array
sub _arrayify {
   # if the input is undefined, we just return that. -mls
   my $val = shift || return undef;

   if ( ref $val ) {
		# if it's a reference, return an array unless it points an empty array. -mls
		return $val->[0] ? @$val : undef;   
   } 
   else {
		# if it's a string, return an array unless the string is missing or empty. -mls
		return (length $val) ? ($val) : undef;   
   }
}

=pod

=head1 INPUT FILTERS

These are the builtin filters which may be specified as a name in the
I<filters> and I<field_filters> parameters of the input profile. You may
also call these functions directly through the procedural interface by 
either importing them directly or importing the whole I<:filters> group. For
example, if you want to access the I<trim> function directly, you could either do:

    use Data::FormValidator (qw/filter_trim/);
    or
    use Data::FormValidator (:filters);

    $string = filter_trim($string);

Notice that when you call filters directly, you'll need to prefix the filter name with
"filter_".


=over

=item trim

Remove white space at the front and end of the fields.

=cut

sub filter_trim {
    my $value = shift;

    # Remove whitespace at the front
    $value =~ s/^\s+//o;

    # Remove whitespace at the end
    $value =~ s/\s+$//o;

    return $value;
}

=pod

=item strip

Runs of white space are replaced by a single space.

=cut

sub filter_strip {
    my $value = shift;

    # Strip whitespace
    $value =~ s/\s+/ /g;

    return $value;
}

=pod

=item digit

Remove non digits characters from the input.

=cut

sub filter_digit {
    my $value = shift;
    $value =~ s/\D//g;

    return $value;
}

=pod

=item alphanum

Remove non alphanumerical characters from the input.

=cut

sub filter_alphanum {
    my $value = shift;
    $value =~ s/\W//g;
    return $value;
}

=pod

=item integer

Extract from its input a valid integer number.

=cut

sub filter_integer {
    my $value = shift;
    $value =~ tr/0-9+-//dc;
    ($value) =~ m/([-+]?\d+)/;
    return $value;
}

=pod

=item pos_integer

Extract from its input a valid positive integer number.

=cut

sub filter_pos_integer {
    my $value = shift;
    $value =~ tr/0-9+//dc;
    ($value) =~ m/(\+?\d+)/;
    return $value;
}

=pod

=item neg_integer

Extract from its input a valid negative integer number.

=cut

sub filter_neg_integer {
    my $value = shift;
    $value =~ tr/0-9-//dc;
    ($value) =~ m/(-\d+)/;
    return $value;
}

=pod

=item decimal

Extract from its input a valid decimal number.

=cut

sub filter_decimal {
    my $value = shift;
    # This is a localization problem, but anyhow...
    $value =~ tr/,/./;
    $value =~ tr/0-9.+-//dc;
    ($value) =~ m/([-+]?\d+\.?\d*)/;
    return $value;
}

=pod

=item pos_decimal

Extract from its input a valid positive decimal number.

=cut

sub filter_pos_decimal {
    my $value = shift;
    # This is a localization problem, but anyhow...
    $value =~ tr/,/./;
    $value =~ tr/0-9.+//dc;
    ($value) =~ m/(\+?\d+\.?\d*)/;
    return $value;
}

=pod

=item neg_decimal

Extract from its input a valid negative decimal number.

=cut

sub filter_neg_decimal {
    my $value = shift;
    # This is a localization problem, but anyhow...
    $value =~ tr/,/./;
    $value =~ tr/0-9.-//dc;
    ($value) =~ m/(-\d+\.?\d*)/;
    return $value;
}

=pod

=item dollars

Extract from its input a valid number to express dollars like currency.

=cut

sub filter_dollars {
    my $value = shift;
    $value =~ tr/,/./;
    $value =~ tr/0-9.+-//dc;
    ($value) =~ m/(\d+\.?\d?\d?)/;
    return $value;
}

=pod

=item phone

Filters out characters which aren't valid for an phone number. (Only
accept digits [0-9], space, comma, minus, parenthesis, period and pound [#].)

=cut

sub filter_phone {
    my $value = shift;
    $value =~ s/[^\d,\(\)\.\s,\-#]//g;
    return $value;
}

=pod

=item sql_wildcard

Transforms shell glob wildcard (*) to the SQL like wildcard (%).

=cut

sub filter_sql_wildcard {
    my $value = shift;
    $value =~ tr/*/%/;
    return $value;
}

=pod

=item quotemeta

Calls the quotemeta (quote non alphanumeric character) builtin on its
input.

=cut

sub filter_quotemeta {
    quotemeta $_[0];
}

=pod

=item lc

Calls the lc (convert to lowercase) builtin on its input.

=cut

sub filter_lc {
    lc $_[0];
}

=pod

=item uc

Calls the uc (convert to uppercase) builtin on its input.

=cut

sub filter_uc {
    uc $_[0];
}

=pod

=item ucfirst

Calls the ucfirst (Uppercase first letter) builtin on its input.

=cut

sub filter_ucfirst {
    ucfirst $_[0];
}


=pod

=back

=head1 BUILTIN VALIDATORS

Those are the builtin constraint that can be specified by name in the
input profiles. You may
also call these functions directly through the procedural interface by 
either importing them directly or importing the whole I<:validators> group. For
example, if you want to access the I<email> validator directly, you could either do:

    use Data::FormValidator (qw/valid_email/);
    or
    use Data::FormValidator (:validators);

    if (valid_email($email)) {
      # do something with the email address
    }

Notice that when you call validators directly, you'll need to prefix the validator name with
"valid_" 

=over

=item email

Checks if the email LOOKS LIKE an email address. This checks if the
input contains one @, and a two level domain name. The address portion
is checked quite liberally. For example, all those probably invalid
address would pass the test :

    nobody@top.domain
    %?&/$()@nowhere.net
    guessme@guess.m

=cut

# Many of the following validators are taken from
# MiniVend 3.14. (http://www.minivend.com)
# Copyright 1996-1999 by Michael J. Heins <mike@heins.net>

sub valid_email {
    my $email = shift;

    return $email =~ /[\040-\176]+\@[-A-Za-z0-9.]+\.[A-Za-z]+/;
}

my $state = <<EOF;
AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD
MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA PR RI
SC SD TN TX UT VT VA WA WV WI WY DC AP FP FPO APO GU VI
EOF

my $province = <<EOF;
AB BC MB NB NF NS NT ON PE QC SK YT YK
EOF

=pod

=item state_or_province

This one checks if the input correspond to an american state or a canadian
province.

=cut

sub valid_state_or_province {
    return valid_state(@_) || valid_province(@_);
}

=pod

=item state

This one checks if the input is a valid two letter abbreviation of an 
american state.

=cut

sub valid_state {
    my $val = shift;
    return $state =~ /\b$val\b/i;
}

=pod

=item province

This checks if the input is a two letter canadian province
abbreviation.

=cut

sub valid_province {
    my $val = shift;
    return $province =~ /\b$val\b/i;
}

=pod

=item zip_or_postcode

This constraints checks if the input is an american zipcode or a
canadian postal code.

=cut

sub valid_zip_or_postcode {
    return valid_zip(@_) || valid_postcode(@_);
}

=pod

=item postcode

This constraints checks if the input is a valid Canadian postal code.

=cut

sub valid_postcode {
    my $val = shift;
    $val =~ s/[_\W]+//g;
    return $val =~ /^[ABCEGHJKLMNPRSTVXYabceghjklmnprstvxy]\d[A-Za-z][- ]?\d[A-Za-z]\d$/;
}

=pod

=item zip

This input validator checks if the input is a valid american zipcode :
5 digits followed by an optional mailbox number.

=cut

sub valid_zip {
    my $val = shift;
    return $val =~ /^\s*\d{5}(?:[-]\d{4})?\s*$/;
}

=pod

=item phone

This one checks if the input looks like a phone number, (if it
contains at least 6 digits.)

=cut

sub valid_phone {
    my $val = shift;

    return $val =~ tr/0-9// >= 6;
}

=pod

=item american_phone

This constraints checks if the number is a possible North American style
of phone number : (XXX) XXX-XXXX. It has to contains more than 7 digits.

=cut

sub valid_american_phone {
    my $val = shift;
    return $val =~ tr/0-9// >= 7;
}

=pod

=item cc_number

This is takes two parameters, the credit card number and the credit cart
type. You should take the hash reference option for using that constraint.

The number is checked only for plausibility, it checks if the number could
be valid for a type of card by checking the checksum and looking at the number
of digits and the number of digits of the number.

This functions is only good at weeding typos and such. IT DOESN'T
CHECK IF THERE IS AN ACCOUNT ASSOCIATED WITH THE NUMBER.

=cut

# This one is taken from the contributed program to 
# MiniVend by Bruce Albrecht
sub valid_cc_number {
    my ( $the_card, $card_type ) = @_;

    my ($index, $digit, $product);
    my $multiplier = 2;        # multiplier is either 1 or 2
    my $the_sum = 0;

    return 0 if length($the_card) == 0;

    # check card type
    return 0 unless $card_type =~ /^[admv]/i;

    return 0 if ($card_type =~ /^v/i && substr($the_card, 0, 1) ne "4") ||
      ($card_type =~ /^m/i && substr($the_card, 0, 1) ne "5") ||
	($card_type =~ /^d/i && substr($the_card, 0, 4) ne "6011") ||
	  ($card_type =~ /^a/i && substr($the_card, 0, 2) ne "34" &&
	   substr($the_card, 0, 2) ne "37");

    # check for valid number of digits.
    $the_card =~ s/\s//g;    # strip out spaces
    return 0 if $the_card !~ /^\d+$/;

    $digit = substr($the_card, 0, 1);
    $index = length($the_card)-1;
    return 0 if ($digit == 3 && $index != 14) ||
        ($digit == 4 && $index != 12 && $index != 15) ||
            ($digit == 5 && $index != 15) ||
                ($digit == 6 && $index != 13 && $index != 15);


    # calculate checksum.
    for ($index--; $index >= 0; $index --)
    {
        $digit=substr($the_card, $index, 1);
        $product = $multiplier * $digit;
        $the_sum += $product > 9 ? $product - 9 : $product;
        $multiplier = 3 - $multiplier;
    }
    $the_sum %= 10;
    $the_sum = 10 - $the_sum if $the_sum;

    # return whether checksum matched.
    $the_sum == substr($the_card, -1);
}

=pod

=item cc_exp

This one checks if the input is in the format MM/YY or MM/YYYY and if
the MM part is a valid month (1-12) and if that date is not in the past.

=cut

sub valid_cc_exp {
    my $val = shift;

    my ($month, $year) = split('/', $val);
    return 0 if $month !~ /^\d+$/ || $year !~ /^\d+$/;
    return 0 if $month <1 || $month > 12;
    $year += ($year < 70) ? 2000 : 1900 if $year < 1900;
    my @now=localtime();
    $now[5] += 1900;
    return 0 if ($year < $now[5]) || ($year == $now[5] && $month <= $now[4]);

    return 1;
}

=pod

=item cc_type

This one checks if the input field starts by M(asterCard), V(isa),
A(merican express) or D(iscovery).

=cut

sub valid_cc_type {
    my $val = shift;
    return $val =~ /^[MVAD]/i;
}

1;

__END__

=pod

=back

=head1 CREDITS

Some of those input validation functions have been taken from MiniVend
by Michael J. Heins <mike@heins.net>

The credit card checksum validation was taken from contribution by
Bruce Albrecht <bruce.albrecht@seag.fingerhut.com> to the MiniVend
program.

Mark Stosberg contributed a number of enhancements including
I<required_regexp>, I<optional_regexp> and I<constraint_regexp_map>

 

=head1 AUTHOR

Copyright (c) 1999 Francis J. Lacoste and iNsu Innovations Inc.
All rights reserved.

Parts Copyright 1996-1999 by Michael J. Heins <mike@heins.net>
Parts Copyright 1996-1999 by Bruce Albrecht  <bruce.albrecht@seag.fingerhut.com>
Parts Copyright 2001      by Mark Stosberg <mark@summersault.com>

This program is free software; you can redistribute it and/or modify
it under the terms as perl itself.

=cut

