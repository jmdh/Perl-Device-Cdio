package Device::Cdio::ISO9660::IFS;
require 5.8.6;
#
#    $Id$
#
#    Copyright (C) 2006 Rocky Bernstein <rocky@cpan.org>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

=pod

=head1 NAME

Device::Cdio::ISO9660::IFS - Class for ISO9660 filesystem reading

=head1 SYNOPSIS

This encapsulates IS9660 filesystem handling. This library however
needs to be used in conjunction with Device::Cdio.

    use Device::Cdio::ISO9660:IFS;
    ...

=head1 DESCRIPTION

This is an Perl Object-Oriented interface to the GNU CD Input and
Control library (libcdio) which is written in C. The library
encapsulates CD-ROM reading and control. Perl programs wishing to be
oblivious of the OS- and device-dependent properties of a CD-ROM can
use this library.

The encapsulation is done in two parts. The lower-level Perl
interface is called L<perliso9660> and is generated by SWIG.

The more object-oriented package Device::Cdio::ISO9660 and uses uses
perliso9660. 

Although perliso9660 is perfectly usable on its own, it is expected that
Cdio is what most people will use. As perlcdio more closely models the
C interface, it is conceivable (if unlikely) that die-hard libcdio C
users who are very familiar with that interface could prefer that.

See also L<http://www.gnu/org/software/libcdio/libcdio.html> for more
complete description and
L<http://www.gnu/org/software/libcdio/libcdio.html> of the C library
from which this is based, and
L<http://www.gnu.org/software/libcdio/doxygen/files.html> for API

=head2 CALLING ROUTINES

Routines accept named parameters as well as positional parameters.
For named parameters, each argument name is preceded by a dash. For
example:

    Device::Cdio::ISO9660::IFS->new(-source=>'MYISO.ISO')

Each argument name is preceded by a dash.  Neither case nor order
matters in the argument list.  -driver_id, -Driver_ID, and -DRIVER_ID
are all acceptable.  In fact, only the first argument needs to begin
with a dash.  If a dash is present in the first argument, we assume
dashes for the subsequent parameters.

In the documentation below and elsewhere in this package the parameter
name that can be used in this style of call is given in the parameter
list. For example, for "close tray the documentation below reads:

   close_tray(drive=undef, driver_id=$perlcdio::DRIVER_UNKNOWN) 
    -> ($drc, $driver_id)

So the parameter names are "drive", and "driver_id". Neither parameter
is required. If "drive" is not specified, a value of "undef" will be
used. And if "driver_id" is not specified, a value of
$perlcdio::DRIVER_UNKNOWN is used.

The older, more traditional style of positional parameters is also
supported. So the "have_driver example from above can also be written:

    Cdio::have_driver('GNU/Linux')

Finally, since no parameter name can be confused with a an integer,
negative values will not get confused as a named parameter.

=cut

$revision = '$Id$';

$Device::Cdio::ISO9660::IFS::VERSION = $Device::Cdio::VERSION;

use warnings;
use strict;
use Exporter;
use perliso9660;
use Carp;

use vars qw($VERSION $revision @EXPORT_OK @EXPORT @ISA %drivers);
use Device::Cdio::Util qw( _check_arg_count _extra_args _rearrange );


@ISA = qw(Exporter);
@EXPORT    = qw( close open new );

# Note: the keys below match those the names returned by
# cdio_get_driver_name()

=pod

=head1 METHODS

=head2 new

new(source, iso_mask)->$track_object

Create a new ISO 9660 object. Source or iso_mask is optional. 

If source is given, open() is called using that and the optional iso_mask
parameter; iso_mask is used only if source is specified.
If source is given but opening fails, undef is returned.
If source is not given, an object is always returned.

=cut

sub new {

  my($class,@p) = @_;

  my($source, $iso_mask, @args) = 
      _rearrange(['SOURCE', 'ISO_MASK'], @p);

  return undef if _extra_args(@args);
  $iso_mask = $perliso9660::EXTENSION_NONE if !defined($iso_mask);

  my $self = {};
  $self->{iso9660} = undef;

  bless ($self, $class);

  if (defined($source)) {
      return undef if !$self->open($source, $iso_mask);
  }

  return $self;
}

	
=pod

=head2 close

close()->bool

Free resources associated with ISO9660.  Call this when done using using
an ISO 9660 image.

=cut

