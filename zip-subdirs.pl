#!/usr/bin/perl
BEGIN { 
	# Need to explicitly set @INC so that when
	# packed into .exe (via pp) and run,
	# will be able to find libraries.
	push @INC, '/Dwimperl/perl/site/lib';
	push @INC, '/Dwimperl/perl/vendor/lib';
	push @INC, '/Dwimperl/perl/lib';
	use File::Spec 3.33;
	use FindBin; 
}


=head1 Author

Created by Andrew Proper, 2016

https://endosynth.wordpress.com/

andrewrproper@gmail.com


=head1 License : GPL v3

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut



use strict;
use warnings;
use feature ':5.10';

use Wx 0.9903 ':image';
use Archive::Zip 1.30;
use File::Spec 3.33;
use File::Find 1.19;
use POSIX 1.24;
use Time::HiRes 1.9724;
use YAML 0.77;

use lib File::Spec->catfile( $FindBin::Bin, 'lib' );
use Number::Bytes::Human 0.09;

package MyApp;
use base 'Wx::App';

my $config_fn = $FindBin::Bin.'/config.yaml';

my %config = ();
eval {
	my $config_ref = YAML::LoadFile( $config_fn );
	if ( ref $config_ref eq 'HASH' ) {
		%config = %$config_ref;
	}
};
my $e = $@;
if ( $e ) {
	chomp $e;
	say 'ERROR - failed to load config, using defaults';
	say 'ERROR - yaml error: '.$e;
}

#my $regex_is_2notbackup = qr{2notbackup};

say 'DEBUG - config{get_tree_du_max_ms}: '.( $config{get_tree_du_max_ms} || '' );
my $get_tree_du_max_ms = $config{get_tree_du_max_ms} || 3000;

my $dir_size_run_start_ut = time();
my $dir_size_started_run = 0;
my $generic_filter_file_count = 0;

# The OnInit method is called automatically when an
# application object is first constructed.
# Application level initialization can be done here.

