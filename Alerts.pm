package Log::Dispatch::File::Alerts;

use 5.006001;
use strict;
use warnings;

use Log::Dispatch::File;
use Log::Log4perl::DateFormat;
use Fcntl ':flock'; # import LOCK_* constants

our @ISA = qw(Log::Dispatch::File);

our $VERSION = '1.00';

our $TIME_HIRES_AVAILABLE = undef;

BEGIN { # borrowed from Log::Log4perl::Layout::PatternLayout, Thanks!
	# Check if we've got Time::HiRes. If not, don't make a big fuss,
	# just set a flag so we know later on that we can't have fine-grained
	# time stamps
	
	eval { require Time::HiRes; };
	if ($@) {
		$TIME_HIRES_AVAILABLE = 0;
	} else {
		$TIME_HIRES_AVAILABLE = 1;
	}
}

# Preloaded methods go here.

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	
	my %p = @_;
	
	my $self = bless {}, $class;
	
	# only append mode is supported
	$p{mode} = 'append';
	# 'close' mode is always used
	$p{close_after_write} = 1;
	
	# base class initialization
	$self->_basic_init(%p);

	# split pathname into path, basename, extension
	if ($p{filename} =~ /^(.*)\%d\{([^\}]*)\}(.*)$/) {
		$self->{rolling_filename_prefix}  = $1;
		$self->{rolling_filename_postfix} = $3;
		$self->{rolling_filename_format}  = Log::Log4perl::DateFormat->new($2);
		$p{filename} = $self->_createFilename(0);
	} elsif ($p{filename} =~ /^(.*)(\.[^\.]+)$/) {
		$self->{rolling_filename_prefix}  = $1;
		$self->{rolling_filename_postfix} = $2;
		$self->{rolling_filename_format}  = Log::Log4perl::DateFormat->new('-yyyy-MM-dd-$!');
		$p{filename} = $self->_createFilename(0);
	} else {
		$self->{rolling_filename_prefix}  = $p{filename};
		$self->{rolling_filename_postfix} = '';
		$self->{rolling_filename_format}  = Log::Log4perl::DateFormat->new('.yyyy-MM-dd-$!');
		$p{filename} = $self->_createFilename(0);
	}

	$self->_make_handle(%p);
			
	return $self;
}

sub log_message { # parts borrowed from Log::Dispatch::FileRotate, Thanks!
	my $self = shift;
	my %p = @_;
	my $try = '0001';

	while (defined $try) {
		$self->{filename} = $self->_createFilename($try);
		$self->_open_file;
		$self->_lock();
		my $fh = $self->{fh};
		if (not -s $fh) {
			# if the file is not zero-sized, it s fresh.
			# else someone else already used it.
			print $fh $p{message};
			$self->_unlock();
			close($fh);
			$self->{fh} = undef;
			$try = undef;
		} else {
			$try++;
			if ($try > 9999) {
				die 'could not find an unused file for filename "'
				. $self->{filename}
				. '". Did you use "!"?';
			}
		}
	}
}

sub _lock { # borrowed from Log::Dispatch::FileRotate, Thanks!
	my $self = shift;
	flock($self->{fh},LOCK_EX);
	# Make sure we are at the EOF
	seek($self->{fh}, 0, 2);
	return 1;
}

sub _unlock { # borrowed from Log::Dispatch::FileRotate, Thanks!
	my $self = shift;
	flock($self->{fh},LOCK_UN);
	return 1;
}

sub _current_time { # borrowed from Log::Log4perl::Layout::PatternLayout, Thanks!
	# Return secs and optionally msecs if we have Time::HiRes
	if($TIME_HIRES_AVAILABLE) {
		return (Time::HiRes::gettimeofday());
	} else {
		return (time(), 0);
	}
}

sub _createFilename {
	my $self = shift;
	my $try = shift;
	return $self->{rolling_filename_prefix}
	     . $self->_format($try)
	     . $self->{rolling_filename_postfix};
}

sub _format {
	my $self = shift;
	my $try = shift;
	my $result = $self->{rolling_filename_format}->format($self->_current_time());
	$result =~ s/(\$+)/sprintf('%0'.length($1).'.'.length($1).'u', $$)/eg;
	$result =~ s/(\!+)/sprintf('%0'.length($1).'.'.length($1).'u', $try)/eg;
	return $result;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Log::Dispatch::File::Alerts - Object for logging to alert files

=head1 SYNOPSIS

  use Log::Dispatch::File::Alerts;

  my $file = Log::Dispatch::File::Alerts->new(
                             name      => 'file1',
                             min_level => 'emerg',
                             filename  => 'Somefile%d{yyyy!!!!}.log',
                             mode      => 'append' );

  $file->log( level => 'emerg',
              message => "I've fallen and I can't get up\n" );

=head1 ABSTRACT

This module provides an object for logging to files under the
Log::Dispatch::* system.

=head1 DESCRIPTION

This module subclasses Log::Dispatch::File for logging to date/time 
stamped files. See L<Log::Dispatch::File> for instructions on usage. 
This module differs only on the following three points:

=over 4

=item alert files

This module will use a seperate file for every log message.

=item multitasking-safe

This module uses flock() to lock the file while writing to it.

=item stamped filenames

This module supports a special tag in the filename that will expand to 
the current date/time/pid.

It is the same tag Log::Log4perl::Layout::PatternLayout uses, see 
L<Log::Log4perl::Layout::PatternLayout>, chapter "Fine-tune the date". 
In short: Include a "%d{...}" in the filename where "..." is a format 
string according to the SimpleDateFormat in the Java World 
(http://java.sun.com/j2se/1.3/docs/api/java/text/SimpleDateFormat.html). 
See also L<Log::Log4perl::DateFormat> for information about further 
restrictions.

In addition to the format provided by Log::Log4perl::DateFormat this 
module also supports '$' for inserting the PID and '!' for inserting a 
uniq number. Repeat the character to define how many character wide the 
field should be.

A note on the '!': The module first tries to find a fresh filename with 
this set to 1. If there is already a file with that name then it is 
increased until either a free filename has been found or it reaches 
9999. In the later case the module dies.

=head1 HISTORY

=over 8

=item 0.99

Original version; taken from Log::Dispatch::File::Rolling 1.02

=item 1.00

Initial coding

=back

=head1 SEE ALSO

L<Log::Dispatch::File>, L<Log::Log4perl::Layout::PatternLayout>, 
L<Log::Dispatch::File::Rolling>, L<Log::Log4perl::DateFormat>, 
http://java.sun.com/j2se/1.3/docs/api/java/text/SimpleDateFormat.html, 
'perldoc -f flock'

=head1 AUTHOR

M. Jacob, E<lt>jacob@j-e-b.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003 M. Jacob E<lt>jacob@j-e-b.netE<gt>

Based on:

  Log::Dispatch::File::Stamped by Eric Cholet <cholet@logilune.com>
  Log::Dispatch::FileRotate by Mark Pfeiffer, <markpf@mlp-consulting.com.au>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
