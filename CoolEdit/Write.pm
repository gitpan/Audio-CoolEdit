package Audio::CoolEdit::Write;

use strict;
use Audio::CoolEdit::Write::BlockPack;
use FileHandle;
use Cwd;

=head1 NAME

Audio::CoolEdit::Write - Methods for writing
Syntrillium CoolEdit Pro .ses files.

=head1 SYNOPSIS

	use Audio::CoolEdit;

	my $cool = new Audio::CoolEdit;

	my $details =	{
			'bits_sample'	=> 16,
			'sample_rate'	=> 44100,
			};

	my $write = $cool -> write( './test', $details );

=head1 NOTES

This module shouldn't be used directly, a blessed object can be returned from L<Audio::CoolEdit>.

=head1 AUTHOR

Nick Peskett - nick@soup.demon.co.uk

=head1 SEE ALSO

	L<Audio::CoolEdit>

	L<Audio::CoolEdit::Read>

=head1 METHODS

=cut

sub new {
	my $class = shift;
	my( $out_file, $details, $settings ) = @_;

	$out_file .= '.ses';
	my $handle = new FileHandle join( '', '>', $out_file );
	unless ( defined $handle ) {
		my $error = $!;
		chomp( $error );
		die "unable to open file '$out_file' ($error)"
	}
	binmode $handle;
	print "creating cooledit file '$out_file'\n";

	unless ( exists $details -> {'block_align'} ) {
		$details -> {'block_align'} = 2 * int( $details -> {'bits_sample'} / 8 );
	}

	my $self =	{
				'out_file'	=> $out_file,
				'settings'	=> $settings,
				'len_pack'	=> $settings -> get_len_pack(),
				'data'		=> '',
				'version'	=> '1.1',
				'fade_steps'	=> 12,
				'files'		=> [],
				'cues'		=> [],
				'total_length'	=> 0,
				'no_tracks'	=> 0,
				'details'	=> $details,
				'handle'	=> $handle,
				'block_pack'	=> Audio::CoolEdit::Write::BlockPack -> new( $settings ),
			};
	bless $self, $class;
	return $self;
}

=head2 file_name

Returns the filename of the session file to be written.

	my $file = $write -> file_name();

=cut

sub file_name {
	my $self = shift;
	return $self -> {'out_file'};
}

=head2 add_file

Adds a wav file to the current ses file.
Takes a reference to a hash as the only parameter.
This hash should at least contain a path to the wav file.

	use Audio::Tools::Fades;
	my $fade_type = 'trig';
	my $fade_length = 20000;
	my $fades = new Audio::Tools::Fades;
	my $fade_sub = $fades -> fade( $fade_length, 0, $fade_type );

	my $record =	{
				'file'		=> './t/testout.wav',
				'offset'	=> 0,
				'title'		=> "song 1",
				'fade'		=> {
						   'in'	=>	{
								'type'	=> $fade_type,
								'fade'	=> $fade_sub,
								'start'	=> 0,
								'end'	=> $fade_length,
								},
						   },
			};

	$write -> add_file( $record );

Parameters are; (* optional)

	file	=> path to wav file
	offset*	=> offset in bytes to place the file.
	start*	=> the byte offset to start the file at.
	end*	=> the byte offset to stop the file at.
	length*	=> length of data in bytes
	title*	=> title of file
	fade*	=> this should be a reference to a hash

If you don't supply length or offset you will need to install
the Audio::Wav module so the file can be analysed.

The fade hash should be in the following format;
see L<Audio::Tools::Fades>

	in/out	=>	{
			type	=> linear/ exp/ invexp/ trig/ invtrig
			fade	=> return from Audio::Tools::Fades -> fade method,
			start	=> fade starts (bytes),
			end	=> fade ends (bytes),
			}

=cut

