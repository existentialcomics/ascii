#!/usr/bin/perl
#
use strict;
use warnings;
use Ascii;
use String::ShellQuote;

my $movie = shift;
my $out = shift;
my $size = 160;
my $filter = 1.4;
my $print = undef;

if (!$out){
	print "usage: <input file> <output file\n";
	exit;
}

my $fps = 24;
my $dir = '/tmp/.asciimovie' . rand(10000000) . '/';

mkdir $dir;

my $cmd = sprintf('avconv -i %s -r %s -f image2 %s%s.jpg &', shell_quote($movie), $fps, $dir,  '%0d');

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
		open my $fh, ">", $out;
		print $fh $image->{base}->{'width'} . "\n";
		print $fh "$fps\n";
		close $fh;
		
	}
	if ($filter){
		$image = Ascii::edgeFilter($image, $filter);
	}
	Ascii::printImage($image, { 'filter' => $print, 'outfile' => $out } );
	unlink $file;
	$count++;
	#Ascii::printImage($image, { 'filter' => $print } );
}