sub close {
    my($self,@p) = @_;
    return 0 if !_check_arg_count($#_, 0);
    if (defined($self->{iso9660})) {
	return perliso9660::close($self->{iso9660});
    } else {
	print "***No object to close\n";
        $self->{iso9660} = undef;
	return 0;
    }
}

=pod

=head2 open

open(source, iso_mask=$libiso9660::EXTENSION_NONE)->bool

Open an ISO 9660 image for reading. Subsequent operations will read
from this ISO 9660 image.

This should be called before using any other routine except possibly
new. It is implicitly called when a new is done specifying a source.

=cut

sub open {
    my($self,@p) = @_;
    my($source, $iso_mask) = 
	_rearrange(['SOURCE', 'ISO_MASK'], @p);
    
    $self->close() if defined($self->{iso9660});
    $iso_mask = $perliso9660::EXTENSION_NONE if !defined($iso_mask);
    if (!defined($source)) {
      print "*** An ISO-9660 file image must be given\n";
      return 0;
    }
    $self->{iso9660} = perliso9660::open_ext($source, $iso_mask);
    return defined($self->{iso9660});
}

=pod

=head2 open_fuzzy

open_fuzzy(source, iso_mask=$libiso9660::EXTENSION_NONE, fuzz=20)->bool

Open an ISO 9660 image for reading. Subsequent operations will read
from this ISO 9660 image. Some tolerence allowed for positioning the
ISO9660 image. We scan for $perliso9660::STANDARD_ID and use that to
set the eventual offset to adjust by (as long as that is <= $fuzz).

This should be called before using any other routine except possibly
new (which must be called first. It is implicitly called when a new is
done specifying a source.

=cut

sub open_fuzzy {
    my($self,@p) = @_;
    my($source, $iso_mask, $fuzz) = 
	_rearrange(['SOURCE', 'ISO_MASK', 'FUZZ'], @p);
    
    $self->close() if defined($self->{iso9660});
    $iso_mask = $perliso9660::EXTENSION_NONE if !defined($iso_mask);

    if (!defined($fuzz)) {
	$fuzz = 20;
    } elsif ($fuzz !~ m{\A\d+\Z}) {
	print "*** Expecting fuzz to be an integer; got '$fuzz'\n";
	return 0;
    }

    $self->{iso9660} = perliso9660::open_fuzzy_ext($source, $iso_mask, $fuzz);
    return defined($self->{iso9660});
}

=pod

=head2 read_fuzzy_superblock

read_fuzzy_superblock(iso_mask=$libiso9660::EXTENSION_NONE, fuzz=20)->bool

Read the Super block of an ISO 9660 image but determine framesize
and datastart and a possible additional offset. Generally here we are
not reading an ISO 9660 image but a CD-Image which contains an ISO 9660
filesystem.

=cut

sub read_fuzzy_superblock {
    my($self,@p) = @_;
    my($iso_mask, $fuzz) = 
	_rearrange(['ISO_MASK', 'FUZZ'], @p);
    
    $iso_mask = $perliso9660::EXTENSION_NONE if !defined($iso_mask);

    if (!defined($fuzz)) {
	$fuzz = 20;
    } elsif ($fuzz !~ m{\A\d+\Z}) {
	print "*** Expecting fuzz to be an integer; got '$fuzz'\n";
	return 0;
    }

    return perliso9660::ifs_fuzzy_read_superblock($self->{iso9660},
						  $iso_mask, $fuzz);
}

=pod

=head2 readdir

readdir(dirname)->@iso_stat

Read path (a directory) and return a list of iso9660 stat references

Each item of @iso_stat is a hash reference which contains

=over 4

=item LSN 

the Logical sector number (an integer)

=item size 

the total size of the file in bytes

=item  sec_size 

the number of sectors allocated

=item  filename

the file name of the statbuf entry

=item XA

if the file has XA attributes; 0 if not

=item is_dir 

1 if a directory; 0 if a not;

=back

FIXME: If you look at iso9660.h you'll see more fields, such as for
Rock-Ridge specific fields or XA specific fields. Eventually these
will be added. Volunteers? 

=cut

sub readdir {
    my($self,@p) = @_;

    my($dirname, @args) = _rearrange(['DIRNAME'], @p);
    return undef if _extra_args(@args);

    if (!defined($dirname)) {
      print "*** A directory name must be given\n";
      return undef;
    }

    my @values = perliso9660::ifs_readdir($self->{iso9660}, $dirname);

    # Remove the two input parameters
    splice(@values, 0, 2) if @values > 2;

    my @result = ();
    my $i      = 0;
    while ( $i < @values ) {
	my $href = {};
	$href->{filename} = $values[$i++];
	$href->{LSN}      = $values[$i++];
	$href->{size}     = $values[$i++];
	$href->{sec_size} = $values[$i++];
	$href->{is_dir}   = $values[$i++];
	$href->{XA}       = $values[$i++];
	push @result, $href;
    }
    return @result;
}

=pod

=head2 read_pvd

read_pvd()->pvd

Read the Super block of an ISO 9660 image. This is the Primary Volume
Descriptor (PVD) and perhaps a Supplemental Volume Descriptor if
(Joliet) extensions are acceptable.

=cut

sub read_pvd {
    my($self,@p) = @_;
    return 0 if !_check_arg_count($#_, 0);

    # FIXME call new on PVD object
    return perliso9660::ifs_read_pvd($self->{iso9660});
}

=pod

=head2 read_superblock

read_superblock(iso_mask=$libiso9660::EXTENSION_NONE)->bool

Read the Super block of an ISO 9660 image. This is the Primary Volume
Descriptor (PVD) and perhaps a Supplemental Volume Descriptor if
(Joliet) extensions are acceptable.

=cut

sub read_superblock {
    my($self,@p) = @_;
    my($iso_mask) = rearrange(['ISO_MASK'], @p);
    
    $iso_mask = $perliso9660::EXTENSION_NONE if !defined($iso_mask);

    return perliso9660::ifs_read_superblock($self->{iso9660}, $iso_mask);
}

=pod 

=head2 seek_read

seek_read(start, size)->(size, str)

Seek to a position and then read n bytes. Size read is returned.

=cut

sub seek_read {
    my($self,@p) = @_;
    my($start, $size) = rearrange(['START', 'SIZE'], @p);
    
    (my $data, $size) = perliso9660::seek_read($self->{iso}, $start, $size);
    return wantarray ? ($data, $size) : $data;
}

1; # Magic true value requred at the end of a module

__END__

=pod

=head1 SEE ALSO

L<Device::Cdio> for general information on the CD Input and Control
Library, L<Device::Cdio::Device> for device objects and
L<Device::Cdio::Track> for track objects.

L<perliso9660> is the lower-level interface to libcdio.

L<http://www.gnu.org/software/libcdio> has documentation on
libcdio including the a manual and the API via doxygen.

=head1 AUTHORS

Rocky Bernstein C<< <rocky at cpan.org> >>.

=head1 COPYRIGHT

Copyright (C) 2006 Rocky Bernstein <rocky@cpan.org>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=cut
