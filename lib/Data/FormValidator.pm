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
#    Parts Copyright 2001-2003 by Mark Stosberg <mark@stosberg.com>
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

package Data::FormValidator;

use 5.005; # for "qr" support, which isn't strictly required. -mls

use Data::FormValidator::Results;
use Data::FormValidator::Filters (qw/:filters/);
use Data::FormValidator::Constraints (qw/:validators :matchers/);

use vars qw( $VERSION $AUTOLOAD @ISA @EXPORT_OK %EXPORT_TAGS );

$VERSION = '3.00';

require Exporter;
@ISA = qw(Exporter);

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
@EXPORT_OK = (@{ $EXPORT_TAGS{filters} }, @{ $EXPORT_TAGS{validators} }, @{ $EXPORT_TAGS{matchers} });


use strict;
use Carp; # generate better errors with more context
use Symbol;


sub DESTROY {}

=pod

=head1 NAME

Data::FormValidator - Validates user input (usually from an HTML form) based
on input profile.

=head1 SYNOPSIS

 use Data::FormValidator;
 
 my $results = Data::FormValidator->check(\%input_hash, \%dfv_profile);
 
 if ($results->has_invalid or $results->has_missing) {
 	# do something with $results->invalid, $results->missing
 	# or  $results->msgs
 }
 else {
 	# do something with $results->valid
 }


=head1 DESCRIPTION

Data::FormValidator's main aim is to make input validation expressible in a
simple format.

Data::FormValidator lets you define profiles which declare the
required  and optional fields and any constraints they might have.

The results are provided as an object which makes it easy to handle 
missing and invalid results, return error messages about which constraints
failed, or process the resulting valid data.

=cut

sub new {
    my $proto = shift;
	my $profiles_or_file = shift;
    my $defaults = shift;

    my $class = ref $proto || $proto;

    if ($defaults) {
        ref $defaults eq 'HASH' or 
            die 'second argument to new must be a hash ref';
    }

	my ($file, $profiles);

	if (ref $profiles_or_file) {
		$profiles = $profiles_or_file;
	}
	else {
		$file = $profiles_or_file;
	}


    bless { 
		profile_file => $file,
	    profiles	 => $profiles,
        defaults     => $defaults,
	  }, $class;
}

=pod

=head1 VALIDATING INPUT

=head2 check()

C<check> is the recommended method to use to validate forms. It returns it's results as
L<Data::FormValidator::Results|Data::FormValidator::Results> object.  A
deprecated method C<validate> is also available, returning it's results in
array described below.

 use Data::FormValidator;
 my $results = Data::FormValidator->check(\%input_hash, \%dfv_profile);

Here, C<check()> is used as a class method, and takes two required parameters. 

The first a reference to the data to be be validated. This can either be a hash
reference, or a CGI or Apache::Request object.  Note that if you use a hash
reference, multiple values for a single key should be presented as an array
reference.

The second argument is a reference to the profile you are validating.

=head2 validate()

    my( $valids, $missings, $invalids, $unknowns ) = 
		Data::FormValidator->validate( \%input_hash, \%dfv_profile);

C<validate()> provides a deprecated alternative to C<check()>. It has the same input
syntax, but returns a four element array, described as follows

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
which failed one or more of their constraint checks.

Fields defined with multiple constraints will have an array ref returned in the
@invalids array instead of a string. The first element in this array is the
name of the field, and the remaining fields are the names of the failed
constraints. 

=item unknowns

This is a list of fields which are unknown to the profile. Whether or
not this indicates an error in the user input is application
dependant.

=back

=head2 new()

Using C<new()> is only needed for advanced usage, so feel free to skip this
section if you are just getting started.

That said, using C<new()> is useful in some cases. These include:

=over

=item o

