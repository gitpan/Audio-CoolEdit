package Audio::CoolEdit::Read;

use strict;
use FileHandle;
use Audio::CoolEdit::Read::Unpack;

=head1 NAME

Audio::CoolEdit::Read - Methods for reading
Syntrillium CoolEdit Pro .ses files.

=head1 SYNOPSIS

	use Audio::CoolEdit;

	my $cool = new Audio::CoolEdit;

	my $read = $cool -> read( './testfile.ses' );

=head1 NOTES

This module shouldn't be used directly, a blessed object can be returned from L<Audio::CoolEdit>.

=head1 AUTHOR

Nick Peskett - nick@soup.demon.co.uk

=head1 SEE ALSO

	L<Audio::CoolEdit>

	L<Audio::CoolEdit::Write>

=head1 METHODS

=cut

sub new {
	my $class = shift;
	my( $in_file, $settings ) = @_;

	$in_file .= '.ses';
	my $handle = new FileHandle join( '', '<', $in_file );
	unless ( defined $handle ) {
		my $error = $!;
		chomp( $error );
		die "unable to open file '$in_file' ($error)"
	}
	binmode $handle;
	print "opening cooledit file '$in_file'\n";


	my $self =	{
				'settings'	=> $settings,
				'len_pack'	=> $settings -> get_len_pack(),
				'unpack'	=> Audio::CoolEdit::Read::Unpack -> new( $settings ),
				'data'		=> '',
				'handle'	=> $handle,
				'in_file'	=> $in_file,
				'pos'		=> 0,
				'dump'		=> {},
			};
	bless $self, $class;
	$self -> _read();
	return $self;
}

=head2 dump

The only method, returns a complex reference to a hash with all sorts of stuff in it. :-)

	print Data::Dumper->Dump([ $cool -> dump() ]);

=cut

sub dump {
	my $self = shift;
	return $self -> {'dump'};
}

sub _read {
	my $self = shift;
	my $ident = $self -> _read_raw( 8 );
	my $total_len = $self -> _read_long();
	my $settings = $self -> {'settings'};
	my $unpack = $self -> {'unpack'};
	my $handle = $self -> {'handle'};
	my $dump = $self -> {'dump'};
	while ( $self -> {'pos'} < $total_len ) {
		my $type = $self -> _read_raw( 4 );
		$type .= $self -> _read_raw( 4 ) if $type eq 'LIST';
		my $type_len = $self -> _read_long();
		my $header = $settings -> is_valid_header( $type );
		unless ( defined $header ) {
			print "unknown block '$type'\n";
			seek( $handle, $type_len, 1 ) || die "unable to seek";
			$self -> {'pos'} += $type_len;
			next;
		}
#		my $got =
#		die "read was too small ($got against $type_len)" unless $got == $type_len;
		my $data = $self -> _read_raw( $type_len );
		my $record = $unpack -> block( $header, $data, $type_len );
		$dump -> { $header } = $record;
	}
}

sub _read_long {
	my $self = shift;
	my $pack = $self -> {'len_pack'};
	my $data = $self -> _read_raw( 4 );
	my( $output ) = unpack( $pack, $data );
	return $output;
}

sub _read_raw {
	my $self = shift;
	my $len = shift;
	my $data;
	$self -> {'pos'} += read( $self -> {'handle'}, $data, $len );
	return $data;
}


1;
