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

my $file = shift;
if (! $file) { getUsage(); }

if (! -e $file){ print "File $file not found\n"; exit;}
my $size = (defined($options{'size'}) ? $options{'size'} : 60);
my $image = Ascii::getImage($file, $size, {
});
if ($options{'edge'}){
    $image = Ascii::edgeFilter($image, $options{'edge'});
}
if ($options{overlayColors}){
    $image = Ascii::overlayColor($options{'overlayColors'}, $image, $size, {});
}
Ascii::printImage($image, { 
        'filter' => $options{'edgeOnly'},
        'outfile' => $options{'file'},
        'text' => $options{'text'},
        'backgroundColor' => $options{'backgroundcolor'}
    } );

