package Data::FormValidator::Constraints::Upload;

use strict;

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
@ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Data::FormValidator::Constraints::Upload ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.

@EXPORT = qw(
	valid_file_format		
	valid_image_max_dimensions
	valid_file_max_bytes	
	valid_image_min_dimensions
);

@EXPORT_OK = qw(
	file_format
	image_max_dimensions
	file_max_bytes
	image_min_dimensions
);

$VERSION = 1.2;

sub file_format {
	my %params = @_;
	return sub {
		my $self = shift; 
		$self->set_current_constraint_name('file_format');
		valid_file_format($self,\%params);
	}
}

sub image_max_dimensions {
	my $w  = shift || die 'image_max_dimensions: missing maximum width value';
	my $h  = shift || die 'image_max_dimensions: missing maximum height value';
	return sub {
		my $self = shift;
		$self->set_current_constraint_name('image_max_dimensions');
		valid_image_max_dimensions($self,\$w,\$h);
	}
}

sub file_max_bytes {
	my ($max_bytes) = @_;
	return sub {
		my $self = shift;
		$self->set_current_constraint_name('file_max_bytes');
		valid_file_max_bytes($self,\$max_bytes);
	}
}

sub image_min_dimensions {
	my $w  = shift || die 'image_min_dimensions: missing minimum width value';
	my $h  = shift || die 'image_min_dimensions: missing minimum height value';
	return sub {
		my $self = shift;
		$self->set_current_constraint_name('image_min_dimensions');
		valid_image_min_dimensions($self,\$w,\$h);
	}
}

sub valid_file_format {
	my $self = shift;
	$self->isa('Data::FormValidator::Results') ||
		die "file_format: first argument is not a Data::FormValidator::Results object. ";
	my $params = shift || {};
	# if (ref $params ne 'HASH' ) {
	# 	die "format: hash reference expected. Make sure you have
	# 	included 'params => []' in your constraint definition, even if there
	# 	are no additional arguments";
	# }

	my $q = $self->get_input_data;

	$q->can('param') ||
		die 'file_format: data object missing param() method';

	my $field = $self->get_current_constraint_field;
	my $fh = _get_upload_fh($self);

	## load filehandle 
	if (!$fh) {
	     warn "$0: can't get filehandle for field named $field" and return undef;
	}

	## load file magic stuff
	require File::MMagic;	
	my $mm = File::MMagic->new; 
	my $fm_mt;
	
	## only use filehandle bits for magic data
	  $fm_mt = $mm->checktype_filehandle($fh) || 
	    (warn "$0: can't get filehandle for field named $field" and return undef);
        # Work around a bug in File::MMagic (RT#12074)
        seek($fh,0,0);

	## fetch mime type universally (or close) 
	my $uploaded_mt = _get_upload_mime_type($self);

   # XXX perhaps this should be in a global variable so it's easier
   # for other apps to change the defaults;	
   $params->{mime_types} ||= [qw!image/jpeg  image/pjpeg image/gif image/png!];
   my %allowed_types = map { $_ => 1 } @{ $params->{mime_types} };

   # try the File::MMagic, then the uploaded field, then return undef we find neither
   my $mt = ($fm_mt || $uploaded_mt) or return undef;

   # figure out an extension
   use MIME::Types;
   my $mimetypes = MIME::Types->new;
   my MIME::Type $t = $mimetypes->type($mt);
   my @mt_exts = $t ? $t->extensions : ();

	## setup filename to retrieve extension
	my $fn = $q->param($field);
   	my ($uploaded_ext) = ($fn =~ m/\.([\w\d]*)?$/);
   my $ext;
	
   if (scalar @mt_exts) {
   		# If the upload extension is one recognized by MIME::Type, use it.
		if (grep {/^$uploaded_ext$/} @mt_exts) 	 {
			$ext = $uploaded_ext;
		}
		# otherwise, use one from MIME::Type, just to be safe
		else {
			$ext = $mt_exts[0];
		}
   }
   else {
   	   # If is a provided extension but no MIME::Type extension, use that.
	   # It's possible that there no extension uploaded or found)
	   $ext = $uploaded_ext;
   }

   # Add the mime_type and extension to the valid data set
   my $info = $self->meta($field) || {};
   $info = { %$info, mime_type => $mt, extension => ".$ext" };
   $self->meta($field,$info);

   return $allowed_types{$mt};
}

