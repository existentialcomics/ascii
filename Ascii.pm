#!/usr/bin/perl
#
#
package Ascii;
use GD;
use strict;
use List::Util qw( reduce max);
use Time::HiRes qw(usleep);
#use Term::ANSIColor;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
use Data::Dumper;
use Math::SimpleHisto::XS;
use Image::Magick;

my @master_ascii;
#my @master_ascii = (qw(W M 0 @ N & ), ',', qw(' - . `), ' ');
push @master_ascii, " ";
push @master_ascii, reverse qw(@ 8 & * = + , .);
my $aspectRatio = .6;

my $defaultFilterThreshold = .2;

#my %colors = (
#		'white'    => '120,120,120',
#		'blue'     => '0,0,255',
#		'yellow'   => '255,225,30',
#		'green'    => '0,255,0',
#		'magenta'  => '255,0,255',
#		'cyan'     => '0,255,255',
#		'red'      => '265,0,0',
#		'white'    => '255,255,255'
#		);
my %colors = (
		'white'    => [0.5, 0.5, 0.5],
		'green'    => [0.0, 1.0, 0.0],
		'blue'     => [0.0, 0.0, 1.0],
		'yellow'   => [1.0, 1.0, 0.0],
		'magenta'  => [1.0, 0.0, 1.0],
		'cyan'     => [0.0, 1.0, 1.0],
		'red'      => [1.0, 0.0, 0.0],
		#'white'    => [1.0, 1.0, 1.0],
		);
#my %colors = (
#		#'white'    => [0.5, 0.5, 0.5],
#		'white'    => [1.0, 1.0, 1.0],
#		'blue'     => [0.0, 1.0, 0.0],
#		'red'      => [1.0, 0.0, 0.0],
#		);
#
#%colors = (
#	'red'      => '255,0,0',
#	'blue',    => '0,255,0',
#	'white'    => '0,0,0',
#);

sub _autoContrast {
	my $gdimg = shift;
	my $hist = Math::SimpleHisto::XS->new(
		min => 0, max => 256, nbins => $#master_ascii,
	);

	my ($w, $h) = $gdimg->getBounds();
	for my $x (0 .. $w){
		for my $y (0 .. $h){
			my $index = $gdimg->getPixel($x, $y);
			my ($r,$g,$b) = $gdimg->rgb($index);
			$hist->fill(($r+$g+$b) / 3);
		}
	}
	my $centers = $hist->bin_centers();
	foreach my $i (@$centers){
		print "$i\n";
	}
	
	print "mean: " . $hist->mean() . "\n";
	print "median: " . $hist->median() . "\n";
	print "bin for 128: " . $hist->find_bin(128) . "\n";
	$hist->normalize(0.5);
	print "------------------\n";
	print "mean: " . $hist->mean() . "\n";
	print "median: " . $hist->median() . "\n";
	print "bin for 128: " . $hist->find_bin(128) . "\n";
	print "\n";
}

sub getImage_magick {
	my ($file, $width, $options) = @_;
	my %image = (
		base  => {},
		color => {},
	);
	my $img = new Image::Magick;
	$img->read($file);
	my $h = $img->[0]->Get('Height');
	my $w = $img->[0]->Get('Width');
	my $height = ($h * ($width / $w)) * $aspectRatio;
	$img->[0]->Scale("width" => $width, "height" => $height);
	$h = $img->[0]->Get('Height');
	$w = $img->[0]->Get('Width');

	$image{'base'}->{'width'} = $h;
	$image{'base'}->{'height'} = $w;

	$img->Equalize('channel' => 'all');
	my @pixels = $img->GetPixels(map=>'IRGB', height=>$height, width=>$width, normalize=>1);
	for my $row (1 .. $h){
		for my $col (1 .. $w){
			my $pixel = shift(@pixels);
			my $r     = shift(@pixels);
			my $g     = shift(@pixels);
			my $b     = shift(@pixels);
			$image{'base'}->{'img'}->{$row}->{$col} = $pixel;
			$image{'color'}->{'img'}->{$row}->{$col} = _closestColor($r, $g, $b);
		}
	}
	return \%image;
}

sub overlayColor {
	my ($file, $image, $width, $options) = @_;
	my $colorImg = getImage($file, $width, $options);
	$image->{'color'} = $colorImg->{'color'};
	return $image;
}