sub OnInit {
	my $self = shift;

	$self->{list_data_by_pos} = {};
	$self->{_load_base}{load_base_path_entries} = [];


	# BEGIN - GUI elements
	
	# create a new frame (a frame is a top level window)
	$self->{frame} = Wx::Frame->new(
		undef,           # parent window
		-1,              # ID -1 means any
		'Zip Subdirs',   # title
		&Wx::wxDefaultPosition, # window position
		[ 800, 600 ], # &Wx::wxDefaultSize,     # window size
	);

	## http://www.programmingforums.org/thread15370.html
	## http://www.wxperl.it/p/wxperl-primer.html
	my $app_icon = Wx::Icon->new('resources/zip-subdirs-icon-export.ico', Wx::wxBITMAP_TYPE_ICO, 16,16 ); # needed to use ':image'
	$self->{frame}->SetIcon( $app_icon );


	my $sizer = Wx::BoxSizer->new(&Wx::wxVERTICAL);

	my $head_bar = Wx::StatusBar->new(
		$self->{frame},
		-1,
	);
	$sizer->Add( $head_bar, 1, &Wx::wxEXPAND );
	my $web_url = 'https://endosynth.wordpress.com/category/zip-subdirs/';
	$head_bar->SetStatusText( '  zip-subdirs - created by Andrew Proper 2016 - '.$web_url );

	my $help_bar = Wx::StatusBar->new(
		$self->{frame},
		-1,
	);
	$sizer->Add( $help_bar, 1, &Wx::wxEXPAND );
	$help_bar->SetStatusText( '      For help, see README.html' );



	my $win_home = $ENV{HOMEDRIVE}.$ENV{HOMEPATH};
	my $base_path = File::Spec->catfile( $win_home, 'Documents' );

	my $dir_picker = Wx::DirPickerCtrl->new(
			$self->{frame},
			-1,
			$base_path, # path
			'Choose new base directory: ', # dir selector prompt string
			&Wx::wxDefaultPosition,
			[ 500, 20 ], # &Wx::wxDefaultSize,
			&Wx::wxDIRP_USE_TEXTCTRL, # style
			);
	$sizer->Add( $dir_picker, 1, &Wx::wxEXPAND );

	my $status_bar = Wx::StatusBar->new(
			$self->{frame},
			-1,
			);
	$sizer->Add( $status_bar, 1, &Wx::wxEXPAND );
	$status_bar->SetStatusText( '  base dir: '.$base_path );

	my $load_button = Wx::Button->new(
		$self->{frame},
		'-1',
		'load files list',
	);
	$sizer->Add( $load_button, 1, &Wx::wxEXPAND );

	$self->{list_box} = Wx::ListBox->new(
		$self->{frame},
		-1,
		&Wx::wxDefaultPosition,
		&Wx::wxDefaultSize,
		#0, # n
		[],	# choices
		&Wx::wxLB_MULTIPLE, # style
	);
	$sizer->Add( $self->{list_box}, 6, &Wx::wxEXPAND );

	my $button_run = Wx::Button->new( 
			$self->{frame}, 
			-1,
			'create a zip of each selected path',
	);
	$sizer->Add( $button_run, 1, &Wx::wxEXPAND );

	$self->{status_text} = Wx::TextCtrl->new( 
		$self->{frame}, # parent
		-1, # id
		'', # value
		&Wx::wxDefaultPosition, # position
		&Wx::wxDefaultSize,  # size
		&Wx::wxTE_MULTILINE | &Wx::wxTE_READONLY, # style, needs multiline for logging

	);
	$sizer->Add( $self->{status_text}, 6, &Wx::wxEXPAND );

	my $status_log = Wx::LogTextCtrl->new( $self->{status_text} );
	Wx::Log::SetActiveTarget( $status_log );

	$self->{frame}->SetSizer( $sizer );

	# END - GUI elements

	# BEGIN - GUI events


	Wx::Event::EVT_DIRPICKER_CHANGED( $dir_picker, -1, sub {
		my $this_dir_picker = shift;
		my $event			= shift;

		my $new_base_path = $this_dir_picker->GetPath();
		$status_bar->SetStatusText( 'base dir: '.$new_base_path );

		# will be processed when idle event is called
		$self->_load_base_path_entries( $new_base_path );
	} );

	Wx::Event::EVT_BUTTON($load_button, -1, sub {
		my $this_button = shift;
		my $event  = shift;

		my $new_base_path = $dir_picker->GetPath();

		# will be processed when idle event is called
		$self->_load_base_path_entries( $new_base_path );
	});


	my $bytes_per_mb = 1024 * 1024;

	Wx::Event::EVT_BUTTON($button_run, -1, sub {
		my $this_button = shift;
		my $event  = shift;


		# fork to start child process, which will complete the zipping
		my $pid = fork;
		Wx::wxLogMessage( 'starting zip child process: '.$! );
		if ( ! defined $pid ) {
			Wx::wxLogMessage( 'failed to start zip child process: '.$! );
		} elsif ($pid == 0) { # child gets PID 0


			#$b->SetLabel('Clicked');
			#$b->Disable;
			my @selected_positions = $self->{list_box}->GetSelections();
	
			my $ts = POSIX::strftime( '%Y-%m-%d_%H-%M-%S', localtime() );
			Wx::wxLogMessage( '' );
			Wx::wxLogMessage( 'zipping '.scalar( @selected_positions ).' paths' );
			Wx::wxLogMessage( '' );
			POS: foreach my $pos ( @selected_positions ) {
				my $path = $self->{list_data_by_pos}{ $pos }{path} || 'undef';
	
				my $start_ut = time();
	
				my $zip = Archive::Zip->new();
	
				my $zip_fn = $path.'--'.$ts.'.zip';
	
				my $subdir_name = $path;
				$subdir_name =~ s{.*[\\\/]}{}; # relative folter name only
	
				my $save_as = $subdir_name.'--'.$ts;

				Wx::wxLogMessage( 'zipping '.$path );
				Wx::wxLogMessage( 'as      '.$save_as );
				Wx::wxLogMessage( 'into    '.$zip_fn );
	
				$generic_filter_file_count = 0;
				$zip->addTree( $path, $save_as, sub { _generic_filter( $subdir_name ) } );
				Wx::wxLogMessage( 'found '.$generic_filter_file_count.' items total' );
	
				$self->{status_text}->Update(); # update display
	
				#say 'writing archive to file ['.$zip_fn.']';
				# write object to file
				#   http://www.perlmonks.org/?node_id=1095166
				Wx::wxLogMessage( 'writing zip file to disk: '.$zip_fn );
				if ( $zip->writeToFileNamed( $zip_fn ) != Archive::Zip::AZ_OK ) {
					Wx::wxLogError( 'failed to write zip to '.$zip_fn.' - '.$! );
					Wx::wxLogError( 'aborting zipping' );
					return 0;
				}
				my $size = Number::Bytes::Human::format_bytes( -s $zip_fn );
				Wx::wxLogMessage( 'OK - zipped to '.$zip_fn.' ['.$size.'] in '.( time() - $start_ut ).' s ' );
				Wx::wxLogMessage( '' );
	
				$self->{status_text}->Update(); # update display
			}
			Wx::wxLogMessage( 'done zipping selected paths' );

		}
	});

	Wx::Event::EVT_IDLE( $self, sub {
		$self->_work_when_idle();
	} );


	# END - GUI events


	# BEGIN - init GUI

	# show the frame
	$self->{frame}->Show( 1 );

	$self->{frame}->Update(); # update display

	
	# END - init GUI

    
	# The OnInit sub must return a true value or the wxApp
	# will not start. Although an explicit return is not
	# necessary as the $self->{frame}->Show line will return
	# a true value, we'll include an explicit line
	# in this example.
    
	return 1;
}

