#
#    FormValidator.pm - Object that validates form input data.
#
#    This file is part of Data::FormValidator.
#
#    Author: Francis J. Lacoste <francis.lacoste@iNsu.COM>
#    Maintainer: Mark Stosberg <mark@stosberg.com>
#
#    Copyright (C) 1999 Francis J. Lacoste, iNsu Innovations
#    Parts Copyright 1996-1999 by Michael J. Heins <mike@heins.net>
#    Parts Copyright 1996-1999 by Bruce Albrecht  <bruce.albrecht@seag.fingerhut.com>
#    Parts Copyright 2001-2002 by Mark Stosberg <mark@stosberg.com>
#
#    Parts of this module are based on work by
#    Bruce Albrecht, <bruce.albrecht@seag.fingerhut.com> contributed to
#    MiniVend.
#
#    Parts also based on work by Michael J. Heins <mikeh@minivend.com>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms same terms as perl itself.
#
#    $Header: /cvsroot/cascade/dfv/lib/Data/FormValidator.pm,v 1.8 2003/03/23 02:57:23 markjugg Exp $
package Data::FormValidator;

use vars qw( $VERSION $AUTOLOAD);

$VERSION = '2.02';

require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(
       	filter_alphanum
	filter_decimal
	filter_digit
	filter_integer
	filter_lc
	filter_neg_decimal
	filter_neg_integer
	filter_phone
	filter_pos_decimal
	filter_pos_integer
	filter_quotemeta
	filter_sql_wildcard
	filter_strip
	filter_trim
	filter_uc
	filter_ucfirst
	valid_american_phone
	valid_cc_exp
	valid_cc_number
	valid_cc_type
	valid_email
	valid_ip_address
	valid_phone
	valid_postcode
	valid_province
	valid_state
	valid_state_or_province
	valid_zip
	valid_zip_or_postcode
	match_american_phone
	match_cc_exp
	match_cc_number
	match_cc_type
	match_email
	match_ip_address
	match_phone
	match_postcode
	match_province
	match_state
	match_state_or_province
	match_zip
	match_zip_or_postcode	
);

%EXPORT_TAGS = (
    filters => [qw/
          filter_alphanum
          filter_decimal
          filter_digit
          filter_dollars
          filter_integer
          filter_lc
          filter_neg_decimal
          filter_neg_integer
          filter_phone
          filter_pos_decimal
          filter_pos_integer
          filter_quotemeta
          filter_sql_wildcard
          filter_strip
          filter_trim
          filter_uc
          filter_ucfirst
    /],
    validators => [qw/
	valid_american_phone
	valid_cc_exp
	valid_cc_number
	valid_cc_type
	valid_email
	valid_ip_address
	valid_phone
	valid_postcode
	valid_province
	valid_state
	valid_state_or_province
	valid_zip
	valid_zip_or_postcode
/],
    matchers => [qw/
	match_american_phone
	match_cc_exp
	match_cc_number
	match_cc_type
	match_email
	match_ip_address
	match_phone
	match_postcode
	match_province
	match_state
	match_state_or_province
	match_zip
	match_zip_or_postcode
/],		
);

use strict;
use Carp; # generate better errors with more context
use Symbol;


sub AUTOLOAD {
    my $name = $AUTOLOAD;

    # Since all the valid_* routines are essentially identical we're
    # going to generate them dynamically from match_ routines with the same names.
    if ($name =~ m/^(.*::)valid_(.*)/) {
		no strict qw/refs/;
		return defined &{$1.'match_' . $2}(@_);
    }
    else { 
		die "subroutine '$name' not found"; 
	}
}

sub DESTROY {}

=pod

=head1 NAME

Data::FormValidator - Validates user input (usually from an HTML form) based
on input profile.

