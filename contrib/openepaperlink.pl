#!/usr/bin/perl
use v5.36;
use autodie;

use FindBin;
use lib "$FindBin::Bin/../lib";
use RevBank::Products;

use Imager;
use Imager::Fill;
use Imager::Font::Wrap;
use LWP::Simple qw($ua);
use JSON::XS ();

my $json = JSON::XS->new;
$ua->timeout(2);

my $resources = "$FindBin::Bin/oepl_resources";
my $datadir = $ENV{REVBANK_DATADIR} ||= "$ENV{HOME}/.revbank";
my $outdir = "$datadir/oepl_images";
my $ap = 'http://10.42.42.123';

eval { mkdir $outdir };

sub slurp ($fn) { local (@ARGV) = $fn; local $/ = wantarray ? "\n" : undef; <> }
sub spurt ($fn, @data) { open my $fh, '>', $fn; print $fh @data; }

sub post ($uri, $kv) {
	for (my $i = 0; $i < @$kv; $i += 2) {
		if ($kv->[$i] eq "file") {
			$kv->[$i + 1] = [ $kv->[$i + 1], "filename.jpg", Content_Type => "image/jpeg" ];
			last;
		}
	}

	my $response = $ua->post("$ap/$uri", Content_Type => 'form-data', Content => $kv);
	warn $response->content if not $response->is_success;
	return $response->is_success;
}


sub draw ($product, $hwtype, $force) {
	my $sub = main->can("draw_hwtype_$hwtype") or do {
		warn "Unsupported hwtype ($hwtype)";
		return undef;
	};
	$product->{_fn} = $product->{id} =~ s/([^A-Za-z0-9_])/sprintf("%%%02x", ord $1)/ger;
	my $image = $sub->($product);

	my $fn = "$outdir/$product->{_fn}\_$hwtype.jpg";
	my $old = -e $fn ? slurp($fn) : "";

	$image->write(
		data => \my $new,
		type => "jpeg",
		jpegquality => 100,  # no underscore
		jpeg_optimize => 1,
		jpeg_sample => "1x1",  # 1x1 = 4:4:4
	) or die $image->errstr;

	if ($force or $new ne $old) {
		spurt $fn, $new if $new ne $old;
		return $fn;
	}

	return undef;
}

sub get_dbitem($mac) {
	my $response = $ua->get("$ap/get_db?mac=$mac");
	my $hash = eval { $json->decode($response->content) } || { tags => [] };
	my $tags = $hash->{tags};
	if (@$tags != 1) {
		my $status = $response->status_line;
		warn "Can't get info for $mac (HTTP $status); new tag not ready yet?\n";
		return {};
	}
	return $tags->[0];
}

sub comma($str) {
	"$str" =~ s/\./,/gr =~ s/0/O/gr;
}

sub aztec($product) {
	my $fn = "$outdir/$product->{_fn}_aztec.png";

	if (not -e $fn) {
		system qw(zint --barcode 92 --vers 3 --scale 1 --filetype PNG --nobackground --whitesp 0 --vwhitesp 0), "--data" => $product->{id}, "--output" => $fn;
	}

	return Imager->new->read(file => $fn) if -e $fn;
}

