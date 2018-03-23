#!/usr/bin/perl
#
use strict;
use warnings;
use Ascii;
use String::ShellQuote;

use Getopt::Long;

my %options = ();

sub getUsage {
    print "usage: $0 <file> [<options>]\n";
    exit;
}

GetOptions(\%options,
    'size=i',
    'file=s',
    'text=s',
    'edge=i',
    'overlayColor=s',
    'edgeOnly',
    'backgroundcolor|bg'
) or getUsage();

my $inputFile = shift;
my $outputFile = shift;

my $size = (defined($options{'size'}) ? $options{'size'} : 60);

if (! $inputFile) { getUsage(); }

if (!$outputFile){
	print "usage: <input file> <output file>\n";
	exit;
}

my $fps = 24;
my $dir = '/tmp/.asciimovie' . rand(10000000) . '/';

mkdir $dir;

#my $cmd = sprintf('avconv -i %s -r %s -f image2 %s%s.jpg &', shell_quote($inputFile), $fps, $dir,  '%0d');
my $cmd = sprintf('ffmpeg -i %s -r %s -f image2 %s%s.jpg &', shell_quote($inputFile), $fps, $dir,  '%0d');

print "$cmd\n";
system $cmd;
sleep 5;

my $continue = 1;
my $count = 1;
while ($continue == 1){
	my $file = $dir . $count . ".jpg";
	if (! -e $file){ exit;}
	print "$file\n";
	my $image = Ascii::getImage($file, $size, {});
	if ($count == 1){
		open my $fh, ">", $outputFile or die "Failed to open $outputFile\n";
		print $fh $image->{base}->{'width'} . "\n";
		print $fh "$fps\n";
		close $fh;
		
	}
    if ($options{'edge'}){
        $image = Ascii::edgeFilter($image, $options{'edge'});
    }
	Ascii::printImage($image, 
        { 
            'filter' => $options{'edgeOnly'},
            'outfile' => $outputFile,
            'backgroundColor' => $options{'backgroundcolor'},
            'append' => 1
        } );
	unlink $file;
	$count++;
}