sub add_file {
	my $self = shift;
	my $record = shift;
	unless ( exists $record -> {'length'} ) {
		require Audio::Wav;
		$record -> {'length'} = Audio::Wav -> new() -> read( $record -> {'file'} ) -> length();
	}
	my $files = $self -> {'files'};
	unless ( exists $record -> {'offset'} ) {
		if ( scalar @$files ) {
			my $rec = $files -> [ $#$files ];
			$record -> {'offset'} = $rec -> {'length'} + $rec -> {'offset'};
		} else {
			$record -> {'offset'} = 0;
		}
	}
	push @$files, $record;
}

=head2 add_cue

Adds a cuepoint to the current file.

	$write -> add_cue( $byte_offset, 'Name', 'Description' );

=cut

sub add_cue {
	my $self = shift;
	my $pos = shift;
	my $name = shift;
	my $desc = shift;

	my $record =	{
			'sample_pos'	=> $self -> _fix_sample( $pos ),
			'name'		=> defined($name) ? $name : '',
			'desc'		=> defined($desc) ? $desc : '',
			};

	push @{ $self -> {'cues'} }, $record;
}

=head2 finish

Finish & write the current file.

	$write -> finish();

=cut

sub finish {
	my $self = shift;
	$self -> _write_version();
	my $files = $self -> {'files'};

	my $wav_list = [];
	my $wav_data = [];
	my $tracks = [];
	my $envelope = [];

	my $last_file = $#$files;

#	print Data::Dumper->Dump([ $files ]);

	foreach my $id ( 0 .. $last_file ) {
		$self -> {'no_tracks'} ++;
		my $wav_id = $id + 1;
		my $record = $files -> [$id];

		my $length = $record -> {'length'};
		my $offset = $record -> {'offset'};

#		print Data::Dumper->Dump([ $record ], ['record']);

		push @$tracks,
			{
			'left_vol'	=> 1,
			'right_vol'	=> 1,
			'flags'		=> 0,
			'title'		=> exists( $record -> {'title'} ) ? $record -> {'title'} : '',
			'wave_in_id'	=> 1,
			'wave_out_id'	=> 1,
			'wave_in_mode'	=> 0,
			'wave_out_mode'	=> 0,
			};

#		my $path = $in_dir . '/' . $record -> {'file'} . '.wav';
		my $path = $record -> {'file'};
		if ( $path =~ /^(\.+)(.*)/ ) {
			$path = cwd() . $2;
		}
		$path =~ s#/+#\\#g;
		push @$wav_list,
			{
			'wav_id'	=> $wav_id,
			'file_format'	=> 17,
			'filename'	=> $path,
			};

		push @$wav_data,
			{
			'left_vol'	=> 1,
			'right_vol'	=> 1,
			'offset'	=> $self -> _fix_sample( $offset ),
			'size_samp'	=> $self -> _fix_sample( $length ),
			'wav_id'	=> $wav_id,
			'flags'		=> 0,
			'uniq_wav_id'	=> $wav_id,
			'track'		=> $wav_id,
			'parent_group'	=> 0,
			'offset_wav'	=> 0,
			};

		push @$envelope, $self -> _add_fades( $wav_id, $record, $length );
		next unless $id == $last_file;
		$self -> {'total_length'} = $self -> _fix_sample( $length + $offset );
	}

#	print Data::Dumper->Dump([ $envelope ]);


	$self -> _write_state();

	$self -> _add_block( 'tracks', $tracks );
	$self -> _add_block( 'wav_list', $wav_list );
	$self -> _add_block( 'wav_data', $wav_data );
	$self -> _add_block( 'envelope', $envelope );
	$self -> _add_block( 'cues', $self -> {'cues'} );

	$self -> _write_file();
}

sub _add_fades {
	my $self = shift;
	my $id = shift;
	my $record = shift;
	my $length = shift;

	my $fades = $record -> {'fade'};
#	print Data::Dumper->Dump([ $record ]);
#	exit;

	my @points;

	my %supplied;

	foreach my $type ( qw( in out ) ) {
		$supplied{$type} = exists( $fades -> {$type} );
		next unless $supplied{$type};
		my $fade = $fades -> {$type};
		my @arg;
		foreach my $arg ( qw( start end fade type ) ) {
			die "missing fade-$type arguement: $arg\n" unless exists( $fade -> {$arg} );
			push @arg, $fade -> {$arg};
		}
		push @arg, $length;
		push @points, $self -> _do_fade( @arg );
	}

	if ( $supplied{'in'} ) {
		my $fade_start = $fades -> {'in'} -> {'start'};
		if ( $fade_start > 0 ) {
			my $sub = $fades -> {'in'} -> {'fade'};
			push @points, [ 0, &$sub( 0, 1 ) ];
		}
	} else {
		if ( exists( $record -> {'start'} ) && $record -> {'start'} ) {
			my $start = $record -> {'start'};
			push @points, [ 0, 0 ];
			push @points, [ $start - 1, 0 ];
			push @points, [ $start, 1 ];
		} else {
			push @points, [ 0, 1 ];
		}
	}

	if ( $supplied{'out'} ) {
		my $fade_end = $fades -> {'out'} -> {'end'};
		if ( $length > $fade_end ) {
			my $sub = $fades -> {'out'} -> {'fade'};
			my $start = $fades -> {'out'} -> {'start'};
			push @points, [ $length, &$sub( $fade_end - $start, 1 ) ];
		}
	} else {
		if ( exists( $record -> {'end'} ) && $length > $record -> {'end'} ) {
			my $end = $record -> {'end'};
			push @points, [ $end, 1 ];
			push @points, [ $end + 1, 0 ];
			push @points, [ $length, 0 ];
		} else {
			push @points, [ $length, 1 ];
		}
	}

	my $output = [ $id ];

	@points = sort { $a -> [0] <=> $b -> [0] } @points;

	foreach my $point ( @points ) {
		push @$output,	{
				'sample_pos'	=> $self -> _fix_sample( $point -> [0] ),
				'value'		=> $point -> [1],
				};
	}

	return $output;
}

sub _do_fade {
	my( $self, $from, $to, $filter, $type ) = @_;
	my $block_align = $self -> {'details'} -> {'block_align'};
	my $length = $to - $from;
	my $steps = $self -> {'fade_steps'};
	$steps = 0 if $type eq 'linear';
	my @output;
	push @output, [ $from, &$filter( 0, 1 ) ];
	if ( $steps > 1 ) {
		my $step = $length / $steps;
		for my $cnt ( 1 .. $steps - 1 ) {
			my $pos = int( $cnt * $step );
			$pos -= $pos % $block_align;
			push @output, [ $from + $pos, &$filter( $pos, 1 ) ];
		}
	}
	push @output, [ $to, &$filter( $length, 1 ) ];
	return @output;
}

sub _fix_sample {
	my $self = shift;
	my $length = shift;
#	return $length;
	my $block_align = $self -> {'details'} -> {'block_align'};
	return $length / $block_align;
}



###################

sub _write_file {
	my $self = shift;
	my $details = $self -> {'details'};

# die Data::Dumper->Dump([ $self ]);
	my $blocks = $self -> {'data'};
	$self -> {'data'} = '';

	my $header =	{
			'sample_rate'		=> $details -> {'sample_rate'},
			'sample_in_sesh'	=> $self -> _fix_sample( $self -> {'total_length'} ),
			'wav_blocks'		=> $self -> {'no_tracks'}, # scalar( @{ $self -> {'files'} } ),
			'bits_sample'		=> $details -> {'bits_sample'},
			'channels'		=> 1,	# $details -> {'channels'},
			'master_vol'		=> 1,
			'master_vol_r'		=> 1,
			'sesh_offset'		=> 0, 	# $self -> {'total_length'},
			'save_assoc'		=> 0,
			'private'		=> 0,
			'filename'		=> '',
			};

	$self -> _add_block( 'header', $header );

	my $data = $self -> {'data'} . $blocks;
	my $output = 'COOLNESS';
	$output .= pack( $self -> {'len_pack'}, length( $data ) );
	$output .= $data;

	my $handle = $self -> {'handle'};
	my $out_len = length( $output );
	my $wrote = syswrite $handle, $output, $out_len;
	$handle -> close();
	print "wrote: $wrote bytes\n";
}

sub _write_version {
	my $self = shift;
	my $version = 'Cool Edit Pro ' . $self -> {'version'};
	$self -> _add_block( 'version', { 'version' => $version } );
}

sub _write_state {
	my $self = shift;
	my $state =	{
                  	'left_view'		=> -0.5,
                  	'right_view'		=> $self -> {'total_length'} + .5,
                  	'bottom_view'		=> 1,
                  	'top_view'		=> $self -> {'no_tracks'},
			};

	$self -> _add_block( 'state', $state );
}

sub _add_block {
	my $self = shift;
	my $type = shift;
	my $record = shift;
	$self -> {'data'} .= $self -> {'block_pack'} -> make_block( $type, $record );
}

1;