sub valid_image_max_dimensions {
	my $self = shift;
	$self->isa('Data::FormValidator::Results') ||
		die "image_max_dimensions: first argument is not a Data::FormValidator::Results object. ";
	my $max_width_ref  = shift || die 'image_max_dimensions: missing maximum width value';
	my $max_height_ref = shift || die 'image_max_dimensions: missing maximum height value';
	my $max_width  = $$max_width_ref;
	my $max_height = $$max_height_ref;
	($max_width > 0) || die 'image_max_dimensions: maximum width must be > 0';
	($max_height > 0) || die 'image_max_dimensions: maximum height must be > 0';

	my $q = $self->get_input_data;
	my $field = $self->get_current_constraint_field;
	my ($width,$height) = _get_img_size($self);

	unless ($width) {
		warn "$0: imgsize test failed";
		return undef;
	}

   # Add the dimensions to the valid hash
   my $info = $self->meta($field) || {};
   $info = { %$info, width => $width, height => $height };
   $self->meta($field,$info);

    return (($width <= $$max_width_ref) and ($height <= $$max_height_ref));
}

sub valid_file_max_bytes {
	my $self = shift;

	$self->isa('Data::FormValidator::Results') ||
		die "first argument is not a Data::FormValidator::Results object.";
	
	my $max_bytes_ref = shift;
	my $max_bytes;

	if ((ref $max_bytes_ref) and defined $$max_bytes_ref) {
		$max_bytes = $$max_bytes_ref;
	}
	else {
		$max_bytes = 1024*1024; # default to 1 Meg
	}

	my $q = $self->get_input_data;
	$q->can('param') ||
		die 'file_max_bytes: object missing param() method';

	my $field = $self->get_current_constraint_field;

	## retrieve upload fh for field
	my $fh = _get_upload_fh($self);
	if (!$fh) { warn "Failed to load filehandle for $field" && return undef; }

	## retrieve size
   	my $file_size = (stat ($fh))[7];

   # Add the size to the valid hash
   my $info = $self->meta($field) || {};
   $info = { %$info, bytes => $file_size  };
   $self->meta($field,$info);

   return ($file_size <= $max_bytes);
}

sub valid_image_min_dimensions {
	my $self = shift;
	$self->isa('Data::FormValidator::Results') ||
		die "image_min_dimensions: first argument is not a Data::FormValidator::Results object. ";
	my $min_width_ref  = shift || 
		die 'image_min_dimensions: missing minimum width value';
	my $min_height_ref = shift || 
		die 'image_min_dimensions: missing minimum height value';
	my $min_width  = $$min_width_ref;
	my $min_height = $$min_height_ref;

	## do these matter?
	($min_width > 0)  || die 'image_min_dimensions: minimum width must be > 0';
	($min_height > 0) || die 'image_min_dimensions: minimum height must be > 0';

	my $q = $self->get_input_data;
	my $field = $self->get_current_constraint_field;
	my ($width, $height) = _get_img_size($self);

	unless ($width) {
		warn "image failed processing";
		return undef;
	}

	# Add the dimensions to the valid hash
	my $info = $self->meta($field) || {};
	$info = { %$info, width => $width, height => $height };
	$self->meta($field,$info);

	return (($width >= $min_width) and ($height >= $min_height));
}

sub _get_img_size
{
	my $self = shift;
	my $q    = $self->get_input_data;

	## setup caller to make can errors more useful
	my $caller = (caller(1))[3];
	my $pkg  = __PACKAGE__ . "::";
	$caller =~ s/$pkg//g;

	$q->can('param')  || die "$caller: data object missing param() method";
	$q->can('upload') || die "$caller: data object missing upload() method";

	my $field = $self->get_current_constraint_field;

	## retrieve filehandle from query object.
	my $fh = _get_upload_fh($self);

	## check error
	if (!$fh) { warn "Unable to load filehandle" && return undef; }

	require Image::Size;
	import  Image::Size;

	## check size
	my ($width, $height, $err) = imgsize($fh);

	unless ($width) {
		warn "$caller: imgsize test failed: $err";
		return undef;
	}

	return ($width, $height);
}

## fetch filehandle for use with various file type checking
## call it with (_get_upload_fh($self)) since kind of mock object 
sub _get_upload_fh
{
	my $self  = shift;
	my $q	  = $self->get_input_data;
	my $field = $self->get_current_constraint_field;

	## CGI::Simple object processing (slightly different from others)
	if ($q->isa('CGI::Simple')) {
		## get filename 
		my $fn = $q->param($field);
		if (!$fn) {
			warn sprintf("Failed to locate filename '%s'", $q->cgi_error);
			return undef;
		}

		## return filename
		return $q->upload($fn);
	}

	## NOTE: Both Apache::Upload and CGI filehandles are not seekable
	## this causes issues with File::MMagic...

	## Apache::Request object processing 
	if ($q->isa('Apache::Request')) {
		use IO::File;
		my $upload = $q->upload($field); ## return Apache::Upload
	
		## error checking 
		warn "Failed to locate upload object" && return undef unless $upload; 

		## return filehandle
		return IO::File->new_from_fd(fileno($upload->fh), "r");
	}


	## only CGI.pm just in case for weird subclasses
	## generic data object (or CGI), CGI.pm has incomplete fh's nice huh
	if ($q->isa('CGI')) {
		use IO::File;
		my $fh = $q->upload($field);

		warn "Failed to load fh for $field" && return undef unless $fh;

		#my $tmpfile = $q->tmpFileName($q->param($field)) || return undef;
		#return FileHandle->new($tmpfile);

		## convert into seekable handle
		return IO::File->new_from_fd(fileno($fh), "r");
	}

	## not going to figure it out
	return undef;
}

