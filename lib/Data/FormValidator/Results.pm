#
#    Results.pm - Object which contains validation result.
#
#    This file is part of FormValidator.
#
#    Author: Francis J. Lacoste <francis.lacoste@iNsu.COM>
#    Maintainer: Mark Stosberg <mark@summersault.com>
#
#    Copyright (C) 2000 iNsu Innovations Inc.
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms same terms as perl itself.
#
use strict;

package Data::FormValidator::Results;

use Data::FormValidator::Filters qw/:filters/;
use Data::FormValidator::Constraints (qw/:validators :matchers/);
use Symbol;

=pod

=head1 NAME

Data::FormValidator::Results - Object which contains the results of an input validation.

=head1 SYNOPSIS

    my $results = $validator->check( \%fdat, "customer_infos" );

    # Print the name of missing fields
    if ( $results->has_missing ) {
	foreach my $f ( $results->missing ) {
	    print $f, " is missing\n";
	}
    }

    # Print the name of invalid fields
    if ( $results->has_invalid ) {
	foreach my $f ( $results->invalid ) {
	    print $f, " is invalid: ", $results->invalid( $f ) \n";
	}
    }

    # Print unknown fields
    if ( $results->has_unknown ) {
	foreach my $f ( $results->unknown ) {
	    print $f, " is unknown\n";
	}
    }

    # Print valid fields
    foreach my $f ( $results->valid() ) {
	print $f, " =  ", $result->valid( $f ), "\n";
    }

=head1 DESCRIPTION

This is the object returned by the Data::FormValidator check method. It can
be queried for information about the validation results.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my ($profile, $data) = @_;

    my $self = bless {}, $class;

    $self->_process( $profile, $data );

    $self;
}