sub _work_when_idle {
	my $self 	= shift;
	my $event	= shift;


	my $entries_ref = $self->{_load_base}{load_base_path_entries};
	if ( ref $entries_ref ne 'ARRAY' ) {
		Wx::wxLogError( 'entries_ref should be an ARRAY ref' );
		return;
	}

	if ( scalar @$entries_ref && ! $dir_size_started_run ) {
		$dir_size_started_run = 1;
		$dir_size_run_start_ut = time();
	}

	my $short_entry = shift @$entries_ref;

	if ( ! $short_entry ) {
		return;
	}
	if ( $short_entry =~ /^\.\.*$/ ) {
		return;
	}
	if ( $short_entry eq '' ) {
		return;
	}

#	my $prefix = '[_idle_worker] ';
#	Wx::wxLogMessage( $prefix.'short_entry ['.$short_entry.']' );

	my $entry = File::Spec->catfile( $self->{_load_base}{base_path}, $short_entry );
#	if ( $entry =~ /\s/ ) {
#		$entry = '"'.$entry.'"';
#	}
	#Wx::wxLogMessage( 'load_base_path '.$entry );
	if ( ! -d $entry ) { # only add sub-directories
		return;
	}
	$self->{_load_base}{dirs_count}++;
	my ( $size, $aborted ) = $self->_get_tree_du_bytes( $entry );
	if ( defined $size ) {
		$size = Number::Bytes::Human::format_bytes( $size );
	} else {
		$size = '??';
	}

	$self->{list_data_by_pos}{ $self->{_load_base}{pos} } = {
		path => $entry,
		size => $size,
	};
	my $pad_length = ( 100 - length( $entry ) ) / 2;

	$self->{list_box}->Append( $entry.' '.( '. ' x $pad_length ).' '.$size.( $aborted ? ' +' : '' ) );
	$self->{list_box}->Update(); # update display
	$self->{frame}->Update(); # update display
	$self->{_load_base}{pos}++;


	if ( ! @$entries_ref ) { # no entries left, so at end of base_path entries list
		$dir_size_started_run = 0;
		if ( ! $self->{_load_base}{dirs_count} ) {
			Wx::wxLogWarning( 'no subdirs found under '.$self->{_load_base}{base_path} );
		} else {
			my $duration_secs = time() - $dir_size_run_start_ut;
			Wx::wxLogMessage( 'loaded '.$self->{_load_base}{dirs_count}.
				' subdirs of '.$self->{_load_base}{base_path}.' in '.$duration_secs.' secs' );
		}
	}
}



sub _load_base_path_entries {
	my $self = shift;
	my $base_path = shift;

	$self->{status_text}->Clear();
	$self->{status_text}->Update();
	$self->{list_box}->Clear();
	$self->{list_box}->Update();
	$self->{list_data_by_pos} = {};
	Wx::wxLogMessage( 'loading subdirs of '.$base_path.' ...' );

	my $DIR;
	if ( ! opendir( $DIR, $base_path ) ) {
		Wx::wxLogWarning( 'failed to open dir ['.$base_path.'] - '.$! );
		return undef;
	}
	my @entries = readdir( $DIR );
	closedir $DIR;

	# store data for _work_when_idle to process
	$self->{_load_base}{pos} 					= 0;
	$self->{_load_base}{base_path} 				= $base_path;
	$self->{_load_base}{load_base_path_entries} = \@entries;
	$self->{_load_base}{dirs_count} 			= 0;

	return;

}

sub _get_tree_du_bytes {
	my $self = shift;
	my $path = shift;

	my ( $start_secs, $start_ms ) = Time::HiRes::gettimeofday();

	my $prefix = '[tree_du] ';



	my $bytes = 0;
	my $aborted = 0;
	if ( -d $path ) {
		# get size of directory
		FIND_SIZE: {
			File::Find::find(
				sub {
					my ( $now_secs, $now_ms ) = Time::HiRes::gettimeofday();
					my $elapsed_ms   = $now_ms   - $start_ms;
					if ( $elapsed_ms > $get_tree_du_max_ms ) { # if reading has taken more than these many seconds
						$aborted = 1;
						say 'WARNING - too long to read size ['.$elapsed_ms.' ms] abort: '.$path;
						last FIND_SIZE; # exit out of File::Find::find
					}

					my $full_fn = $File::Find::name;
					if ( -f $full_fn ) {
						$bytes += -s $full_fn;
					}
				},
				$path
			);
		}
	}


	return ( $bytes, $aborted );
}



sub _generic_filter {   # filter sub add only selected files
	my $descr = shift;

	my $file = $_;

	my $start = 'filter['.$descr.']';
	my $end = '['.$file.']';
#	if ( $file =~ $regex_is_2notbackup ) {
#		Wx::wxLogMessage( $start.' reject: 2notbackup '.$end );
#		return 0;
#	}
	if ( ! -e $file ) {
		Wx::wxLogMessage( $start.' reject: not found '.$end );
		return 0;
	} else {
		$generic_filter_file_count++;
		if ( $generic_filter_file_count % 250 == 0 ) {
			Wx::wxLogMessage( 'found '.$generic_filter_file_count.' items' );
		}
	}
	return 1;
}


###############################################
###############################################
###############################################


package main;

# create the application object, this will call OnInit
# before the constructor returns.

my $app = MyApp->new;

# process GUI events from the application this function
# will not return until the last frame is closed

$app->MainLoop;




# vim: set paste