sub getImage {
	my ($file, $width, $options) = @_;
	return getImage_magick($file, $width, $options);
	my %image = (
		base  => {},
		color => {},
	);

	if (!defined($options)){ $options = {}; }
	my $gdimg = GD::Image->newFromJpeg($file)  or die "failed to open $file";
	my ($w, $h) = $gdimg->getBounds();

	$options->{'brightness'} = 30;
	$options->{'contrast'} = 40;
	$options->{'autocontrast'} = 5;

	if ($options->{'autocontrast'}){
		my ($b, $c) = _autoContrast($gdimg, $options->{'autocontrast'});
		exit;
	}


	my $pixelWidth = $w / $width;
	my $pixelHeight = $pixelWidth * $aspectRatio;

	my $rows = int($h / $pixelWidth);
	my $cols = int($w / $pixelHeight);

	$image{'base'}->{'width'} = $rows;
	$image{'base'}->{'height'} = $cols;

	foreach my $row (1 .. $rows){
		foreach my $col (1 .. $cols){
			my $xStart = $col * $pixelHeight;
			my $yStart = $row * $pixelWidth;
			my $averageRed   = 0;
			my $averageBlue  = 0;
			my $averageGreen = 0;
			my $pixels = 0;
			for my $x ($xStart .. $xStart + int($pixelWidth)){
				for my $y ($yStart .. $yStart + int($pixelHeight)){
					my $index = $gdimg->getPixel($x, $y);
					my ($r,$g,$b) = $gdimg->rgb($index);
					### adjust for brightness and contrast
					$r = _trPix($r + $options->{'brightness'});
					$g = _trPix($g + $options->{'brightness'});
					$b = _trPix($b + $options->{'brightness'});

					# contrast
					my $factor = (259 * ($options->{'contrast'} + 255)) / (255 * (259 - $options->{'contrast'}));
					$r = _trPix($factor * ($r - 128) + 128);
					$g = _trPix($factor * ($g - 128) + 128);
					$b = _trPix($factor * ($b - 128) + 128);

					$averageRed   += $r;
					$averageBlue  += $b;
					$averageGreen += $g;
					$pixels++;
				}
			}

			$averageRed   = int $averageRed / $pixels;
			$averageBlue  = int $averageBlue / $pixels;
			$averageGreen = int $averageGreen / $pixels;
#print "$averageRed, $averageBlue, $averageGreen\n";

			my $closestColor = 'white';
			my $smallestDiff = 1000;
			foreach my $color (keys %colors){
				my ($r, $g, $b) = split ",", $colors{$color};
				my $diff = abs($r - $averageRed) + abs($b - $averageBlue) + abs($g - $averageGreen);
				if ($diff < $smallestDiff){
					$closestColor = $color;
					$smallestDiff = $diff;
				}
			}

			my $averageBrightness = _trPix( ($averageRed + $averageBlue + $averageGreen) / 3 );
			$image{'base'}->{'img'}->{$row}->{$col} = $averageBrightness;
			$image{'color'}->{'img'}->{$row}->{$col} = $closestColor;
#print color("$closestColor");
#print $master_ascii[$idx];
		}
	}
	return \%image;
}

# force a pixel to be in range
sub _trPix {
	my $pix = shift;
	if ($pix < 0){ return 0;}
	if ($pix > 255){ return 255; }
	return $pix;
}