sub _draw_hwtype_3_4 ($product, $xsize, $ysize, $fontsize, $lineheight) {
	# Same design for hwtype 3 and hwtype 4, but on hwtype 4, with larger font.

	my @colors = (
		my $white = Imager::Color->new(255,255,255),
		my $black = Imager::Color->new(0,0,0),
		my $red   = Imager::Color->new(255,0,0),
	);

	my $font = Imager::Font->new(file => "$resources/TerminusTTF-Bold-4.49.3.ttf", aa => 0);

	# Terminus sizes: 12 14 16 18 20 22 24 28 32

	my $is_erase = $product->{id} eq "_ERASE_";
	my $is_promo = $product->{tags}{promo};
	my $fg = $is_promo ? $white : $black;
	my $bg = $is_promo || $is_erase ? $red : $white;

	my $image = Imager->new(xsize => $xsize, ysize => $ysize);
	$image->setcolors(colors => \@colors);
	$image->box(filled => 1, color => $bg);
	return $image if $is_erase;

	my $addon_text;
	my $addon_highlight = 0;

	for my $addon (@{ $product->{addons} }) {
		next if $addon->{tags}{OPAQUE};
		my $d = $addon->{description};
		$addon_text = ($addon->{price} < 0) ? $d : "+ $d";
		$addon_highlight = 1 if $addon->{price} < 0;
		last;
	}

	my $text = $product->{description};

	my (undef, undef, undef, $bottom) = Imager::Font::Wrap->wrap_text(
		image => $image,
		font => $font,
		string => $text,
		color => $fg,
		justify => "center",
		x => 0,
		y => 0,
		size => $fontsize,
		height => ($addon_text ? 3 : 2) * $lineheight,
	);

	$addon_text and Imager::Font::Wrap->wrap_text(
		image => $image,
		font => $font,
		string => $addon_text,
		color => ($addon_highlight ? ($is_promo ? $black : $red) : $fg),
		justify => "center",
		x => 0,
		y => $bottom,
		size => $fontsize,
		height => (3 * $lineheight) - $bottom,
	);

	my $xmargin = 6;
	my $ymargin = 2;
	my $has_discount = $product->{tag_price} < $product->{price};

	my $price = sub {
		return $image->align_string(
			x => $xsize - 1 - $xmargin,
			y => $ysize - 1 - $ymargin,
			valign => 'bottom',
			halign => 'right',
			string => comma($product->{tag_price}),
			utf8 => 1,
			color => ($has_discount ? $white : $white),
			font => $font,
			aa => 0,
			size => 32,
		);
	};

	my @bounds = $price->();


	my @box = ($bounds[0] - $xmargin, $bounds[1] - $ymargin, $bounds[2] + $xmargin, $bounds[3] + $ymargin);
	$image->box(box => \@box, fill => { solid => ($has_discount ? $red : $black) });
	$price->();

	if (my $unit = $product->{tags}{ml} ? "ml" : $product->{tags}{g} ? "g" : undef) {
		my $X = $unit eq "ml" ? "L" : $unit eq "g" ? "kg" : die;
		my $perX = sprintf "%.02f", $product->{tag_price}->float * 1000 / $product->{tags}{$unit};

		@bounds = $image->align_string(
			x => $box[2],
			y => $box[1],
			valign => 'bottom',
			halign => 'right',
			string => comma("$product->{tags}{$unit} $unit $perX/$X"),
			utf8 => 1,
			color => $fg,
			font => $font,
			aa => 0,
			size => 12,
		);
	}

	# There's place for only 1 but looping over all is easier :)
	# Intended purpose is statiegeld logos.
	for my $addon (@{ $product->{addons} }) {
		my $fn = "$resources/$addon->{id}.png";
		-e $fn or next;
		my $statiegeld = Imager->new->read(file => $fn);
		$image->compose(src => $statiegeld, tx => 63, ty => $ysize - 48 - 1);
	}

	if (my $aztec = aztec $product) {
		$image->compose(src => $aztec, tx => 1, ty => $ysize - 46 - 1);
	}

	return $image;
}

sub draw_hwtype_3 ($product) {
	_draw_hwtype_3_4($product, 212, 104, 18, 18);
}

sub draw_hwtype_4 ($product) {
	_draw_hwtype_3_4($product, 296, 152, 28, 30);
}

my @lines = slurp "$datadir/oepl";
my %new_hwtype;

my $products = read_products;
$products->{_NOTFOUND_} = {
	id => "_NOTFOUND_",
	description => "(product unavailable)",
	price => "999.99",
	tag_price => "999.99",
};

my $fix_mode = @ARGV && $ARGV[0] eq 'fix';
shift if $fix_mode;

my $erase_mode = !$fix_mode && @ARGV && $ARGV[0] eq 'erase';
shift if $erase_mode;
die "Usage: $0 erase <mac>...\n" if $erase_mode and not @ARGV;

my %fns;

for my $line (@lines) {
	my ($mac, $product_id, $hwtype) = split " ", $line;
	$mac and $mac =~ /^[0-F]{12,16}$/ or next;
	$product_id or next;
	(grep { $_ eq $product_id or $_ eq $mac } @ARGV) or next if @ARGV;

	my $product = $erase_mode
		? { id => "_ERASE_", description => $mac }
		: $products->{$product_id} || $products->{_NOTFOUND_};

	my $needs_fixing = 0;
	if ($fix_mode or not $hwtype) {
		my $dbitem = get_dbitem($mac);
		next if not %$dbitem;
		$hwtype ||= $new_hwtype{$mac} = $dbitem->{hwType};
		$needs_fixing = $dbitem->{hash} =~ /^0+$/;
	}

	my $fn = $fns{$product} ||= draw($product, $hwtype, $needs_fixing || !!@ARGV) or next;

	print "Uploading image for $mac ($product->{description}).\n";
	post "imgupload" => [ mac => $mac, lut => 1, alias => $product->{description}, file => $fn ];

	if ($new_hwtype{$mac}) {
		$line =~ s/$/ $new_hwtype{$mac}/;
	}
}

if (%new_hwtype) {
	spurt "$datadir/oepl", @lines;
}
