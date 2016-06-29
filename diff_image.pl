#!/usr/bin/perl

use strict;
use GD;
use Getopt::Long ;
use List::Util qw(min max);

my %options = ();
GetOptions (\%options,'1=s','2=s', 'sensitivity=i', 'help|h', 'quiet|q') or die ;
print_help() if exists $options{'help'} ; # display a mesasge with available options

# default sensitivity
$options{'sensitivity'} ||= 50 ;

# to output 24bits png
GD::Image->trueColor(1);

# check arguments
die "Missing --1=filename option" if !exists $options{'1'};
die "Missing --2=filename option" if !exists $options{'2'};

# check if image exists
die "Image $options{1} not found" if !-e $options{'1'};
die "Image $options{2} not found" if !-e $options{'2'};

# open images
my $i1 = myGDimageOpen($options{'1'});
my $i2 = myGDimageOpen($options{'2'});

# compare dimension
die sprintf("Images are not the same size (%dx%dpx and %dx%dpx)", $i1->width, $i1->height, $i2->width, $i2->height) if $i1->width != $i2->width || $i1->height != $i2->height ;

# clone image1 to print diff over it
my $overi = $i1->clone();
$overi->copyMergeGray($i1, 0, 0, 0, 0, $i1->width, $i1->height, 0);

# clone with only the difference
my $diffi = new GD::Image($i1->width, $i1->height);
$diffi->alphaBlending(0);
$diffi->saveAlpha(1);
$diffi->filledRectangle(0, 0, $i1->width, $i1->height, $i1->colorAllocateAlpha(255, 255, 255, 127));

# difference will be in green
my $green = $i1->colorAllocate(0,255,0);

# increment this counter when encountering a pixel diff
my $different_pixels = 0;

# draw a rectangle of difference
my %rect_points = ('x1'=>0,'y1'=>0,'x2'=>0,'y2'=>0);

# loop x and y pixel
for (my $x = 0; $x < $i1->width; $x++) {
	for (my $y = 0; $y < $i1->height; $y++) {
		
		# get color at current pixel
		my 	$index2 = $i2->getPixel($x, $y);
		my 	@rgb1   = $i1->rgb( $i1->getPixel($x, $y) );		
		my 	@rgb2   = $i2->rgb( $index2 );
		
		my $found_diff = 0;

		# check 3 primitive color (r, g, b)
		for(my $i=0 ; $i<3 ; $i++) {
			$found_diff = 1 if (abs($rgb1[$i] - $rgb2[$i]) * 100 / 255 > $options{'sensitivity'});
		}
		
		if ($found_diff) { # different pixel
			if ($different_pixels++ == 0) { # first diff
				$rect_points{'x1'} = $x;
				$rect_points{'y1'} = $y;
			}

			$rect_points{'x1'} = min($x, $rect_points{'x1'});
			$rect_points{'y1'} = min($y, $rect_points{'y1'});
			$rect_points{'x2'} = max($x, $rect_points{'x2'});
			$rect_points{'y2'} = max($y, $rect_points{'y2'});

			# draw image2 over image diff
			$overi->setPixel($x,$y, $index2 );

			# draw only diffirence
			$diffi->setPixel($x,$y, $index2 );
		}
	}
}


if (!$different_pixels) {
	print "Images are the same" unless $options{'quiet'};

} else {
	#create over image
	savePng($overi, 'over_image.png');

	#create diff image
	savePng($diffi, 'diff_image.png');

	#create PSD diff image
	savePsd($options{'1'}, $options{'2'}, 'diff_image.png', 'diff_image.psd');

	#create image2 diff image
	my $zonei = $i2->clone();
	$zonei->rectangle($rect_points{'x1'},$rect_points{'y1'},$rect_points{'x2'},$rect_points{'y2'}, $green);
	savePng($zonei, 'diff_zone.png');
	
	my $total_pixel = $i1->width * $i1->height;
	printf("%d/%d different pixels [%0.2f%%]", $different_pixels, $total_pixel, 100*$different_pixels/$total_pixel ) unless $options{'quiet'};
}

##################################################################################################################

# own newFrom because some times, GD don't reconize jpeg file
sub myGDimageOpen($) {
	my ($filename) = shift;
	my $gd_obj;
	if    ($filename =~ /\.jpe?g$/i) { $gd_obj = GD::Image->newFromJpeg($filename) or die "Unable to read JPEG image '$filename'"; }
	elsif ($filename =~ /\.gif$/i)   { $gd_obj = GD::Image->newFromGif($filename)  or die "Unable to read GIF image '$filename'"; }
	elsif ($filename =~ /\.png$/i)   { $gd_obj = GD::Image->newFromPng($filename)  or die "Unable to read PNG image '$filename'"; }
	elsif ($filename =~ /\.xbm$/i)   { $gd_obj = GD::Image->newFromXbm($filename)  or die "Unable to read XBM image '$filename'"; }

	return $gd_obj;
}


# save GD Obj into a jpeg file
sub savePng($$) {
	my ($gd_obj,$filename) = @_;
	
	$filename .= '.png' if $filename !~ /\.png$/i; # add .png if needed
	open (OUTPUT,"+>$filename") or die "Unable to save PNG $filename ($!)";
	binmode OUTPUT;
	print OUTPUT $gd_obj->png(0);
	close OUTPUT;
}

sub savePsd($$$) {
	my ($layer1, $layer2, $layer_diff, $filename) = @_;

	my $imageMagick_is_installed = 0;
	my $output = '';

	# check OS
	if ($^O =~ /^linux$/i) {
		$output = join('',`which convert`);

	} elsif ($^O =~ /^MSWin32$/i) {
		$output = join('',`where convert`);

	} else {
		print "Can't create PSD file on this OS $^O" unless $options{'quiet'};
	}

	# check if ImageMagick is installed (to create PSD)
	$imageMagick_is_installed = 1 if ($output =~ /ImageMagick/i && $output =~ /convert/) ;

	if ($imageMagick_is_installed) {
		# create PSD layered file
		`convert ( -page +0+0 -label "difference" "$layer_diff"[0] -background none -mosaic -set colorspace RGB ) ( -page +0+0 -label "$layer2" "$layer2"[0] -background none -mosaic -set colorspace RGB ) ( -page +0+0 -label "$layer1" "$layer1"[0] -background none -mosaic -set colorspace RGB ) ( -clone 0--1 -background none -mosaic ) -alpha On -reverse "$filename"`;
	} else {
		print "Can't create PSD file, ImageMagick is not installed on your system"  unless $options{'quiet'};
	}
}


# display the documentation
sub print_help {
	print <<EOT ;
--1=filename			Image file one
--2=filename			Image file tow
--sensitivity=x 		Pourcentage of sensitivity of comparaison (50 is default)
--quiet -q 				Don't print anything
--help -h				Display this message

EOT
	exit;
}