package Audio::CoolEdit::Settings;

use strict;
use Audio::Tools::ByteOrder;

# dword = long
# dword	I	unsigned
# double  d	double prec float
# int	i
# word	S

my %blocks =
	(
	# HEADER BLOCK
	# 4	text 	Header "hdr "
	# 4	DWORD 	Length of header data
	# 4	int	Sample Rate
	# 4	DWORD	Samples in Session (may be longer than all waves in session)
	# 4	int	Number of Wave Blocks
	# 2	WORD	Bits per Sample (16 or 32)
	# 2	WORD	Channels (not used - must be set to 1)
	# 8	double	Master volume (1.0=unity)
	# 8	double 	Master volume right (not used - set to Master Volume)
	# 4	DWORD	Session time offset in samples (for SMPTE and ruler display)

	# 4	BOOL	Save Associated Files separately flag (1=yes)
	# 4	BOOL	Private (must be zero)
	# 256	SZ	Filename string (generally blank)
	'header'	=> {
				'header'	=> 'hdr ',
				'data'		=> [
							   [ 'sample_rate',	'int'	],
							   [ 'sample_in_sesh',	'long'	],
							   [ 'wav_blocks',	'int'	],
							   [ 'bits_sample',	'word'	],
							   [ 'channels',	'word'	],
							   [ 'master_vol',	'double'],
							   [ 'master_vol_r',	'double'],
							   [ 'sesh_offset',	'long'	],

							   [ 'save_assoc',	'word'	],
							   [ 'private',		'word'	],
							   [ 'filename',	'z256'	],
						   ]
			   },

	# VERSION BLOCK
	# 4	text 	header "vers"
	# 4	DWORD 	length of version data
	# N	SZ	Version string (zero terminated).
	'version'	=> {
				'header'	=> 'vers',
				'data'		=> [
							   [ 'version',	'z'	],
						   ]
			   },

	# PROGRAM STATE BLOCK
	# 4	text 	Header "stat"
	# 4	DWORD 	Length of state data
	# 8	double	Left Sample viewing
	# 8	double	Right Sample viewing
	# 8	double	Bottom track viewing
	# 8	double	Top track viewing
	# 4	DWORD	Low Sample Selected
	# 4	DWORD	High Sample Selected
	'state'	=> {
				'header'	=> 'stat',
				'data'		=> [
							   [ 'left_view',	'double'],
							   [ 'right_view',	'double'],
							   [ 'bottom_view',	'double'],
							   [ 'top_view',	'double'],
							   [ 'low_samp_sel',	'long'	],
							   [ 'high_samp_sel',	'long'	],
						   ]
			   },

	# TEMPO BLOCK
	# 4	text 	Header "tmpo"
	# 4	DWORD 	Length of tempo data
	# 8	double	Beats per Minute
	# 4	int	Beats per Bar
	# 4	int	Ticks per Quarter Note (ticks per beat)
	# 8	double	Beat Offset In Milliseconds (location of first beat)
	'tempo'	=> {
				'header'	=> 'tmpo',
				'data'		=> [
							   [ 'bpm',		'double'],
							   [ 'beats_per_bar',	'int'	],
							   [ 'ticks_per_beat',	'int'	],
							   [ 'beat_offset',	'double'],
						   ]
			   },

	# TRACKS BLOCK
	# 4	text 	Header 'trks'
	# 4	DWORD 	Length of tracks data
	# 4	DWORD	Count of tracks (N) (size of individual track block = (dwLength-4)/N )
	# N tracks follow, each formatted as:
	# 8	double	Left Volume (absolute, 1.0=unity)
	# 8	double	Right Volume
	# 4	DWORD	Flags (Mute=0x1, Solo=0x2, Record=0x4)
	# 36	SZ	Text Title

	# 4	UINT	ID of Wave In device
	# 4	UINT	ID of Wave Out device
	# 2	WORD	Wave In Mode (0=record stereo, 1=record left only, 2=record right only)
	# 2	WORD 	Wave Out Mode (0=stereo, 1=output from left channel only, 2=output from right)
	# 2	WORD 	wUnused1;
	# 2	WORD 	wUnused2;
	'tracks'	=> {
				'header'	=> 'trks',
				'multi'		=> 1,
				'data'		=> [
							   [ 'left_vol',	'double'],
							   [ 'right_vol',	'double'],
							   [ 'flags',		'long'	],
							   [ 'title',		'z36'	],
							   [ 'wave_in_id',	'long'	],
							   [ 'wave_out_id',	'long'	],
							   [ 'wave_in_mode',	'word'	],
							   [ 'wave_out_mode',	'word'	],
							   [ 'unused_1',	'word'	],
							   [ 'unused_2',	'word'	],
						   ]
			   },

	# WAVES LIST
	# 4	text	Header 'LIST'
	# 4	text	Header Type 'FILE'
	# 4	DWORD	Length of list
	# Entries follow, each formatted as:
	# 4	text	Header 'wav '
	# 4	DWORD	Length of wave data
	# 4	DWORD	Unique Waveform ID
	# 4	DWORD	File Format (cool edit internal - can be set to 0xffffffff or possibly 0)
	# N	SZ	Filename, zero terminated.  N=Filename Length + 1 (for the zero terminator)
	'wav_list'	=> {
				'header'	=> 'LISTFILE',
				'while'		=> 1,
				'data'		=> [
							   [ 'header',		'Z4'	],
							   [ 'block_length',	'long'	],
							   [ 'wav_id',		'long'	],
							   [ 'file_format',	'long'	],
							   [ 'filename',	'z'	],
						   ]
			   },
	# WAVE BLOCKS BLOCK
	# 4	text 	Header 'blk '
	# 4	DWORD 	Length of wave blocks data
	# 4	DWORD	Count of Wave Blocks (N) (size of individual wave block block = (dwLength-4)/N )
	# N wave blocks  follow, each formatted as:
	# 8	double	Left Volume (1.0=unity)
	# 8	double	Right Volume
	# 8	double	Unused 1
	# 8	double	Unused 2
	# 4	DWORD	Offset of wave block into session in Samples
	# 4	DWORD	Size of block in Samples
	# 4	DWORD	Wave block ID
	# 4	DWORD	Flags (Group=0x1, Locked=0x2, Mute=0x4, NoRecord=0x8, Record=0x10, Punch=0x20)
	# 4	DWORD	Unique Waveform ID
	# 4	int	Track
	# 4	int	Parent Group
	# 4	int	Unused
	# 4	DWORD	Offset into wave file that this block starts at

	# 4	int	Punch Generation
	# 4	int	Previous Punch In block
	# 4	int	Next Punch In block
	# 4	int	Original Index

	'wav_data'	=> {
				'header'	=> 'blk ',
				'multi'		=> 1,
				'data'		=> [
							   [ 'left_vol',	'double'],
							   [ 'right_vol',	'double'],
							   [ 'unused_1',	'double'],
							   [ 'unused_2',	'double'],
							   [ 'offset',		'long'	],
							   [ 'size_samp',	'long'	],
							   [ 'wav_id',		'long'	],
							   [ 'flags',		'long'	],
							   [ 'uniq_wav_id',	'long'	],
							   [ 'track',		'int'	],
							   [ 'parent_group',	'int'	],
							   [ 'unused_3',	'int'	],
							   [ 'offset_wav',	'long'	],

							   [ 'punch',		'int'	],
#							   [ 'prev_punch',	'int'	], # these seem to be for 1.1 only
#							   [ 'next_punch',	'int'	],
#							   [ 'orig_index',	'int'	],
						   ]
			   },

	# ENVELOPES BLOCK
	# 4	text 	Header "envp"
	# 4	DWORD 	Length of envelope data
	# 4	DWORD	Count of Envelopes (N) (size of individual envelope block = (dwLength-4)/N )
	# N envelope blocks  follow, each formatted as:
	# 4	DWORD	Size of this envelope block
	# 4	DWORD	Wave block ID
	# 4	DWORD	Count of Volume points (CtV)
	# 4	DWORD 	Count of Pan points (CtP)
	# CtV volume envelope points, each formatted as:
	# 4	DWORD	Sample Position
	# 8	double	Volume at position (=0.0 to 1.0)
	# 4	DWORD	Unused
	# CtP pan envelope points, each formatted as:
	# 4	DWORD	Sample Position
	# 8	double	Pan at position (0.0=right  to 1.0=left)
	# 4	DWORD	Unused
	'envelope'	=> {
				'header'	=> 'envp',
				'multi'		=> 1,
				'data'		=> [
							   [ 'sample_pos',	'long'	],
							   [ 'unused_1',	'long'	],
							   [ 'value',		'double'],
							   [ 'unused_2',	'double'],
						   ]
			   },

	# CUES BLOCK
	# 4	text 	Header "cues"
	# 4	DWORD 	Length of cue data
	# 4	DWORD	Count of Cues (N)
	# N cue blocks  follow, each formatted as:
	# 4	DWORD	Offset in Samples
	# 4	DWORD	Length in Samples (0=cue, non-zero=range size in samples)
	# 4	WORD	Length of Name (N)		<- this is really 2 bytes
	# 4	WORD	Length of Description (M)	<- this is really 2 bytes
	# N	SZ	Cue Name string
	# M	SZ	Cue Description string
	'cues'		=> {
				'header'	=> 'cues',
				'multi'		=> 1,
				'data'		=> [
							   [ 'sample_pos',	'long'	],
							   [ 'sample_length',	'long'	],
							   [ 'name_len',	'word'	],
							   [ 'desc_len',	'word'	],
							   [ 'name',		'z'	],
							   [ 'desc',		'z'	],
						   ]
			   },
	);

