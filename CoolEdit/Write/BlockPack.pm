package Audio::CoolEdit::Write::BlockPack;

use strict;

sub new {
	my $class = shift;
	my $settings = shift;
	my $self =	{
				'settings'	=> $settings,
				'len_pack'	=> $settings -> get_len_pack(),
			};
	bless $self, $class;
	return $self;
}

sub make_block {
	my $self = shift;
	my $type = shift;
	my $record = shift;

	my $settings = $self -> {'settings'};
	my( $header, $pack ) = $settings -> get_format( $type );

	my $details =	{
				'type'		=> $type,
				'header'	=> $header,
				'pack'		=> $pack,
				'record'	=> $record,
			};


#	print Data::Dumper->Dump( [ $record ], [ $type ] );

	my $block;

	if ( $type eq 'envelope' ) {
		$block = $self -> _add_envelope_block( $details );
	} elsif ( $type eq 'wav_list' ) {
		$block = $self -> _add_wavlist_block( $details );
	} elsif ( $settings -> is_while( $type ) || $settings -> is_multi( $type ) ) {
		$block = $self -> _multi_add_block( $details );
	} else {
		$block = &_make_block( $details );
	}

	$block =
		$header
		. pack( $self -> {'len_pack'}, length( $block ) )
		. $block;
	return $block;
}


######################

sub _add_envelope_block {
	my $self = shift;
	my $details = shift;
#	print Data::Dumper->Dump([ $details ]);
#	die;

	my $len_pack = $self -> {'len_pack'};
	my @env_data = @{ $details -> {'record'} };

	my $output = pack( $len_pack, scalar( @env_data ) );

	foreach my $data ( @env_data ) {
		my $id = shift @$data;
		my $block = '';
		foreach my $point ( @$data ) {
			$details -> {'record'} = $point;
			$block .= &_make_block( $details );
		}
		my $block_len = length( $block );
		$output .= pack( $len_pack, $block_len );
		$output .= pack( $len_pack, $id );
		$output .= pack( $len_pack, scalar( @$data ) ); # number of fades
		$output .= pack( $len_pack, 0 ); # number of pans
		$output .= $block;

	}
	return $output;
}

sub _add_wavlist_block {
	my $self = shift;
	my $details = shift;
	my @records = @{ $details -> {'record'} };
	my @blocks;
	foreach my $record ( @records ) {
		$details -> {'record'} = $record;
		my $block = &_make_block( $details );
		$block = substr( $block, 8 );
		$block = 'wav ' . pack( $self -> {'len_pack'}, length( $block ) ) . $block;
		push @blocks, $block;
	}
	return join( '', @blocks );
}

sub _multi_add_block {
	my $self = shift;
	my $details = shift;

	my @records = @{ $details -> {'record'} };

	my @blocks;
	foreach my $record ( @records ) {
		$details -> {'record'} = $record;
		push @blocks, &_make_block( $details );
	}
	my $main_block = join '', @blocks;
	my $output = '';
	$output .= pack( $self -> {'len_pack'}, scalar( @blocks ) ) unless $self -> {'settings'} -> is_while( $details -> {'type'} );
	$output .= $main_block;
	return $output;
}

sub _make_block {
	my $details = shift;


	my $type = $details -> {'type'};
	my $settings = $details -> {'pack'};
	my $record = $details -> {'record'};

	if ( $type eq 'cues' ) {
#		my %key_ids = map { $settings -> [$_] -> [0] => $_ } ( 0 .. $#$settings );
		foreach my $key ( qw( name desc ) ) {
			my $len = length( $record -> {$key} );
			$len ++;
			$record -> { $key . '_len' } = $len;
#			$settings -> [ $key_ids{$key} ] -> [1] = 'z' . $len;
		}
	}


	my $block = '';
	foreach my $row ( @$settings ) {
		my( $key, $pack ) = @$row;
		my $val;
		if ( exists $record -> {$key} ) {
			$val = $record -> {$key};
		} else {
			if ( $pack && $pack !~ /^z/i ) {
				$val = 0;
			} else {
				$val = '';
			}
		}
		if ( $pack =~ /^(z)(\d*)/i ) {
			my $match = $1;
			my $len = $2;
			if ( $len ) {
				$len -- if $match eq 'z';
				$val = sprintf( '%' .$len . 's', $val );
			}
			$val .= "\0" if $match eq 'z';
		} elsif ( $pack ) {
			$val = pack( $pack, $val );
		}
		$block .= $val;
	}
	return $block;
}

1;