sub _process {
    my ($self, $profile, $data) = @_;

 	# Copy data and assumes that all is valid to start with
 		
	my %data        = $self->_get_data($data);
    my %valid	    = %data;
    my @missings    = ();
    my @invalid	    = ();
    my @unknown	    = ();

	# msgs() method will need access to the profile
	$self->{profile} = $profile;

    # import valid_* subs from requested packages
	foreach my $package (_arrayify($profile->{validator_packages})) {
		if ( !exists $profile->{imported_validators}{$package} ) {
			eval "require $package";
			if ($@) {
				die "Couldn't load validator package '$package': $@";
			}

			# Perl will die with a nice error message if the package can't be found
			# No need to go through extra effort here. -mls :)
			my $package_ref = qualify_to_ref("${package}::");
			my @subs = grep(/^(valid_|match_)/, keys(%{*{$package_ref}}));
			foreach my $sub (@subs) {
				# is it a sub? (i.e. make sure it's not a scalar, hash, etc.)
				my $subref = *{qualify_to_ref("${package}::$sub")}{CODE};
				if (defined $subref) {
					*{qualify_to_ref($sub)} = $subref;
				}
			}
			$profile->{imported_validators}{$package} = 1;
		}
	}

	# Apply inconditional filters
    foreach my $filter (_arrayify($profile->{filters})) {
		if (defined $filter) {
			# Qualify symbolic references
			$filter = (ref $filter ? $filter : *{qualify_to_ref("filter_$filter")}{CODE}) ||
				die "No filter found named: '$filter'";
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
				$filter = (ref $filter ? $filter : *{qualify_to_ref("filter_$filter")}{CODE}) ||
					die "No filter found named '$filter'";
				
				# apply filter, modifying %valid by reference
				_filter_apply(\%valid,$field,$filter);
			}	
		}
    }   

	# add in specific filters from the regexp map
	while ( my ($re,$filters) = each %{$profile->{field_filter_regexp_map} }) {
		my $sub = _create_sub_from_RE($re);

		foreach my $filter ( _arrayify($filters)) {
			if (defined $filter) {
				# Qualify symbolic references
				$filter = (ref $filter ? $filter : *{qualify_to_ref("filter_$filter")}{CODE}) ||
					die "No filter found named '$filter'";

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
    my $required_re = _create_sub_from_RE($profile->{required_regexp});
    my $optional_re = _create_sub_from_RE($profile->{optional_regexp});

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
					$valid{$field}->[$i] = undef unless length $valid{$field}->[$i];
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
		my $sub = _create_sub_from_RE($re);

		# find all the keys that match this RE and add a constraint for them
		for my $key (keys %valid) {
			if ($sub->($key)) {
					my $cur = $profile->{constraints}{$key};
					my $new = $profile->{constraint_regexp_map}{$re};
					# If they already have an arrayref of constraints, add to the list
					if (ref $cur eq 'ARRAY') {
						push @{ $profile->{constraints}{$key} }, $new;
					} 
					# If they have a single constraint defined, create an array ref with with this plus the new one
					elsif ($cur) {
						$profile->{constraints}{$key} = [$cur,$new];
					}
					# otherwise, a new constraint is created with this as the single constraint
					else {
						$profile->{constraints}{$key} = $new;
					}

					warn "constraint_regexp_map: $key matches\n" if $profile->{debug};
						
				}
			}
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
		   	 # set current constraint field for use by get_current_constraint_field
			 $self->{__CURRENT_CONSTRAINT_FIELD} = $field;
		   	
			 my $c = $self->_constraint_hash_build($field,$constraint_spec,$untaint_this);

			 my $is_value_list = 1 if (ref $valid{$field} eq 'ARRAY');
			 if ($is_value_list) {
				 foreach (my $i = 0; $i < scalar @{ $valid{$field}} ; $i++) {
					 my @params = $self->_constraint_input_build($c,$valid{$field}->[$i],\%valid);

					 # set current constraint field for use by get_current_constraint_value
					 $self->{__CURRENT_CONSTRAINT_VALUE} = $valid{$field}->[$i];

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
				my @params = $self->_constraint_input_build($c,$valid{$field},\%valid);

				# set current constraint field for use by get_current_constraint_value
				$self->{__CURRENT_CONSTRAINT_VALUE} = $valid{$field};

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
			   my @failed = map { $_->{name} } @invalid_list;
				push @invalid, [$field, @failed];
				push @{ $self->{invalid}->{$field} }, @failed;
		   }
		   else {
			   push @invalid, $field;
				push @{ $self->{invalid}->{$field} }, $invalid_list[0]->{name} ;
		   }
		   delete $valid{$field};
	   }

   }

    # add back in missing optional fields from the data hash if we need to
	foreach my $field ( keys %data ) {
		if ($profile->{missing_optional_valid} and $optional{$field} and (not exists $valid{$field})) {
			$valid{$field} = undef;
		}
	}

	my ($missing,$invalid);

	$self->{valid} ||= {};
    $self->{valid}	=  { %valid , %{$self->{valid}} };

	# the older interface to validate returned things differently
    $self->{validate_invalid}	= \@invalid || [];

    $self->{missing}	= { map { $_ => 1 } @missings };
    $self->{unknown}	= { map { $_ => 1 } @unknown };

}

=pod

=head1  valid( [field], [value] );

This method returns in an array context the list of fields which
contains valid value. In a scalar context, it returns an hash reference
which contains the valid fields and their value.

If called with one argument, it returns the value of that field if it
contains valid data, undef otherwise.

If called with two arguments, the first is taken as a field in the valid
hash, and this field is set to the value of the second argument. The
value is returned.

This can be useful in some cases to call from within a constraint
to alter the results of the valid hash.


=cut

sub valid {
	my $self = shift;
	my $key = shift;
	my $val = shift;
	$self->{valid}{$key} = $val if defined $val;
	return $self->{valid}{$key} if defined $key;
	wantarray ? keys %{ $self->{valid} } : $self->{valid};
}


=pod

=head1 has_missing()

This method returns true if the results contains missing fields.

=cut

sub has_missing {
    return scalar keys %{$_[0]{missing}};
}

=pod

=head1 missing( [field] )

This method returns in an array context the list of fields which
are missing. In a scalar context, it returns an array reference
to the list of missing fields.

If called with an argument, it returns true if that field is missing,
undef otherwise.

=cut

sub missing {
    return $_[0]{missing}{$_[1]} if (defined $_[1]);

    wantarray ? keys %{$_[0]{missing}} : [ keys %{$_[0]{missing}} ];
}


=pod

=head1 has_invalid()

This method returns true if the results contains fields with invalid
data.

=cut

sub has_invalid {
    return scalar keys %{$_[0]{invalid}};
}

=pod

=head1 invalid( [field] )

This method returns in an array context the list of fields which
contains invalid value. 

In a scalar context, it returns an hash reference which contains the invalid
fields as keys, and references to arrays of failed constraints as values.

If called with an argument, it returns the reference to
an array of failed constraints for this field.

=cut

sub invalid {
	my $self = shift;
	my $field = shift;
    return $self->{invalid}{$field} if defined $field;

    wantarray ? keys %{$self->{invalid}} : $self->{invalid};
}

=pod

=head1 has_unknown()

This method returns true if the results contains unknown fields.

=cut

sub has_unknown {
    return scalar keys %{$_[0]{unknown}};

}

=pod

=head1 unknown( [field] )

This method returns in an array context the list of fields which
are unknown. In a scalar context, it returns an hash reference
which contains the unknown fields and their value.

If called with an argument, it returns the value of that field if it
is unknown, undef otherwise.

=cut

sub unknown {
    return $_[0]{unknown}{$_[1]} if (defined $_[1]);

    wantarray ? keys %{$_[0]{unknown}} : $_[0]{unknown};
}


=pod

=head1 msgs([config parameters])

This method returns a hash reference to error messages. The exact format
is determined by parameters in th C<msgs> area of the validation profile,
described in the L<Data::FormValidator> documentation.

This method takes one possible parameter, a hash reference containing the same 
options that you can define in the validation profile. This allows you to seperate
the controls for message display from the rest of the profile. While validation profiles
may be different for every form, you may wish to format messages the same way
across many projects.

Controls passed into the <msgs> method will be applied first, followed by ones
applied in the profile. This allows you to keep the controls you pass to
C<msgs> as "global" and override them in a specific profile if needed. 

=cut

sub msgs {
	my $self = shift;
	my $controls = shift || {};
	if (defined $controls and ref $controls ne 'HASH') {
		die "$0: parameter passed to msgs must be a hash ref";
	}


	# Allow msgs to be called more than one to accumulate error messages
	$self->{msgs} ||= {};
	$self->{profile}->{msgs} ||= {};
	$self->{msgs} = { %{ $self->{msgs} }, %$controls };

	my %profile = (
		prefix	=> '',
		missing => 'Missing',
		invalid	=> 'Invalid',
		invalid_seperator => ' ',
		format  => '<span style="color:red;font-weight:bold"><span id="dfv_errors">* %s</span></span>',
		%{ $self->{msgs} },
		%{ $self->{profile}->{msgs} },
	);
	my %msgs = ();

	# Add invalid messages to hash
		#  look at all the constraints, look up their messages (or provide a default)
		#  add field + formatted constraint message to hash
	if ($self->has_invalid) {
		my $invalid = $self->invalid;
		for my $i ( keys %$invalid ) {
			$msgs{$i} = join $profile{invalid_seperator}, map {
				_error_msg_fmt($profile{format},($profile{constraints}{$_} || $profile{invalid}))
				} @{ $invalid->{$i} };
		}
	}

	# Add missing messages, if any
	if ($self->has_missing) {
		my $missing = $self->missing;
		for my $m (@$missing) {
			$msgs{$m} = _error_msg_fmt($profile{format},$profile{missing});
		}
	}

	my $msgs_ref = prefix_hash($profile{prefix},\%msgs);

	$msgs_ref->{ $profile{any_errors} } = 1 if defined $profile{any_errors};

	return $msgs_ref;

}

=pod

=head1 WRITING YOUR OWN VALIDATION ROUTINES

It's easy to create your own module of validation routines. The easiest approach
to this may be to check the source code of the Data::FormValidator module for example
syntax. Also notice the C<validator_packages> option in the input profile.

You will find that validation routines are named two ways. Some are named with
the prefix C<match_> while others start with C<valid_>. The difference is that the
C<match_ routines> are built to untaint the data and routine a safe version of
it if it validates, while C<valid_> routines simply return a true value if the
validation succeeds and false otherwise.

It is preferable to write "match" routines that untaint data for the extra security
benefits. Plus, Data::FormValidator will AUTOLOAD a "valid_" version if anyone tries to
use it, so you only need to write one routine to cover both cases. 

Usually validation routines only need one input, the value being specified. However,
sometimes more than one value is needed. For that, the following syntax is
recommended for calling the routines:

B<Example>:

		image_field  => {  
			constraint_method  => 'max_image_dimensions',
			params => [\100,\200],
		},

Using this syntax, the first parameter that will be passed to the routine is
the Data::FormValidator object. The remaining parameters will come from the
C<params> array. Strings will be replaced by the values of fields with the same names,
and references will be passed directly.

A couple of of useful methods to use on the Data::FormValidator::Results object  are
available to you to use inside of your routine.

=over 4

=item get_input_data

Returns the raw input data. This may be a CGI object if that's what 
was used in the validation routine. 

B<Example>

 my $data = $self->get_input_data;

=back

=cut 

sub get_input_data {
	my $self = shift;
	return $self->{__INPUT_DATA};
}

=pod

=over 4

=item get_current_constraint_field

Returns the name of the current field being tested in the constraint.

B<Example>:

 my $field = $self->get_current_constraint_field;

This reduces the number of parameters that need to be passed into the routine
and allows multi-valued constraints to be used with C<constraint_regexp_map>.

=back

For complete examples of multi-valued constraints, see L<Data::FormValidator::Constraints::Upload>

=cut

sub get_current_constraint_field {
	my $self = shift;
	return $self->{__CURRENT_CONSTRAINT_FIELD};
}
=pod

=over 4

=item get_current_constraint_value

Returns the name of the current value being tested in the constraint.

B<Example>:

 my $value = $self->get_current_constraint_value;

This reduces the number of parameters that need to be passed into the routine
and allows multi-valued constraints to be used with C<constraint_regexp_map>.

=back

=cut

sub get_current_constraint_value {
	my $self = shift;
	return $self->{__CURRENT_CONSTRAINT_VALUE};
}

# INPUT: prefix_string, hash reference
# Copies the hash and prefixes all keys with prefix_string
# OUTPUT: hash refence
sub prefix_hash {
	my ($pre,$href) = @_;
	die "prefix_hash: need two arguments" unless (scalar @_ == 2);
	die "prefix_hash: second argument must be a hash ref" unless (ref $href eq 'HASH');
	my %out; 
	for (keys %$href) {
		$out{$pre.$_} = $href->{$_};
	}
	return \%out;
}


# We tolerate two kinds of regular expression formats
# First, the preferred format made with "qr", matched using a learning paren
# Also, we accept the deprecated format given as strings: 'm/old/'
# (which must start with a slash or "m", not a paren)
sub _create_sub_from_RE {
	my $re = shift || return undef;
	my $sub;
	if ($re =~ /^\(/) {
		$sub = sub { $_[0] =~ $re };
	}
	else {
		$sub = eval 'sub { $_[0] =~ '.$re. '}';
		die "Error compiling regular expression $re: $@" if $@;
	}
	return $sub;
}


sub _error_msg_fmt ($$) {
	my ($fmt,$msg) = @_;
	$fmt ||= 
			'<span style="color:red;font-weight:bold"><span id="vrm_errors">* %s</span></span>';
	($fmt =~ m/%s/) || die 'format must contain %s'; 
	return sprintf $fmt, $msg;
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

# apply filter, modifying %valid by reference
sub _filter_apply {
	my ($valid,$field,$filter) = @_;
	die 'wrong number of arguments passed to _filter_apply' unless (scalar @_ == 3);
	if (ref $valid->{$field} eq 'ARRAY') {
		for (my $i = 0; $i < @{ $valid->{$field} }; $i++) {
			$valid->{$field}->[$i] = $filter->( $valid->{$field}->[$i] );
		}
	}
	else {
		$valid->{$field} = $filter->( $valid->{$field} );
	}
}

sub _constraint_hash_build {
	my ($self,$field,$constraint_spec,$untaint_this) = @_;
	die "_constraint_apply received wrong number of arguments" unless (scalar @_ == 4);

	my	$c = {
			name 		=> $constraint_spec,
			constraint  => $constraint_spec, 
		};


   # constraints can be passed in directly via hash
	if (ref $c->{constraint} eq 'HASH') {
			$c->{constraint} = ($constraint_spec->{constraint_method} || $constraint_spec->{constraint});
			$c->{name}       = $constraint_spec->{name};
			$c->{params}     = $constraint_spec->{params};
			$c->{is_method}  = 1 if $constraint_spec->{constraint_method};
	}

	# Check for regexp constraint
	if ((ref $c->{constraint} eq 'Regexp')
		or ( $c->{constraint} =~ m@^\s*(/.+/|m(.).+\2)[cgimosx]*\s*$@ )) {
		#If untainting return the match otherwise return result of match
               my $return_code = ($untaint_this) ? 'return (substr($_[0], $-[0], $+[0] - $-[0]) =~ m/(.*)/s)[0] if defined($-[0]);' : '';
		
		   if (ref $c->{constraint} eq 'Regexp') {
			   $c->{constraint} = sub { $_[0] =~ $c->{constraint}; eval($return_code) };
		   }
		   else {
			   $c->{constraint} = eval 'sub { $_[0] =~ '. $c->{constraint} . ';' . $return_code . '}';
		   }
		die "Error compiling regular expression $c->{constraint}: $@" if $@;
	}
	# check for code ref
	elsif (ref $c->{constraint} eq 'CODE') {
		# do nothing, it's already a code ref
	}
	else {
		# provide a default name for the constraint if we don't have one already
		$c->{name} ||= $c->{constraint};
		
		#If untaint is turned on call match_* sub directly. 
		if ($untaint_this) {
			$c->{constraint} = *{qualify_to_ref("match_$c->{constraint}")}{CODE} ||
				die "No untainting constraint found named '$c->constraint'";
		}
		else {
			# try to use match_* first
			my $routine = 'match_'.$c->{constraint};			
			if (defined *{qualify_to_ref($routine)}{CODE}) {
				$c->{constraint} = eval 'sub { no strict qw/refs/; return defined &{"match_'.$c->{constraint}.'"}(@_)}';
			}
			# match_* doesn't exist; if it is supposed to be from the
			# validator_package(s) there may be only valid_* defined
			elsif (my $valid_sub = *{qualify_to_ref('valid_'.$c->{constraint})}{CODE}) {
				$c->{constraint} = $valid_sub;
			}
			else {
				die "No constraint found named '$c->{name}'";
			}
		}
	}

	return $c;

}

sub _constraint_input_build {
	my ($self,$c,$value,$valid) = @_;
	die "_constraint_input_build received wrong number of arguments" unless (scalar @_ == 4);

	my @params;
	if (defined $c->{params}) {
		foreach my $fname (_arrayify($c->{params})) {
			# If the value is passed by reference, we treat it literally
			push @params, (ref $fname) ? $fname : $valid->{$fname}
		}
	}
	else {
		push @params, $value;
	}

	unshift @params, $self if $c->{is_method};
	return @params;
}

sub _constraint_check_match {
	my 	($c,$params) = @_;
	die "_constraint_check_match received wrong number of arguments" unless (scalar @_ == 2);

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

# Figure out whether the data is a hash reference of a CGI or Apache::Request object and return it has a hash
sub _get_data {
	my ($self,$data) = @_;
	$self->{__INPUT_DATA} = $data;
	require UNIVERSAL;
	if (UNIVERSAL::isa($data,'CGI') || UNIVERSAL::isa($data,'Apache::Request') ) {
		my %return;
		# make sure object supports param()
		defined($data->UNIVERSAL::can('param')) or
		croak("Data::FormValidator->validate called with CGI or Apache::Request object which lacks a param() method!");
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


1;

__END__

=pod

=head1 SEE ALSO

Data::FormValidator, Data::FormValidator::Filters,
Data::FormValidator::Constraints, Data::FormValidator::ConstraintsFactory

=head1 AUTHOR

Author: Francis J. Lacoste <francis.lacoste@iNsu.COM>
Maintainer: Mark Stosberg <mark@summersault.com> 

=head1 COPYRIGHT

Copyright (c) 1999,2000 iNsu Innovations Inc.
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms as perl itself.

=cut