## returns mime type if included as part of the send
sub _get_upload_mime_type
{
	my $self  = shift;
	my $q     = $self->get_input_data;
	my $field = $self->get_current_constraint_field;

	if ($q->isa('CGI')) {
		my $fn = $q->param($field); 
		
		## nicely check for info
		if ($q->uploadInfo($fn)) {
			return $q->uploadInfo($fn)->{'Content-Type'}
		} 

		return undef;
	}

	if ($q->isa('CGI::Simple')) {
		my $fn = $q->param($field);
		return $q->upload_info($fn, 'mime');
	}

	if ($q->isa('Apache::Request')) {
		my $upload = $q->upload($field);
		return $upload->info('Content-type');
	}

	return undef;
}


1;
__END__

=head1 NAME

Data::FormValidator::Constraints::Upload - Validate File Uploads

=head1 SYNOPSIS

    # Be sure to use a CGI.pm or CGI::Simple object as the form
    # input when using this constraint
    my $q = new CGI;

	use Data::FormValidator::Constraints::Upload qw(
			file_format
			file_max_bytes
		    image_max_dimensions
		    image_min_dimensions
	);
    my $dfv = Data::FormValidator->check($q,$my_profile);

	# In a Data::FormValidator Profile:
	constraint_methods => {
		image_name => [
			file_format(),
			file_max_bytes(10),
		    image_max_dimensions(200,200),	
		    image_min_dimensions(100,100),
		 ],
	}


=head1 DESCRIPTION

B<Note:> This is a new module is a new addition to Data::FormValidator and is 
should be considered "Beta". 

These module is meant to be used in conjunction with the Data::FormValidator
module to automate the task of validating uploaded files. The following
validation routines are supplied.

To use any of them, the input data passed to Data::FormValidator must
be a CGI.pm object.

=over 4

=item file_format

This function checks the format of the file, based on the MIME type if it's
available, and a case-insensitive version of the file extension otherwise. By
default, it tries to validate JPEG, GIF and PNG images. The params are:

 optional hash reference of parameters. A key named I<mime_types> points to
 array references of valid values.

   file_format( mime_types => [qw!image/jpeg image/gif image/png!] );

Calling this function sets some meta data which can be retrieved through
the C<meta()> method of the Data::FormValidator::Results object.
The meta data added is C<extension> and C<mime_type>.

The MIME type of the file will first be tried to figured out by using the
<File::MMagic> module to examine the file. If that doesn't turn up a result,
we'll use a MIME type from the browser if one has been provided. Otherwise, we
give up. The extension we return is based on the MIME type we found, rather
than trusting the one that was uploaded.

=item file_max_bytes

This function checks the maximum size of an uploaded file. By default,
it checks to make sure files are smaller than 1 Meg. The params are:

 reference to max file size in bytes

 	file_max_bytes(1024), # 1 k

Calling this function sets some meta data which can be retrieved through
the C<meta()> method of the Data::FormValidator::Results object.
The meta data added is C<bytes>.

=item image_max_dimensions

This function checks to make sure an uploaded image is no longer than
some maximum dimensions. The params are: 

 reference to max pixel width
 reference to max pixel height

    image_max_dimensions(200,200),

Calling this function sets some meta data which can be retrieved through
the C<meta()> method of the Data::FormValidator::Results object.
The meta data added is C<width> and C<height>.

=item image_min_dimensions

This function checks to make sure an uploaded image is longer than
some minimum dimensions. The params are: 

 reference to min pixel width
 reference to min pixel height

    image_min_dimensions(100,100),

Calling this function sets some meta data which can be retrieved through
the C<meta()> method of the Data::FormValidator::Results object.
The meta data added is C<width> and C<height>.

=back

=head2 BACKWARDS COMPATIBILITY

An older more awkward interface to the constraints in this module is still supported.
To use it, you have to load the package with 'validator_packages', and call each
constraint in a hashref style, passing the the parameters by reference. It looks
like this:

	validator_packages => [qw(Data::FormValidator::Constraints::Upload)],
	constraints => {
		image_name => [
			{
		    	constraint_method => 'image_max_dimensions', 
				params => [\200,\200],
			}
		 ],
	}

I told you it was more awkward. That was before I grokked the magic of closures, which 
is what drives the current interface.

=head1 SEE ALSO

L<FileMetadata>, L<Data::FormValidator>, L<CGI>, L<perl>

=head1 AUTHOR

Mark Stosberg, E<lt>mark@summersault.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003-2005 by Mark Stosberg

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
