package Audio::CoolEdit::Read::Unpack;

use strict;

sub new {
	my $class = shift;
	my $settings = shift;
	my $long = $settings -> get_len_pack();
	my $self =	{
				'settings'	=> $settings,
				'long'		=> $long,
				'long_len'	=> $settings -> len_formats( $long ),
			};
	bless $self, $class;
	return $self;
}

sub block {
	my $self = shift;
	my $header = shift;
	my $data = shift;
	my $data_len = shift;

	my $pos = 0;
	my @pack;
	my $fields = [];
	my $pack = [];
	my $settings = $self -> {'settings'};

	my $format = ( $settings -> get_format( $header ) )[1];
	foreach my $record ( @$format ) {
		my( $key, $val ) = @$record;
		push @$fields, $key;
		push @$pack, $val;
	}

	my $pack_stuff =	{
				'header'	=> $header,
				'data'		=> \$data,
				'pos'		=> \$pos,
				'data_len'	=> $data_len,
				'pack'		=> $pack,
				'fields'	=> $fields,
				'settings'	=> $settings,
				'long'		=> $self -> {'long'},
				'long_len'	=> $self -> {'long_len'},
				};

	my $output = {};
	if ( $header eq 'envelope' ) {
		$output = &_unpack_envelope( $pack_stuff );
	} elsif ( $settings -> is_while( $header ) ) {
		$output = &_unpack_while( $pack_stuff );
	} elsif ( $settings -> is_multi( $header ) ) {
		$output = &_unpack_multi( $pack_stuff, $settings -> is_multi( $header ) );
	} else {
		$output -> {1} = &_unpack_single( $pack_stuff );
	}

	$output -> {'extra'} = substr( $data, $pos ) if $pos < $data_len;
	return $output;
}

sub _unpack_envelope {
	my $details = shift;

	my $long = $details -> {'long'};
	my $long_len = $details -> {'long_len'};
	my $pack = $details -> {'pack'};
	my $fields = $details -> {'fields'};
	my $data = $details -> {'data'};
	my $pos = $details -> {'pos'};

	my $block_count = unpack( $long, substr( $$data, $$pos, $long_len ) );
	$$pos += $long_len;
	my $output = {};

#	print "data = ", $$data, "\n";
#	print "count = $block_count\n";

	for ( 1 .. $block_count ) {
		my %header;
#		print "header:";
		foreach my $type ( qw( block_size wav_id volume_points pan_points ) ) {
			$header{$type} = unpack( $long, substr( $$data, $$pos, $long_len ) );
#			print " $type = $header{$type}";
			$$pos += $long_len;
		}
#		print "\n";

		my $total_points = $header{'volume_points'} + $header{'pan_points'};
		my $record = {};
		my $point_type = 'volume';
		foreach my $id_cnt ( 1 .. $total_points ) {
			$point_type = 'pan' if $id_cnt > $header{'volume_points'};
			push @{ $record -> {$point_type} }, &_unpack_single( $details );
		}
		$output -> { $header{'wav_id'} } = $record;
	}
	return $output;
}

sub _unpack_single {
	my $details = shift;
	my $pack = $details -> {'pack'};
	my $fields = $details -> {'fields'};
	my @values;
	my $output = [];
	for my $id ( 0 .. $#$pack ) {
		push @$output, $fields -> [$id], &_unpack( $pack -> [$id], $details );
	}
	return $output;
}

sub _unpack_multi {
	my $details = shift;
	my $type = shift;

	my $header = $details -> {'header'};
	my $long = $details -> {'long'};
	my $long_len = $details -> {'long_len'};
	my $pack = $details -> {'pack'};
	my $fields = $details -> {'fields'};
	my $data = $details -> {'data'};
	my $pos = $details -> {'pos'};

	my $cnt = unpack( $long, substr( $$data, $$pos, $long_len ) );
	$$pos += $long_len;

	my %field_ids = map { $fields -> [$_] => $_ } ( 0 .. $#$fields );

	my $output = {};
	for my $cnt_id ( 1 .. $cnt ) {
		my @row;
		for my $id ( 0 .. $#$pack ) {
			my $field = $fields -> [$id];
			my $value = &_unpack( $pack -> [$id], $details );
			push @row, $field, $value;
			next unless $header eq 'cues';
			next unless $field =~ s/_len$//;
			$pack -> [ $field_ids{$field} ] = 'z' . $value;
		}
		$output -> {$cnt_id} = \@row;
	}
	return $output;
}

sub _unpack_while {
	my $details = shift;

	my $pack = $details -> {'pack'};
	my $fields = $details -> {'fields'};
	my $data = $details -> {'data'};
	my $data_len = $details -> {'data_len'};
	my $pos = $details -> {'pos'};

	my $output = {};
	my $cnt_id = 1;
	while ( $$pos < $data_len ) {
		my @row;
		for my $id ( 0 .. $#$pack ) {
			push @row, $fields -> [$id], &_unpack( $pack -> [$id], $details );
		}
		$output -> {$cnt_id} = \@row;
		$cnt_id ++;
	}
	return $output;

}

sub _unpack {
	my $unpack = shift;
	my $details = shift;
	my $data = $details -> {'data'};
	my $pos = $details -> {'pos'};
	my $data_len = $details -> {'data_len'};
	my $settings = $details -> {'settings'};
	my $output;
	if ( $unpack =~ /^z(\d*)/i ) {
		my $len = $1;
		my $str = '';
		if ( $len ) {
			$str = substr( $$data, $$pos, $len );
			$$pos += $len;
		} else {
			while ( $$pos <= $data_len ) {
				my $char = substr( $$data, $$pos, 1 );
				$$pos ++;
				last if $char eq "\0";
				$str .= $char;
			}
		}
		$output = $str;
	} else {
		my $len = $settings -> len_formats( $unpack );
		$output = unpack( $unpack, substr( $$data, $$pos, $len ) );
		$$pos += $len;
	}
	return $output;
}

1;
