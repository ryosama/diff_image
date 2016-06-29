# Diff Image
----------------------
Perl script to compare two images

![Image 1](gfx/Image1.png?raw=true "Image 1")

![Image 2](gfx/Image5_max_compression.jpg?raw=true "Image 2")

![Difference painted over](gfx/over_image.png?raw=true "Difference painted over")

![Difference image](gfx/diff_image.png?raw=true "Difference image")

![Difference zone](gfx/diff_zone.png?raw=true "Difference zone")

# Usage
-------
Options :

`--1=filename`
	First image (require)

`--2=filename`
	Second image (require)

`--sensitivity=x`
	Pourcentage of sensitivity of comparaison (50 is default)

`--quiet` or `-q`
	Don't print anything

`--help` or `-h`
	Display this message

# Examples
----------
`perl diff_image.pl --1=Image1.png --2=Image2.png --sensitivity=12`