my %block_lookup;
foreach my $block ( keys %blocks ) {
	my $header = $blocks{$block} -> {'header'};
	$block_lookup{$header} = $block;
}

sub new {
	my $class = shift;
	my $byteorder = new Audio::Tools::ByteOrder;

	my $self =	{
				'formats'	=> $byteorder -> pack_type(),
				'len_formats'	=> $byteorder -> pack_length(),
				'byteorder'	=> $byteorder,
			};
#
#
#
#		print Data::Dumper->Dump([ $self -> {'formats'} ]);#
#		exit;







	bless $self, $class;
	return $self;
}

sub len_formats {
	my $self = shift;
	my $type = shift;
	return $self -> {'len_formats'} -> {$type};
}

sub get_format {
	my $self = shift;
	my $type = shift;
	return undef unless exists( $blocks{$type} );
	my $header = $blocks{$type} -> {'header'};
	my $data = $blocks{$type} -> {'data'};
	my $formats = $self -> {'formats'};
	my @output;
	foreach my $row ( @$data ) {
		my( $key, $val ) = @$row;
		if ( $val && $val !~ /^z/i ) {
			$val = $formats -> {$val};
		}
		push @output, [ $key, $val ];
	}
	return ( $header, [ @output ] );
}

sub is_valid_header {
	my $self = shift;
	my $type = shift;
	return undef unless exists( $block_lookup{$type} );
	my $header = $block_lookup{$type};
	return $header;
}

sub is_multi {
	my $self = shift;
	my $header = shift;
	return 0 unless exists( $blocks{$header} -> {'multi'} );
}

sub is_while {
	my $self = shift;
	my $header = shift;
	return 0 unless exists( $blocks{$header} -> {'while'} );
}

sub get_len_pack {
	my $self = shift;
	return $self -> {'formats'} -> {'long'};
}

1;
