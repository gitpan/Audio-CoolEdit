package Audio::CoolEdit;

use strict;

use Audio::CoolEdit::Settings;
use vars qw( $VERSION );
$VERSION = '0.01';

=head1 NAME

Audio::CoolEdit - Modules for reading & writing
Syntrillium CoolEdit Pro .ses files.

=head1 SYNOPSIS

	use Audio::CoolEdit;

	my $cool = new Audio::CoolEdit;

	my $test_out = './test';

	my $details =	{
			'bits_sample'	=> 16,
			'sample_rate'	=> 44100,
			};

	my $write = $cool -> write( $test_out, $details );

	$write -> add_file(	{
				'file'		=> './t/testout.wav',
				'title'		=> "song 1",
				} );

	$write -> add_file(	{
				'file'		=> './t/testout.wav',
				'title'		=> "song 2",
				} );

	$write -> finish();

	my $read = $cool -> read( $test_out );

	print Data::Dumper->Dump([ $read -> dump() ]);

=head1 DESCRIPTION

Syntrillium's CoolEdit Pro (http://www.syntrillium.com) is a MSWin32 based multitrack capable
sound editor.
This module reads/ writes the .ses (session) file format enabling you to place audio files
in a vitual track at a given offset.
The write module is a lot more developed than the read module as this has been developed to
be used with Audio::Mix

=head1 NOTES

All sample positions used are in byte offsets
(L<Audio::Tools::Time> for conversion utilities)

=head1 AUTHOR

Nick Peskett - nick@soup.demon.co.uk

=head1 SEE ALSO

	L<Audio::CoolEdit::Read>

	L<Audio::CoolEdit::Write>

	L<Audio::Tools>

	L<Audio::Mix>

=head1 METHODS

=head2 new

Returns a blessed Audio::CoolEdit object.

	my $cool = new Audio::CoolEdit;

=cut

sub new {
	my $class = shift;
	my $self =	{
				'settings'	=> new Audio::CoolEdit::Settings,
			};
	bless $self, $class;
	return $self;
}

=head2 write

Returns a blessed Audio::CoolEdit::Write object.

	my $details =	{
			'bits_sample'	=> 16,
			'sample_rate'	=> 44100,
			};
	my $write = $cool -> write( './test', $details );

See L<Audio::CoolEdit::Write> for methods.

=cut

sub write {
	my $self = shift;
	my( $out_file, $write_details ) = @_;
	require Audio::CoolEdit::Write;
	my $write = Audio::CoolEdit::Write -> new( $out_file, $write_details, $self -> {'settings'} );
	return $write;
}

=head2 read

Returns a blessed Audio::CoolEdit::Read object.

	my $read = $cool -> read( './test.ses' );

See L<Audio::CoolEdit::Read> for methods.

=cut

sub read {
	my $self = shift;
	my $file = shift;
	require Audio::CoolEdit::Read;
	my $read = new Audio::CoolEdit::Read $file, $self -> {'settings'};
	return $read;
}

1;
__END__
