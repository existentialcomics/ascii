#!/usr/bin/perl
#
use strict; use warnings;
use Tie::File;
use Fcntl 'O_RDONLY';
require Term::Screen;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
		      clock_gettime clock_getres clock_nanosleep clock time);
use Data::Dumper;

my $starttime = time();

my $file = shift;
my $subtitlesFile = shift;

my @subtitles;
my $hasSubtitles = undef;
if ($subtitlesFile){
	open my $fh, "<", $subtitlesFile;
	while (my $lineNum = <$fh>){
		my $timeRange = <$fh>;
		my $line = <$fh>;
		my $space = <$fh>;
		$timeRange =~ m/(\d\d):(\d\d):(\d\d),(\d+) --> (\d\d):(\d\d):(\d\d),(\d+)/;
		my $startTime = ($1 * 60 * 60) + ($2 * 60) + ($3) + ($4 / 1000);
		my $endTime   = ($5 * 60 * 60) + ($6 * 60) + ($7) + ($8 / 1000);
		my %sub = (
			'line' => $line,
			'start' => $startTime,
			'stop' => $endTime
		);
		push @subtitles, \%sub;
	}
	close $fh;
	$hasSubtitles = 1;
}

open my $fh, "<", $file or die "failed to open $file\n";
my $height = <$fh>;
chomp $height;
my $fps    = <$fh>;
chomp $fps;

my $scr = new Term::Screen;

$scr->clrscr();
$scr->noecho();

my @frames;
tie @frames, 'Tie::File', $file, mode => O_RDONLY, memory => 200_000_000 or die "failed to open";

my $spot = 0;
my $printrow = 0;

# subtitles
my $subSpot = 0;
my $currentLine = "";
my $lastLine = "";

my $playing = 1;
my $frame = 0;
my $frameOffset = 2;
my $timeOffset = 0;

my $framesInSec = 0;
my $lastSec = (time() - $starttime) + $timeOffset;
my $lastFrame = -1;
while ($playing == 1){
	my $time = (time() - $starttime) + $timeOffset;
	$frame = int($time * $fps);
	if ($frame == $lastFrame){ next; }
	$framesInSec++;
	$lastFrame = $frame;
	if (abs($time - $lastSec) > 1){
		$scr->at(0,0);
		$scr->puts(int $time . "      ");
		$scr->at(1,0);
		$scr->puts('fps: ' .$framesInSec . "    ");
		$scr->at(2,0);
		$scr->puts('sub: ' .$subSpot . "    ");
		$lastSec = (time() - $starttime) + $timeOffset;
		$framesInSec = 0;
		$framesInSec++;
	}
	my $offset = ($frame * $height) + $frameOffset;
	my $screenH = 3;
	my $put = "";
	for my $spot ( $offset .. $offset + $height){
		my $row = $frames[$spot];
		$put .= "$row\n\r";
		$scr->at($screenH,0);
		$scr->puts($row);
		$screenH++;
	}

	my $line;
	if ($hasSubtitles){
		if ($time > $subtitles[$subSpot + 1]->{'start'} && $time < $subtitles[$subSpot + 1]->{'stop'}){
			$subSpot++;
			$line = $subtitles[$subSpot]->{'line'};
		} elsif ($time > $subtitles[$subSpot - 1]->{'start'} && $time < $subtitles[$subSpot - 1]->{'stop'}){
			$line = $subtitles[$subSpot - 1]->{'line'};
		} elsif ($time > $subtitles[$subSpot]->{'start'} && $time < $subtitles[$subSpot]->{'stop'}){
			$line = $subtitles[$subSpot + 1]->{'line'};
		} else {
			$scr->at(0, 12);
			$line = " " x 100;
		}
	}
	if ($line){
		if ($line ne $currentLine){
			my $len = length($lastLine);
			$scr->at(0, 12);
			$scr->puts(" " x 100);
			$scr->at(0, 12);
			$scr->puts($line);
			$currentLine = $line;
		}
	}

	if ($scr->key_pressed()) { 
		$lastSec = (time() - $starttime) + $timeOffset;
		my $chr = $scr->getch();
		if ($chr eq 'q'){ $playing = 0}
		if ($chr eq 'kl'){ $timeOffset -= 30 }
		if ($chr eq 'kr'){ $timeOffset += 30}
		if ($chr eq 'a'){ $timeOffset -= 300 }
		if ($chr eq 'd'){ $timeOffset += 300}
		$time = (time() - $starttime) + $timeOffset;
		$subSpot = findSubtitleSpot($time);
	}
}

sub findSubtitleSpot {
	if (!$hasSubtitles){ return 0; }
	my $time = shift;
	foreach (0 .. $#subtitles){
	    if ($time < $subtitles[$_]->{'start'}){
			return $_;
		}
	}
	return -1;
}
