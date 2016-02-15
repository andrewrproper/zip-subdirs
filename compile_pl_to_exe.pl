#!/usr/bin/perl

# This program is made to be run with Dwimperl under Windows.
# It required PAR::Packer to be installed via CPAN in Dwimperl.

# exe_update.pl usage: 
#   B<exe_update.pl> S<[ B<--gui> | B<--console> ]> S<[ B<--icon> I<iconfile> ]>
#                 S<[ B<--manifest> I<manifestfile> ]>
#                 S<[ B<--info> I<key=value;...> ]> I<exefile>

use strict;
use warnings;
use feature 'say';

use FindBin;
use Cwd;
use Win32::Exe;

my $prog_name = 'zip-subdirs';

my $wd = Cwd::realpath( $FindBin::Bin );


my $pl_fn = _win_fn( $wd.'\\'.$prog_name.'.pl' );
my $rel_exe_fn = _win_fn( $prog_name.'.exe' );
my $exe_fn = _win_fn( $wd.'\\'.$prog_name.'.exe' );

my $lib_dir = _win_fn( $wd.'\\lib\\' );

my $resources_dir = $wd.'\\resources\\';
#my $icon_fn = _win_fn( $resources_dir.'\\'.$prog_name.'.ico' );
my $short_icon_fn = 'zip-subdirs-icon-export.ico';
my $rel_icon_fn = _win_fn( 'resources\\'.$short_icon_fn );
my $icon_fn = _win_fn( $resources_dir.'\\'.$short_icon_fn );

# compile perl to exe

# This doesn't work, so instead I added code to push these 
# onto @INC inside target .pl file BEGIN clause
#
my @i_flags = ();
#push @i_flags, '-I '._win_fn( $_, { drive => 1 }, ) for @INC;
#push @i_flags, '-I '._win_fn( $lib_dir, { drive => 1 } );

my @include_modules = qw(
);

my $include_modules_string = '';
if ( @include_modules ) {
	$include_modules_string = ' -M '.join( ' -M ', @include_modules ).' ';
}

_run_cmd( 
	'packing pl to exe', 

	'pp '.
		join( ' ', @i_flags ).' '.
		$include_modules_string.
		'--gui '.  			# --gui flag prevents console window from showing
		'-o '.$exe_fn.' '.
		$pl_fn,
);


if ( 0 ) {
	# this breaks .exe with error about not finding XSLoader

	# update icon on exe
	my $exe = Win32::Exe->new( $exe_fn ); 
	$exe->set_single_group_icon( $icon_fn );
	$exe->write;
}

######## SUBROUTINES

sub _win_fn {
	my $fn = shift;
	my $o_ref = shift;

	my %o = ();
	if ( ref $o_ref eq 'HASH' ) {
		%o = %$o_ref;
	}

	$fn =~ s{/}{\\}gs;
	if ( defined $o{drive} && ! $o{drive} ) {
		$fn =~ s{^[A-Za-z]:}{};
	}
	return $fn;
}

sub _run_cmd {
	my $descr 	= shift || '';
	my $cmd 	= shift || '';

	chomp $descr;
	chomp $cmd;

	say ''.( '=' x 40 );
	say $descr;
	say ''.( '-' x 40 );
	say 'running: '.$cmd;
	say ''.( '-' x 40 );
	print qx( $cmd );
	my $exit_val = $? >> 8;
	say ''.( '-' x 40 );
	say 'exit val: '.$exit_val;
	say ''.( '=' x 40 );
	if ( $exit_val ne '0' ) {
		Carp::confess( 'command failed: '.$! );
	}
}

# vim: ts=4 paste