sub edgeFilter {
	my $image = shift;
	my $filterThreshold = shift;
	if (!defined($filterThreshold)){ $filterThreshold = $defaultFilterThreshold; }
	foreach my $w (1 .. $image->{'base'}->{'width'}){
		foreach my $h (1 .. $image->{'base'}->{'height'}){
			my @nine = (
				[ $image->{'base'}->{'img'}->{$w - 1}->{$h - 1}, $image->{'base'}->{'img'}->{$w - 0}->{$h - 1},$image->{'base'}->{'img'}->{$w + 1}->{$h - 1} ],
				[ $image->{'base'}->{'img'}->{$w - 1}->{$h - 0}, $image->{'base'}->{'img'}->{$w - 0}->{$h - 0},$image->{'base'}->{'img'}->{$w + 1}->{$h - 0} ],
				[ $image->{'base'}->{'img'}->{$w - 1}->{$h + 1}, $image->{'base'}->{'img'}->{$w - 0}->{$h + 1},$image->{'base'}->{'img'}->{$w + 1}->{$h + 1} ]
			);
			my %edgeValues = ();
			$edgeValues{_compareEastWest(\@nine)} = "|";
			$edgeValues{_compareNorthSouth(\@nine)} = "_";
			$edgeValues{_compareNWSE(\@nine)} = "/";
			$edgeValues{_compareNESW(\@nine)} = "\\";

			my $highest = max keys %edgeValues;
			if ($highest > $filterThreshold){
				$image->{'edge'}->{'img'}->{$w}->{$h} = $edgeValues{$highest};
			}
		}
	}
	return $image;
}


sub _closestColor {
	my ($averageRed, $averageGreen, $averageBlue) = @_;
	return sprintf('RGB%.0f%.0f%.0f', $averageRed * 5, $averageGreen * 5, $averageBlue * 5);
	my $closestColor = 'white';
	my $smallestDiff = 1000;
	foreach my $color (keys %colors){
		my ($r, $g, $b) = @{ $colors{$color} };
		my $diff = abs($r - $averageRed) + abs($b - $averageBlue) + abs($g - $averageGreen);
		if ($diff < $smallestDiff){
			$closestColor = $color;
			$smallestDiff = $diff;
		}
	}
	return $closestColor;
}

sub _compareEastWest {
	my $nine = shift;
	my $west = 0;	
	my $east = 0;
	$west += $nine->[0]->[0];
	$west += $nine->[0]->[1];
	$west += $nine->[0]->[2];

	$east += $nine->[2]->[0];
	$east += $nine->[2]->[1];
	$east += $nine->[2]->[2];
	return abs($east - $west);
}

sub _compareNorthSouth {
	my $nine = shift;

	my $north = 0;	
	my $south = 0;
	$north += $nine->[0]->[0];
	$north += $nine->[1]->[0];
	$north += $nine->[2]->[0];

	$south += $nine->[0]->[2];
	$south += $nine->[1]->[2];
	$south += $nine->[2]->[2];
	return abs($south - $north);
}

sub _compareNWSE {
	my $nine = shift;

	my $nw = 0;	
	my $se = 0;
	$nw += $nine->[0]->[0];
	$nw += $nine->[0]->[1];
	$nw += $nine->[1]->[0];

	$se += $nine->[1]->[2];
	$se += $nine->[2]->[1];
	$se += $nine->[2]->[2];
	return abs($se - $nw);
}

sub _compareNESW {
	my $nine = shift;

	my $ne = 0;	
	my $sw = 0;
	$ne += $nine->[0]->[2];
	$ne += $nine->[0]->[1];
	$ne += $nine->[1]->[2];

	$sw += $nine->[2]->[0];
	$sw += $nine->[1]->[0];
	$sw += $nine->[2]->[1];
	return abs($sw - $ne);
}

sub printImage {
	my $image = shift;
	my $options = shift;
	my $out;
	if (defined($options->{'outfile'})){
		open $out, ">>", $options->{'outfile'};
	} else {
		$out = *STDOUT;	
	}
	foreach my $w (1 .. $image->{'base'}->{'width'}){
		foreach my $h (1 .. $image->{'base'}->{'height'}){
			print $out color($image->{'color'}->{'img'}->{$w}->{$h});
			if (defined($options->{'overlay'}->{'img'}->{$w}->{$h})){
			print $out color('white');
			    print $options->{'overlay'}->{'img'}->{$w}->{$h};
			} elsif (defined($image->{'edge'}->{'img'}->{$w}->{$h})){
				print $out $image->{'edge'}->{'img'}->{$w}->{$h};
			} else {
				if ( defined($options->{filter}) ){ 
					print $out " ";
				} else {
					my $char = $#master_ascii * $image->{'base'}->{'img'}->{$w}->{$h};
					if ($char < 0){ $char = 0; }
					if ($char > $#master_ascii){ $char = $#master_ascii; }
					print $out $master_ascii[$char];
				}
			}
		}
		print $out color('reset');
		print $out "\n";
	}
}

1;