Loading more than one profile at a time. Then you can select the profile you
want by name later with C<check()>. Here's an example:

 my $dfv = Data::FormValidator->new({
    profile_1 => { # usual profile definition here },
    profile_1 => { # another profile definition },
 });


As illustrated, multiple profiles are defined through a hash ref whose keys point
to profile definitions.

You can also load several profiles from a file, by defining several profiles as shown above
in an external file. Then just pass in the name of the file:

 my $dfv = Data::FormValidator->new('/path/to/profiles.pl');

If the input profile is specified as a file name, the profiles will be reread
each time that the disk copy is modified.

Now when calling C<check()>, you just need to supply the profile name:

 my $results = $dfv->check(\%input_hash,'profile_1');

=item o

Applying defaults to more than one input profile. There are some parts 
of the validation profile that you might like to re-use for many form
validations. 

To facilite this, C<new()> takes a second argument, a hash reference. Here
the usual input profile definitions can be made. These will act as defaults for
any subsequent calls to C<check()> on this object.

Currently the logic for this is very simple. Any definition of a key in your
validation profile will completely overwrite your default value. 

This means you can't define two keys for C<constraint_regexp_map> and expect
they will always be there. This kind of feature may be added in the future.

The exception here is are definitions for your C<msgs> key. You will safely  
be able to define some defaults for this key and not have them entirely clobbered 
just because C<msgs> was defined in a validation profile.

One way to use this feature is to create your own sub-class that always provides
your defaults to C<new()>. 

Another option to create your own wrapper routine which provides these defaults to 
C<new()>.  Here's an example of a routine you might put in a
L<CGI::Application|CGI::Application> super-class to make use of this feature:

 # Always use the built-in CGI object as the form data
 # and provide some defaults to new constructor
 sub check_form {
     my $self = shift;
     my $profile = shift 
        || die 'check_form: missing required profile';
 
     require Data::FormValidator;
     my $dfv = Data::FormValidator->new({},{ 
        # your defaults here
     });
     return $dfv->check($self->query,$profile);
 }


=back

=cut

sub validate {
	my ($self,$data,$name) = @_;

    my $data_set = $self->check( $data,$name );

    my $valid	= $data_set->valid();
    my $missing	= $data_set->missing();
    my $invalid	= $data_set->{validate_invalid};
    my $unknown = [ $data_set->unknown ];

    return ( $valid, $missing, $invalid, $unknown );
}

sub check {
    my ( $self, $data, $name ) = @_;
	
	# check can be used as a class method for simple cases
	if (not ref $self) {
        my $class = $self;
        $self = {};
        bless $self, $class;
    }

	my $profile;
	if ( ref $name ) {
		$profile = $name;
	} else {
		$self->load_profiles;
		$profile = $self->{profiles}{$name};
		die "No such profile $name\n" unless $profile;
	}
	die "input profile must be a hash ref" unless ref $profile eq "HASH";

	# add in defaults from new(), if any
	if ($self->{defaults}) {
		$profile = { %{$self->{defaults}}, %$profile };
	}
	
	# check the profile syntax or die with an error. 
	_check_profile_syntax($profile);

    my $results = Data::FormValidator::Results->new( $profile, $data );

    # As a special case, pass through any defaults for the 'msgs' key.
    $results->msgs($self->{defaults}->{msgs}) if $self->{defaults}->{msgs};

    return $results;
}


=pod

=head1 INPUT PROFILE SPECIFICATION

An input profile is a hash reference containing one or more of the following
keys. 

Here is a very simple input profile. Examples of more advanced options are
described below.

    my $profile = {
        optional => [qw( company
                         fax 
                         country )],

        required => [qw( fullname 
                         phone 
                         email 
                         address )],

        constraints => {
            email => 'email'
        }
    };


That defines some fields as optional, some as required, and defines that the
field named 'email' must pass the constraint named 'email'.

Here is a complete list of the keys available in the input profile, with
examples of each.

=head2 required

This is an array reference which contains the name of the fields which are
required. Any fields in this list which are not present, or contain only
spaces.  will be reported as missing.


=head2 required_regexp

 required_regexp => qr/city|state|zipcode/,

This is a regular expression used to specify additional fieds which are

 require_some => {
    # require any two fields from this group
    city_or_state_or_zipcode => [ 2, qw/city state zipcode/ ], 
 }

This is a reference to a hash which defines groups of fields where 
1 or more field from the group should be required, but exactly
which fields doesn't matter. The keys in the hash are the group names. 
These are returned as "missing" unless the required number of fields
from the group has been filled in. The values in this hash are
array references. The first element in this hash should be the 
number of fields in the group that is required. If the first
first field in the array is not an a digit, a default of "1" 
will be used. 

=head2 optional

 optional => [qw/meat coffee chocolate/],

This is an array reference which contains the name of optional fields.
These are fields which MAY be present and if they are, they will be
check for valid input. Any fields not in optional or required list
will be reported as unknown.

=head2 optional_regexp

 optional_regexp => qr/_province$/,

This is a regular expression used to specify additional fieds which are
optional. For example, if you wanted all fields names that begin with I<user_> 
to be optional, you could use the regular expression, /^user_/

=head2 dependencies


 dependencies   => {

    # If cc_no is entered, make cc_type and cc_exp required
    "cc_no" => [ qw( cc_type cc_exp ) ],

    # if pay_type eq 'check', require check_no
    "pay_type" => {
        check => [ qw( check_no ) ],
     }
 },

This is for the case where an optional field has other requirements.  The
dependent fields can be specified with an array reference.  

If the dependencies are specified with a hash reference then the additional
constraint is added that the optional field must equal a key for the
dependencies to be added.

Any fields in the dependencies list that is missing when the target is present
will be reported as missing.

=head2 dependency_groups

 dependency_groups  => {
     # if either field is filled in, they all become required
     password_group => [qw/password password_confirmation/],
 }

This is a hash reference which contains information about groups of 
interdependent fields. The keys are arbitrary names that you create and
the values are references to arrays of the field names in each group. 

=head2 defaults

 defaults => {
 	country => "USA",
 },

This is a hash reference where keys are field names and 
values are defaults to use if input for th e field is missing. 

The defaults are set shortly before the constraints are applied, and
will be returned with the other valid data.

=head2 filters

 # trim leading and trailing whitespace on all fields
 filters       => ['trim'],

This is a reference to an array of filters that will be applied to ALL
optional or required fields. 

This can be the name of a built-in filter
(trim,digit,etc) or an anonymous subroutine which should take one parameter, 
the field value and return the (possibly) modified value.

Filters modify the data, so use them carefully. 

See Data::FormValidator::Filters for details on the built-in filters.

=head2 field_filters

 field_filters => { 
 	cc_no => "digit"
 },

A hash ref with field names and keys. Values are array references
of field-specific filters to apply.

See Data::FormValidator::Filters for details on the built-in filters.

=head2 field_filter_regexp_map

 field_filter_regexp_map => {
 	# Upper-case the first letter of all fields that end in "_name"
 	qr/_name$/	=> 'ucfirst',
 },

This is a hash reference where the keys are the regular expressions to
use and the values are references to arrays of filters which will be
applied to specific input fields. Used to apply filters to fields that
match a regular expression. 

=head2 constraints

 constraints => {
	cc_no      => {  
		constraint  => "cc_number",
		params	    => [ qw( cc_no cc_type ) ],
	},
	cc_type	=> "cc_type",
	cc_exp	=> "cc_exp",
  },

A hash ref which contains the constraints that
will be used to check whether or not the field contains valid data.

The keys in this hash are field names. The values can any of the following:

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

=head2 constraint_regexp_map

 constraint_regexp_map => {
 	# All fields that end in _postcode have the 'postcode' constraint applied.
 	qr/_postcode$/	=> 'postcode',
 },			      

A hash ref where the keys are the regular expressions to
use and the values are the constraints to apply. 

If one or more constraints have already been defined for a given field using
"constraints", constraint_regexp_map will add an additional constraint for that
field for each regular expression that matches.

=head2 untaint_all_constraints

 untaint_all_constraints => 1,

If this field is set all form data that passes a constraint will be untainted.
The untainted data will be returned in the valid hash.  Untainting is based on
the pattern match used by the constraint.  Note that some validation routines
may not provide untainting.

If you write your own regular expressions and only match part of the string
then you'll only get part of the string in the valid hash. It is a good idea to
write you own constraints like /^regex$/. That way you match the whole string.

See L<WRITING YOUR OWN VALIDATION ROUTINES> in the Data::FormValidator::Results
documention for more information.

This is overridden by C<untaint_constraint_fields>

=head2 untaint_constraint_fields

 untaint_constraint_fields => [qw(zipcode state)],

Specifies that one or more fields will be untainted if they pass their
constraint(s). This can be set to a single field name or an array reference of
field names. The untainted data will be returned in the valid hash. 

This is overrides the untaint_all_constraints flag.

=head2 missing_optional_valid

 missing_optional_valid => 1

This can be set to a true value to cause missing optional fields to be included
in the valid hash. By default they are not included-- this is the historical
behavior. 

This is an important flag if you are using the contents of an "update" form to
update a record in a database. Without using the option, fields that have been
set back to "blank" may fail to get updated.

=head2 validator_packages 

 # load all the constraints from these modules
 validator_packages => [qw(Data::FormValdidator::Constraints::Upload)],

This key is used to define other packages which contain validation routines.
Set this key to a single package name, or an arrayref of several. All of its
validation routines. will become available for use.  beginning with 'match_'
and 'valid_' will be imported into Data::FormValidator.  This lets you
reference them in a constraint with just their name, just like built-in
routines .  You can even override the provided validators.

See L<WRITING YOUR OWN VALIDATION ROUTINES> in the Data::FormValidator::Results
documention for more information

=head2 msgs

 msgs =>{},

B<NOTE:> This part of the interface is still experimental and may change.  Use
in production code at your own caution. Contact the maintainer with any
questions or suggestions.

This key is used to transform the output of the invalid and missing
return values into a single hash reference which has the field names as keys
and error messages as values. By default, invalid fields have the message
"Invalid" associated with them while missing fields have the message "Missing"
associated with them. In the simplest case, this key can simply be defined as a
reference to a an empty hash, like this:

B<Example>:

 msgs =>{}

This will cause the default messages to be used for missing and invalid fields. Some
default formatting will also be applied, designed for display in an XHTML web
page. That formatting is as followings:

	<span style="color:red;font-weight:bold"><span id="dfv_errors">* %s</span></span>

The C<%s> will be replaced with the message. The effect is that the message
will appear in bold red with an asterisk before it. This style can be overriden by simply
defining "dfv_errors" appropriately in a style sheet, or by providing a new format string.

Here's a more complex example that shows how to provide your own default message strings, as well
as providing custom messages per field, and handling multiple constraints:

 msgs => {
 	
 	# set a custom error prefix, defaults to none
     prefix=> 'error_',
 
 	# Set your own "Missing" message, defaults to "Missing"
     missing => 'Not Here!',
 
 	# Default invalid message, default's to "Invalid"
     invalid => 'Problematic!',
 
 	# message seperator for multiple messages
 	# Defaults to ' '
     invalid_seperator => ' <br /> ',
 
 	# formatting string, default given above.
     format => 'ERROR: %s',
 
 	# Error messages, keyed by constraint name
 	# Your constraints must be named to use this.
     constraints => {
                     'date_and_time' => 'Not a vaild time format',
                     # ...
     },
 
 	# This token will be included in the hash if they are 
 	# any errors returned. This can be useful with templating
 	# systems like HTML::Template
 	# The 'prefix' setting does not apply here.
 	# defaults to undefined
 	any_errors => 'some_errors',
 }

The hash that's prepared can be retreived through the C<msgs> method
described in the L<Data::FormValidator::Results> documentation.

=head2 debug

This method is used to print details about is going on to STDERR.

Currently only level '1' is used. It provides information about which 
fields matched constraint_regexp_map. 

=head2 A shortcut for array refs

A number of parts of the input profile specification include array references
as their values.  In any of these places, you can simply use a string if you
only need to specify one value. For example, instead of

 filters => [ 'trim' ]

you can simply say

 filters => 'trim'

=head2 A note on regular expression formats

In addition to using the preferred method of defining regular expressions
using C<qr>, a deprecated style of defining them as strings is also supported.

Preferred:

 qr/this is great/

Deprecated, but supported

 'm/this still works/'

=head1 VALIDATING INPUT BASED ON MULTIPLE FIELDS

You can pass more than one value into a validation routine.  For that, the
value of the constraint should be a hash reference. If you are creating your
own routines, be sure to read the section labeled L<WRITING YOUR OWN VALIDATION ROUTINES>, 
in the Data::FormValidator::Results documentation.
It describes a newer and more flexible syntax. 

Using the original syntax, one key should be named C<constraint> and should
have a value set to the reference of the subroutine or the name of a built-in
validator.  Another required key is I<params>. The value of the I<params> key
is a reference to an array of the other elements to use in the validation. If
the element is a scalar, it is assumed to a field name. If the value is a
reference, The reference is passed directly to the routine. Don't forget to
include the name of the field to check in that list, if you are using this syntax.

B<Example>:

 cc_no  => {  
 	constraint  => "cc_number",
 	params	     => [ qw( cc_no cc_type ) ],
 },


=head1 MULTIPLE CONSTRAINTS

Multiple constraints can be applied to a single field by defining the value of
the constraint to be an array reference. Each of the values in this array can
be any of the constraint types defined above.

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

Read about the C<validate()> function above to see how multiple constraints
are returned differently with that method.

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



# check the profile syntax and die if we have an error
sub _check_profile_syntax {
	my $profile = shift;

	die "Invalid input profile: needs to be a hash reference\n" unless ref $profile eq "HASH";

	my @valid_profile_keys = (qw/
		constraint_regexp_map
		constraints
		defaults
		dependencies
		dependency_groups
		field_filter_regexp_map
		field_filters
		filters
		missing_optional_valid
		msgs
		optional
		optional_regexp
		require_some
		required
		required_regexp 
		untaint_all_constraints
		validator_packages
        untaint_constraint_fields
		debug
		/);

	# If any of the keys in the profile are not listed as valid keys here, we die with an error	
	for my $key (keys %$profile) {
		unless (grep {$key eq $_} @valid_profile_keys) {
			die "Invalid input profile: $key is not a valid profile key\n"
		}
	}
}




1;

__END__

=pod

=head1 SEE ALSO

B<Other modules in this distribution:>

L<Data::FormValidator::Constraints|Data::FormValidator::Constraints> 

L<Data::FormValidator::Constraints::Dates|Data::FormValidator::Constraints::Dates> 

L<Data::FormValidator::Constraints::Upload|Data::FormValidator::Constraints::Upload>

L<Data::FormValidator::ConstraintsFactory|Data::FormValidator::ConstraintsFactory>

L<Data::FormValidator::Filters|Data::FormValidator::Filters>

L<Data::FormValidator::Results|Data::FormValidator::Results>

B<A sample application by the maintainer:> 

Validationg Web Forms with Perl, L<http://mark.stosberg.com/Tech/perl/form-validation/>

B<Related modules:>

L<Data::FormValidator::Tutorial|Data::FormValidator::Tutorial>

L<CGI::Application::ValidateRM|CGI::Application::ValidateRM>, a
CGI::Application & Data::FormValidator glue module

L<Params::Validate |Params::Validate> looks like a better choice for validating function parameters.  

L<Regexp::Common|Regexp::Common>,
L<Data::Types|Data::Types>,
L<Data::Verify|Data::Verify>,
L<String::Checker|String::Checker>,
L<CGI::ArgChecker|CGI::ArgChecker>,
L<CGI::FormMagick::Validator|CGI::FormMagick::Validator>,
L<CGI::Validate|CGI::Validate>


B<Document Translations:>

Japanese: L<http://perldoc.jp/docs/modules/>

=head1 CREDITS

Some of those input validation functions have been taken from MiniVend
by Michael J. Heins <mike@heins.net>

The credit card checksum validation was taken from contribution by
Bruce Albrecht <bruce.albrecht@seag.fingerhut.com> to the MiniVend
program.

=head1 BUGS

http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-FormValidator 

=head1 AUTHOR

Parts Copyright 2001-2003 by Mark Stosberg <markstos@cpan.org>, (Current Maintainer)

Copyright (c) 1999 Francis J. Lacoste and iNsu Innovations Inc.  All rights reserved.
(Original Author)

Parts Copyright 1996-1999 by Michael J. Heins <mike@heins.net>

Parts Copyright 1996-1999 by Bruce Albrecht  <bruce.albrecht@seag.fingerhut.com>

B<Support Mailing List>
 
If you have any questions, comments, bug reports or feature suggestions,
post them to the support mailing list!  To join the mailing list, visit 
L<http://lists.sourceforge.net/lists/listinfo/cascade-dataform>

=head1 LICENSE 

This program is free software; you can redistribute it and/or modify
it under the terms as perl itself.

=cut

