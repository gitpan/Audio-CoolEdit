$| = 1;

my $out_dir = 'test_output';

unless ( -d $out_dir ) {
	mkdir( $out_dir, 0777 ) ||
		die "unable to make test output directory '$out_dir' - ($!)";
}

my %mods	= (
		  'cooledit'	=> 'Audio::CoolEdit',
		  'tools'	=> 'Audio::Tools',
		  'byteorder'	=> 'Audio::Tools::ByteOrder',
		  'fades'	=> 'Audio::Tools::Fades',
		  'time'	=> 'Audio::Tools::Time',
		  'wav'		=> 'Audio::Wav',
		  );

my %present;
foreach my $type ( keys %mods ) {
	$present{$type} = eval "require $mods{$type}";
}

die "You need $mods{'wav'} for testing (sorry)\n" unless $present{'wav'};

require 'makewavs.pl';
&build( $out_dir );

my $tests = 6;

print "1..$tests\n";

my $cnt;
foreach $type ( qw( cooledit tools byteorder fades ) ) {
	$cnt ++;
	unless ( $present{$type} ) {
		print "not ok $cnt, unable to load $mods{$type}\n";
		die;
	} else {
		print "ok $cnt, $mods{$type} loadable\n";
	}
}

my $cool = new Audio::CoolEdit;

my $test_out = "$out_dir/test";
my $fade_type = 'trig';
my $fade_length = 1;

my $details =	{
		'bits_sample'	=> 16,
		'sample_rate'	=> 44100,
		};

my $time = Audio::Tools::Time -> new( map( $details -> {$_}, qw( sample_rate bits_sample ) ), 2 );
$fade_length = $time -> seconds_to_bytes( $fade_length );

my $fades = new Audio::Tools::Fades;
my $fade_sub = $fades -> fade( $fade_length, 0, $fade_type );

my $write = $cool -> write( $test_out, $details );
my $record =	{
			'file'		=> "$out_dir/1.wav",
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

my $record2 =	{
			'file'		=> "$out_dir/2.wav",
			'title'		=> "song 2",
		};

$write -> add_file( $record2 );
$write -> finish();

$cnt ++;
print "ok $cnt\n";

my $read = $cool -> read( $test_out );

my $coolfile = $read -> dump();

foreach my $key ( keys %$coolfile ) {
	print "\t$key -> ", scalar( keys %{ $coolfile -> {$key} } ), " blocks\n";
}

$cnt ++;
print "ok $cnt\n";

print "please check the file '", $write -> file_name(), "'\n";