=head1 SYNOPSIS

    use Data::FormValidator;

	# For the common case of a validating a single profile provided through a hash reference,
	# using 'validate' like this is the simplest solution 
	my ($valids, $missings, $invalids, $unknowns) 
		= Data::FormValidator->validate(\%fdat, \%profile);

    # This is an example of using a validation profile defined in a seperate file
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

    bless { 
		profile_file => $profile_file,
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

		require_some => {
			# require any two fields from this group
			city_or_state_or_zipcode => [ 2, qw/city state zipcode/ ], 
		},	
	    constraints  =>
		{
		    email	=> "email",
		    fax		=> "american_phone",
		    phone	=> "american_phone",
		    zipcode	=> '/^\s*\d{5}(?:[-]\d{4})?\s*$/',
		    state	=> "state",
		},
        untaint_constraint_fields => [qw(zipcode state)],
	    constraint_regexp_map => {
		'/_postcode$/'	=> 'postcode',
		'/_province$/'  => 'province',		      
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
            "pay_type" => {
                check => [ qw( check_no ) ],
             }
	     },
             untaint_all_constraints => 1,
	     constraints => {
			cc_no      => {  
				constraint  => "cc_number",
				params	    => [ qw( cc_no cc_type ) ],
			},
			cc_type	=> "cc_type",
			cc_exp	=> "cc_exp",
	      },
	    filters       => [ "trim" ],
	    field_filters => { cc_no => "digit" },
	    field_filter_regexp_map => {
			'/_name$/'	=> 'ucfirst',
	    },
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

=item required_regexp

This is a regular expression used to specify additional fieds which are
required. For example, if you wanted all fields names that begin with I<user_> 
to be required, you could use the regular expression, /^user_/

=item require_some

This is a reference to a hash which defines groups of fields where 
1 or more field from the group should be required, but exactly
which fields doesn't matter. The keys in the hash are the group names. 
These are returned as "missing" unless the required number of fields
from the group has been filled in. The values in this hash are
array references. The first element in this hash should be the 
number of fields in the group that is required. If the first
first field in the array is not an a digit, a default of "1" 
will be used. 

=item optional

This is an array reference which contains the name of optional fields.
These are fields which MAY be present and if they are, they will be
check for valid input. Any fields not in optional or required list
will be reported as unknown.

=item optional_regexp

This is a regular expression used to specify additional fieds which are
optional. For example, if you wanted all fields names that begin with I<user_> 
to be optional, you could use the regular expression, /^user_/

=item dependencies

This is an hash reference which contains dependencies information.
This is for the case where one optional fields has other requirements.
The dependencies can be specified with an array reference.  For example,
if you enter your credit card number, the field cc_exp and cc_type should
also be present.  If the dependencies are specified with a hash reference
then the additional constraint is added that the optional field must equal
a key for the dependencies to be added. For example, if the pay_type field
is equal to "check" then the check_no field is required.  Any fields in
the dependencies list that is missing when the target is present will be
reported as missing.

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

=item field_filter_regexp_map

This is a hash reference where the keys are the regular expressions to
use and the values are references to arrays of filters which will be
applied to specific input fields. Used to apply filters to fields that
match a regular expression. For example, you could make the first letter
uppercase of all fields that end in "_name" by using the key '/_name$/'
and the value "ucfirst".


=item constraints

This is a reference to an hash which contains the constraints that
will be used to check whether or not the field contains valid data.
The keys in this hash are the field names. The values can any of the following:

=over 

=item o

the name of a builtin constraint function (see below)

B<Example>: 

	my_zipcode_field 	=> 'zip',

=item o 

a perl regular expression

B<Example>: 

	my_zipcode_field   => '/^\d{5}$/', # match exactly 5 digits

=item o

a subroutine reference

This will check the input and return true or false depending on the input's validity.
By default, the constraint function takes one parameter, the field to be
validated.  To validate a field based more inputs than just the field itself,
see C<VALIDATING INPUT BASED ON MULTIPLE FIELDS>.


B<Examples>:

	my_zipcode_field => sub { my $val = shift;  return $val =~ '/^\d{5}$/' }, 
	
	# OR you can reference a subroutine, which should work like the one above
	my_zipcode_field => \&my_validation_routine, 

=item o 

an array reference

An array reference is used to apply multiple constraints to a single
field. See L<MULTIPLE CONSTRAINTS> below.

=back

=item constraint_regexp_map

This is a hash reference where the keys are the regular expressions to
use and the values are the constraints to apply. Used to apply
constraints to fields that match a regular expression.  For example,
you could check to see that all fields that end in "_postcode" are
valid Canadian postal codes by using the key '_postcode$' and the
value "postcode".

=item untaint_all_constraints

If this field is set all form data that passes a constraint will be
untainted. The untainted data will be returned in the valid
hash. Untainting is based on the pattern match used by the
constraint. If you write your own regular expressions and only match
part of the string then you'll only get part of the string in the
valid hash. It is a good idea to write you own constraints like
/^regex$/. That way you match the whole string.

This is overridden by untaint_constraint_fields

=item untaint_constraint_fields

Specifies that one or more fields will be untainted if they pass their
constraint(s). This can be set to a single field name or an array
reference of field names. The untainted data will be returned in the
valid hash. Untainting is based on the pattern match used by the
constraint. If you write your own regular expressions and only match
part of the string then you'll only get part of the string in the
valid hash. It is a good idea to write you own constraints like
/^regex$/. That way you match the whole string.

This is overrides the untaint_all_constraints flag.

=item missing_optional_valid

This can be set to a true value (such as 1) to cause missing optional
fields to be included in the valid hash. By default they are not
included-- this is the historical behavior. 

=item validator_packages 

This key is used to define other packages which contain validation routines. 
Set this key to a single package name, or an arrayref of several. All of its
subs beginning with 'match_' and 'valid_' will be imported into Data::FormValidator.
This lets you reference them in a constraint with just their name (the part
after the underscore).  You can even override the provided validators.

B<Example>:

	validator_packages => [qw(ProjectName::Validate::Basic)],

=back

=head1 VALIDATING INPUT BASED ON MULTIPLE FIELDS

You can pass more than one value into a validation routine. 
For that, the value of the constraint should be a 
a hash reference. One key should named C<constraint> and should have a value 
set to the reference of the subroutine or the name of a built-in validator.
Another required key is I<params>. The value of the I<params> key is a
reference to an array of the other elements to use in the validation. If the
element is a scalar, it is assumed to a field name. If the value is a reference,
what the reference points to is passed into the subroutine. 
(Don't forget to include the name of the field to check in that list!)

B<Example>:

		cc_no  => {  
			constraint  => "cc_number",
			params	     => [ qw( cc_no cc_type ) ],
		},


=head1 MULTIPLE CONSTRAINTS

Multiple constraints can be applied to a single field by defining
the value of the constraint to be an array reference. Each of the values in this array
can be one of the constraint types defined above: the name of a built-in validator, 
a regular expression, or a subroutine reference. 

It's important to know which of the constraints failed, so fields defined
with multiple constraints will have an array ref returned in the C<@invalids>
array instead of just a string. The first element in this array is the
name of the field, and the remaining fields are the names of the failed
constraints. 

When using multiple constraints it is important to return the name of the
constraint that failed so you can distinquish between them. To do that,
either use a named constraint, or use the hash ref method of defining a
constraint and include a C<name> key with a value set to the name of your
constraint.  Here's an example:

  my_zipcode_field => [
  	'zip',
	{ 
		constraint =>  '/^406/', 
		name 	   =>  'starts_with_406',
	}
	],

You can use an array reference with a single constraint in it if you just want
to have the name of your failed constraint returned in the above fashion. 

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

This is a the data you want to validate. It can take two possible forms. 
First, it can ba reference to a hash. Secondly, it can be a CGI.pm object.
In either case, this data is not modified by Data::FormValidator.
Support for CGI.pm compatible objects is planned. Send a patch or get in touch
if you are interested. 


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

	# check the profile syntax or die with an error. 
	_check_profile_syntax($profile);

    
    # Copy data and assumes that all is valid
    my %valid	    =  _get_data($data);
    my @missings    = ();
    my @invalid	    = ();
    my @unknown	    = ();

    # import valid_* subs from requested packages
	foreach my $package (_arrayify($profile->{validator_packages})) {
		if ( !exists $self->{imported_validators}{$package} ) {
			eval "require $package";
			if ($@) {
				die "Couldn't load validator package '$package': $@";
			}
			my $package_ref = qualify_to_ref("${package}::");
			my @subs = grep(/^(valid_|match_)/, keys(%{*{$package_ref}}));
			foreach my $sub (@subs) {
				# is it a sub? (i.e. make sure it's not a scalar, hash, etc.)
				my $subref = *{qualify_to_ref("${package}::$sub")}{CODE};
				if (defined $subref) {
					*{qualify_to_ref($sub)} = $subref;
				}
			}
			$self->{imported_validators}{$package} = 1;
		}
	}

	# Apply inconditional filters
    foreach my $filter (_arrayify($profile->{filters})) {
		if (defined $filter) {
			# Qualify symbolic references
			$filter = ref $filter ? $filter : *{qualify_to_ref("filter_$filter")}{CODE};
			foreach my $field ( keys %valid ) {
				# apply filter, modifying %valid by reference
				_filter_apply(\%valid,$field,$filter);
			}
		}	
    }

    # Apply specific filters
    while ( my ($field,$filters) = each %{$profile->{field_filters} }) {
		foreach my $filter ( _arrayify($filters)) {
			if (defined $filter) {
				# Qualify symbolic references
				$filter = ref $filter ? $filter : *{qualify_to_ref("filter_$filter")}{CODE};
				
				# apply filter, modifying %valid by reference
				_filter_apply(\%valid,$field,$filter);
			}	
		}
    }   

	# add in specific filters from the regexp map
	while ( my ($re,$filters) = each %{$profile->{field_filter_regexp_map} }) {
		my $sub = eval 'sub { $_[0] =~ '. $re . '}';
		die "Error compiling regular expression $re: $@" if $@;

		foreach my $filter ( _arrayify($filters)) {
			if (defined $filter) {
				# Qualify symbolic references
				$filter = ref $filter ? $filter : *{qualify_to_ref("filter_$filter")}{CODE};
				no strict 'refs';

				# find all the keys that match this RE and apply filters to them
				for my $field (grep { $sub->($_) } (keys %valid)) {
					# apply filter, modifying %valid by reference
					_filter_apply(\%valid,$field,$filter);
				}
			}	
		}
	}
 
    my %required    = map { $_ => 1 } _arrayify($profile->{required});
    my %optional    = map { $_ => 1 } _arrayify($profile->{optional});

    # loop through and add fields to %required and %optional based on regular expressions   
    my $required_re;
    if ($profile->{required_regexp}) {
	$required_re = eval 'sub { $_[0] =~ '. $profile->{required_regexp} . '}';
	die "Error compiling regular expression $required_re: $@" if $@;
    }

    my $optional_re;
    if ($profile->{optional_regexp}) {
	$optional_re = eval 'sub { $_[0] =~ '. $profile->{optional_regexp} . '}';
	die "Error compiling regular expression $optional_re: $@" if $@;
    }

    foreach my $k (keys %valid) {
       if ($required_re && $required_re->($k)) {
		  $required{$k} =  1;
       }
       
       if ($optional_re && $optional_re->($k)) {
		  $optional{$k} =  1;
       }
    }

	# handle "require_some"
	my %require_some;
 	while ( my ( $field, $deps) = each %{$profile->{require_some}} ) {
        foreach my $dep (_arrayify($deps)){
             $require_some{$dep} = 1;
        }
    }

	
	# Remove all empty fields
	foreach my $field (keys %valid) {
		if (ref $valid{$field}) {
			if ( ref $valid{$field} eq 'ARRAY' ) {
				for (my $i = 0; $i < scalar @{ $valid{$field} }; $i++) {
					delete $valid{$field}->[$i] unless length $valid{$field}->[$i];
				}
			}
		}
		else {
			delete $valid{$field} unless length $valid{$field};
		}
	}

    # Check if the presence of some fields makes other optional fields required.
    while ( my ( $field, $deps) = each %{$profile->{dependencies}} ) {
        if ($valid{$field}) {
			if (ref($deps) eq 'HASH') {
				foreach my $key (keys %$deps) {
					if($valid{$field} eq $key){
						foreach my $dep (_arrayify($deps->{$key})){
							$required{$dep} = 1;
						}
					}
				}
			}
            else {
                foreach my $dep (_arrayify($deps)){
                    $required{$dep} = 1;
                }
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
      grep { not (exists $optional{$_} or exists $required{$_} or exists $require_some{$_} ) } keys %valid;
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

	# Check for the absence of require_some fields
	while ( my ( $field, $deps) = each %{$profile->{require_some}} ) {
		my $enough_required_fields = 0;
		my @deps = _arrayify($deps);
		# num fields to require is first element in array if looks like a digit, 1 otherwise. 
		my $num_fields_to_require = ($deps[0] =~ m/^\d+$/) ? $deps[0] : 1;
		foreach my $dep (@deps){
			$enough_required_fields++ if exists $valid{$dep};
		}
		push @missings, $field unless ($enough_required_fields >= $num_fields_to_require);
	}

    # add in the constraints from the regexp map 
	foreach my $re (keys %{ $profile->{constraint_regexp_map} }) {
		my $sub = eval 'sub { $_[0] =~ '. $re . '}';
		die "Error compiling regular expression $re: $@" if $@;

		# find all the keys that match this RE and add a constraint for them
		map { $profile->{constraints}{$_} = $profile->{constraint_regexp_map}{$re} }
		grep { $sub->($_) } (keys %valid);	
	}
 
    # Check constraints

    #Decide which fields to untaint
    my ($untaint_all, %untaint_hash);
	if (defined($profile->{untaint_constraint_fields})) {
		if (ref $profile->{untaint_constraint_fields} eq "ARRAY") {
			foreach my $field (@{$profile->{untaint_constraint_fields}}) {
				$untaint_hash{$field} = 1;
			}
		}
		elsif ($valid{$profile->{untaint_constraint_fields}}) {
			$untaint_hash{$profile->{untaint_constraint_fields}} = 1;
		}
	}
    elsif ((defined($profile->{untaint_all_constraints}))
	   && ($profile->{untaint_all_constraints} == 1)) {
	   $untaint_all = 1;
    }
    
    while ( my ($field,$constraint_list) = each %{$profile->{constraints}} ) {

       next unless exists $valid{$field};

	   my $is_constraint_list = 1 if (ref $constraint_list eq 'ARRAY');
	   my $untaint_this =  ($untaint_all || $untaint_hash{$field} || 0);

	   my @invalid_list;
	   foreach my $constraint_spec (_arrayify($constraint_list)) {
			 my $c = _constraint_hash_build($field,$constraint_spec,$untaint_this);

			 my $is_value_list = 1 if ref $valid{$field};
			 if ($is_value_list) {
				 foreach (my $i = 0; $i < scalar @{ $valid{$field}} ; $i++) {
					 my @params = _constraint_input_build($c,$valid{$field}->[$i]);

					 my ($match,$failed) = _constraint_check_match($c,\@params);
					 if ($failed) {
						push @invalid_list, $failed;
					 }
					 else {
						 $valid{$field}->[$i] = $match if $untaint_this;
					 }
				 }
			 }
			 else {
				my @params = _constraint_input_build($c,$valid{$field});
				my ($match,$failed) = _constraint_check_match($c,\@params);
				if ($failed) {
					push @invalid_list, $failed
				}
				else {
					$valid{$field} = $match if $untaint_this;

				}
			 }
	   }

	   if (@invalid_list) {
		   if ($is_constraint_list) {
				push @invalid, [$field, map { $_->{name} } @invalid_list];
		   }
		   else {
			   push @invalid, $field;
		   }
		   delete $valid{$field};
	   }

   }

    # add back in missing optional fields from the data hash if we need to
	foreach my $field ( keys %$data ) {
		if ($profile->{missing_optional_valid} and $optional{$field} and (not exists $valid{$field})) {
			$valid{$field} = undef;
		}
	}

    return ( \%valid, \@missings, \@invalid, \@unknown );
}

# takes string or array ref as input
# returns array
sub _arrayify {
   # if the input is undefined, return an empty list
   my $val = shift;
   defined $val or return ();

   if ( ref $val eq 'ARRAY' ) {
		# if it's a reference, return an array unless it points an empty array. -mls
                return (length $val->[0]) ? @$val : ();
   } 
   else {
		# if it's a string, return an array unless the string is missing or empty. -mls
                return (length $val) ? ($val) : ();
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

Each validator also has a version that returns the untainted value if
the validation succeeded. You may call these functions directly
through the procedural interface by either importing them directly or
importing the I<:matchers> group. For example if you want to untaint a
value with the I<email> validator directly you may:

    if ($email = match_email($email)) {
        system("echo $email");
    }
    else {
        die "Unable to validate email";
    }

Notice that when you call validators directly and want them to return an
untainted value, you'll need to prefix the validator name with "match_" 


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

sub match_email {
    my $email = shift;

    if ($email =~ /^([\040-\176]+\@[-A-Za-z0-9.]+\.[A-Za-z]+)$/) {
	return $1;
    }
    else { return undef; }
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

sub match_state_or_province {
    my $match;
    if ($match = match_state(@_)) { return $match; }
    else {return match_province(@_); }
}

=pod

=item state

This one checks if the input is a valid two letter abbreviation of an 
american state.

=cut

sub match_state {
    my $val = shift;
    if ($state =~ /\b($val)\b/i) {
	return $1;
    }
    else { return undef; }
}

=pod

=item province

This checks if the input is a two letter canadian province
abbreviation.

=cut

sub match_province {
    my $val = shift;
    if ($province =~ /\b($val)\b/i) {
	return $1;
    }
    else { return undef; }
}

=pod

=item zip_or_postcode

This constraints checks if the input is an american zipcode or a
canadian postal code.

=cut

sub match_zip_or_postcode {
    my $match;
    if ($match = match_zip(@_)) { return $match; }
    else {return match_postcode(@_)};
}
=pod

=item postcode

This constraints checks if the input is a valid Canadian postal code.

=cut

sub match_postcode {
    my $val = shift;
    #$val =~ s/[_\W]+//g;
    if ($val =~ /^([ABCEGHJKLMNPRSTVXYabceghjklmnprstvxy][_\W]*\d[_\W]*[A-Za-z][_\W]*[- ]?[_\W]*\d[_\W]*[A-Za-z][_\W]*\d[_\W]*)$/) {
	return $1;
    }
    else { return undef; }
}

=pod

=item zip

This input validator checks if the input is a valid american zipcode :
5 digits followed by an optional mailbox number.

=cut

sub match_zip {
    my $val = shift;
    if ($val =~ /^(\s*\d{5}(?:[-]\d{4})?\s*)$/) {
	return $1;
    }
    else { return undef; }
}

=pod

=item phone

This one checks if the input looks like a phone number, (if it
contains at least 6 digits.)

=cut

sub match_phone {
    my $val = shift;

    if ($val =~ /^((?:\D*\d\D*){6,})$/) {
	return $1;
    }
    else { return undef; }
}

=pod

=item american_phone

This constraints checks if the number is a possible North American style
of phone number : (XXX) XXX-XXXX. It has to contains 7 or more digits.

=cut

sub match_american_phone {
    my $val = shift;

    if ($val =~ /^((?:\D*\d\D*){7,})$/) {
	return $1;
    }
    else { return undef; }
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

sub match_cc_number {
    my ( $the_card, $card_type ) = @_;
    my $orig_card = $the_card; #used for return match at bottom
    my ($index, $digit, $product);
    my $multiplier = 2;        # multiplier is either 1 or 2
    my $the_sum = 0;

    return undef if length($the_card) == 0;

    # check card type
    return undef unless $card_type =~ /^[admv]/i;

    return undef if ($card_type =~ /^v/i && substr($the_card, 0, 1) ne "4") ||
      ($card_type =~ /^m/i && substr($the_card, 0, 1) ne "5") ||
	($card_type =~ /^d/i && substr($the_card, 0, 4) ne "6011") ||
	  ($card_type =~ /^a/i && substr($the_card, 0, 2) ne "34" &&
	   substr($the_card, 0, 2) ne "37");

    # check for valid number of digits.
    $the_card =~ s/\s//g;    # strip out spaces
    return undef if $the_card !~ /^\d+$/;

    $digit = substr($the_card, 0, 1);
    $index = length($the_card)-1;
    return undef if ($digit == 3 && $index != 14) ||
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
    if ($the_sum == substr($the_card, -1)) {
	if ($orig_card =~ /^([\d\s]*)$/) { return $1; }
	else { return undef; }
    }
    else {
	return undef;
    }
}

=pod

=item cc_exp

This one checks if the input is in the format MM/YY or MM/YYYY and if
the MM part is a valid month (1-12) and if that date is not in the past.

=cut

sub match_cc_exp {
    my $val = shift;
    my ($matched_month, $matched_year);

    my ($month, $year) = split('/', $val);
    return undef if $month !~ /^(\d+)$/;
    $matched_month = $1;

    return undef if  $year !~ /^(\d+)$/;
    $matched_year = $1;

    return undef if $month <1 || $month > 12;
    $year += ($year < 70) ? 2000 : 1900 if $year < 1900;
    my @now=localtime();
    $now[5] += 1900;
    return undef if ($year < $now[5]) || ($year == $now[5] && $month <= $now[4]);

    return "$matched_month/$matched_year";
}

=pod

=item cc_type

This one checks if the input field starts by M(asterCard), V(isa),
A(merican express) or D(iscovery).

=cut

sub match_cc_type {
    my $val = shift;
    if ($val =~ /^([MVAD].*)$/i) { return $1; }
    else { return undef; }
}

=pod

=item ip_address

This checks if the input is formatted like an IP address (v4)

=cut

# contributed by Juan Jose Natera Abreu <jnatera@net-uno.net>

sub match_ip_address {
   my $val = shift;
   if ($val =~ m/^((\d+)\.(\d+)\.(\d+)\.(\d+))$/) {
       if 
	   (($2 >= 0 && $2 <= 255) && ($3 >= 0 && $3 <= 255) && ($4 >= 0 && $4 <= 255) && ($5 >= 0 && $5 <= 255)) {
	       return $1;
	   }
       else { return undef; }
   }
   else { return undef; }
}

# check the profile syntax and die if we have an error
sub _check_profile_syntax {
	my $profile = shift;

	die "Invalid input profile: needs to be a hash reference\n" unless ref $profile eq "HASH";

	my @valid_profile_keys = (qw/
		optional
		required
		required_regexp 
		require_some
		optional_regexp
		constraints
		constraint_regexp_map
		dependencies
		dependency_groups
		defaults
		filters
		field_filters
		field_filter_regexp_map
		missing_optional_valid
		validator_packages
        untaint_constraint_fields
		untaint_all_constraints
		/);

	# If any of the keys in the profile are not listed as valid keys here, we die with an error	
	for my $key (keys %$profile) {
		unless (grep {$key eq $_} @valid_profile_keys) {
			die "Invalid input profile: $key is not a valid profile key\n"
		}
	}
}

# Figure out whether the data is a hash reference of a CGI object and return it has a hash
sub _get_data {
	my $data = shift;
	require UNIVERSAL;
	if (UNIVERSAL::isa($data,'CGI')) {
		my %return;
		# make sure object supports param()
		defined($data->UNIVERSAL::can('param')) or
		croak("Data::FormValidator->validate called with CGI object which lacks a param() method!");
		foreach my $k ($data->param()){
			# we expect param to return an array if there are multiple values
			my @v = $data->param($k);
			$return{$k} = scalar(@v)>1 ? \@v : $v[0];
		}
		return %return;
	}
	# otherwise, it's already a hash reference
	else {
		return %$data;	
	}
}

# apply filter, modifying %valid by reference
sub _filter_apply {
	my ($valid,$field,$filter) = @_;
	die 'wrong number of arguments passed to _filter_apply' unless (scalar @_ == 3);
	if (ref $valid->{$field}) {
		for (my $i = 0; $i < @{ $valid->{$field} }; $i++) {
			$valid->{$field}->[$i] = $filter->( $valid->{$field}->[$i] );
		}
	}
	else {
		$valid->{$field} = $filter->( $valid->{$field} );
	}
}

sub _constraint_hash_build {
	my ($field,$constraint_spec,$untaint_this) = @_;
	die "_constraint_apply recieved wrong number of arguments" unless (scalar @_ == 3);

	my	$c = {
			name 		=> $constraint_spec,
			constraint  => $constraint_spec, 
		};


   # constraints can be passed in directly via hash
	if (ref $c->{constraint} eq 'HASH') {
			$c->{constraint} = $constraint_spec->{constraint};
			$c->{name}       = $constraint_spec->{name};
			$c->{params}     = $constraint_spec->{params};
	}

	# Check for regexp constraint
	if ( $c->{constraint} =~ m@^\s*(/.+/|m(.).+\2)[cgimosx]*\s*$@ ) {
		#If untainting return the match otherwise return result of match
               my $return_code = ($untaint_this) ? 'return (substr($_[0], $-[0], $+[0] - $-[0]) =~ m/(.*)/s)[0] if defined($-[0]);' : '';
		$c->{constraint} = eval 'sub { $_[0] =~ '. $c->{constraint} . ';' . $return_code . '}';
		die "Error compiling regular expression $c->{constraint}: $@" if $@;
	}
	# check for code ref
	elsif (ref $c->{constraint} eq 'CODE') {
		# do nothing, it's already a code ref
	}
	else {
		# Qualify symbolic reference

		#If untaint is turned on call match_* sub directly. 
		if ($untaint_this) {
			$c->{constraint} = *{qualify_to_ref("match_$c->{constraint}")}{CODE};
		}
		else {
			# try to use match_* first
			my $routine = 'match_'.$c->{constraint};			
			if (defined *{qualify_to_ref($routine)}{CODE}) {
				$c->{constraint} = eval 'sub { no strict qw/refs/; return defined &{"match_'.$c->{constraint}.'"}(@_)}';
			}
			# match_* doesn't exist; if it is supposed to be from the
			# validator_package(s) there may be only valid_* defined
			else {
				$c->{constraint} = *{qualify_to_ref('valid_'.$c->{constraint})}{CODE};
			}
		}
	}

	return $c;

}

sub _constraint_input_build {
	my ($c,$value) = @_;
	die "_constraint_input_build recieved wrong number of arguments" unless (scalar @_ == 2);

	my @params;
	if (defined $c->{params}) {
		foreach my $fname (_arrayify($c->{params})) {
			# If the value is passed by reference, we treat it literally
			push @params, (ref $fname) ? $fname : $value 
		}
	}
	else {
		push @params, $value;
	}
	return @params;
}

sub _constraint_check_match {
	my 	($c,$params) = @_;
	die "_constraint_check_match recieved wrong number of arguments" unless (scalar @_ == 2);

	if (my $match = $c->{constraint}->( @$params )) { 
		return $match;
	}
	else {
		return 
		undef,	
		{
			failed  => 1,
			name	=> $c->{name},
		};
	}
}


1;

__END__

=pod

=back

=head1 SEE ALSO

L<Data::FormValidator::Tutorial>, L<Params::Validate>, L<Data::Verify>, perl(1)

This document has also been translated into Japanese. The latest version is available here:
http://perldoc.jp/docs/modules/

=head1 CREDITS

Some of those input validation functions have been taken from MiniVend
by Michael J. Heins <mike@heins.net>

The credit card checksum validation was taken from contribution by
Bruce Albrecht <bruce.albrecht@seag.fingerhut.com> to the MiniVend
program.

=head1 PUBLIC CVS SERVER

Data::FormValidator now has a publicly accessible CVS server provided by
SourceForge (www.sourceforge.net).  You can access it by going to
http://sourceforge.net/cvs/?group_id=6582.  You want the module named 'dfv'. 

=head1 AUTHOR

Copyright (c) 1999 Francis J. Lacoste and iNsu Innovations Inc.
All rights reserved.

Parts Copyright 1996-1999 by Michael J. Heins <mike@heins.net>
Parts Copyright 1996-1999 by Bruce Albrecht  <bruce.albrecht@seag.fingerhut.com>
Parts Copyright 2001      by Mark Stosberg <mark@summersault.com>

B<Support Mailing List>
 
If you have any questions, comments, bug reports or feature suggestions,
post them to the support mailing list!  To join the mailing list, visit 
http://lists.sourceforge.net/lists/listinfo/cascade-dataform

=head1 LICENSE 

This program is free software; you can redistribute it and/or modify
it under the terms as perl itself.

=cut

