package RevBank::Products;

use v5.32;
use warnings;
use experimental 'signatures';  # stable since 5.36

use RevBank::Prompt;
use RevBank::Global;
use Exporter qw(import);
our @EXPORT = qw(read_products);

# Note: the parameters are subject to change
sub read_products($filename = "revbank.products", $default_contra = "+sales/products") {
    state %caches;   # $filename => \%products
    state %mtimes;  # $filename => mtime

    my $mtime = \$mtimes{$filename};
    my $cache = $caches{$filename} ||= {};
    return $cache if $$mtime and (stat $filename)[9] == $$mtime;

    my %products;
    my $linenr = 0;
    my $warnings = 0;

    $$mtime = (stat $filename)[9];
    for my $line (slurp $filename) {
        $linenr++;

        next if $line =~ m[
            ^\s*\#    # comment line
            |
            ^\s*$     # empty line, or only whitespace
        ]x;

        my @split = RevBank::Prompt::split_input($line);

        if (not @split or ref $split[0] or grep /\0/, @split) {
            warn "Invalid value in $filename line $linenr.\n";
            next;
        }

        my ($ids, $p, $desc, @extra) = @split;

        my @addon_ids;
        my %tags;

        my $compat = 0;
        if (@split == 1 and ref $split[0]) {
            $compat = 1;
        } else {
            for (@extra) {
                if (/^\+(.*)/) {
                    push @addon_ids, $1;
                } elsif (/^\#(\w+)(=(.*))?/) {
                    $tags{$1} = $2 ? $3 : 1;
                } else {
                    $compat = 1;
                    last;
                }
            }
        }

        if ($compat) {
            $warnings++;
            warn "$filename line $linenr: can't parse as new format; assuming old format.\n" if $warnings < 4;
            warn "Too many warnings; suppressing the rest. See UPGRADING.md for instructions.\n" if $warnings == 4;

            ($ids, $p, $desc) = split " ", $line, 3;

            @addon_ids = ();
            unshift @addon_ids, $1 while $desc =~ s/\s+ \+ (\S+)$//x;
        }

        my @ids = split /,/, $ids;

        $p //= 0;
        $desc ||= "(no description)";

        my $canonical = join " ", map RevBank::Prompt::reconstruct($_), $ids, $p, $desc, @extra;

        my ($price, $contra) = split /\@/, $p, 2;

        my $sign = $price =~ s/^-// ? -1 : 1;
        my $percent = $price =~ s/%$//;

        if ($percent) {
            if (grep !/^\+/, @ids) {
                warn "Percentage invalid for non-addon at $filename line $linenr.\n";
                next;
            }
            $percent = $sign * (0 + $price);
            $price = undef;  # calculated later
        } else {
            $price = eval { parse_amount($price) };
            if (not defined $price) {
                warn "Invalid price for '$ids[0]' at $filename line $linenr.\n";
                next;
            }
            $price *= $sign;
        }
        for my $id (@ids) {
            warn "Product '$id' redefined at $filename line $linenr (original at line $products{$id}{line}).\n" if exists $products{$id};

            # HERE (see .pod)
            $products{$id} = {
                id          => $ids[0],
                aliases     => [ @ids[1 .. $#ids] ],
                is_alias    => $id ne $ids[0],
                description => $desc,
                contra      => $contra || $default_contra,
                _addon_ids  => \@addon_ids,
                line        => $linenr,
                tags        => \%tags,
                config      => $canonical,

                percent     => $percent,
                price       => $price,  # base price

                # The following are calculated below, for top-level products only:
                # tag_price   => base price + sum of transparent addons
                # hidden_fees => sum of opaque addons
                # total_price => tag_price + hidden_fees
            };
        }
    }

    # Resolve addons
    PRODUCT: for my $product (values %products) {
        my %ids_seen = ($product->{id} => 1);
        my @addon_ids = @{ $product->{_addon_ids} };

        while (my $addon_id = shift @addon_ids) {
            $addon_id = "+$addon_id" if exists $products{"+$addon_id"};

            if ($ids_seen{$addon_id}++) {
                warn "Infinite addon loop for '$product->{id}' at $filename line $product->{line}.\n";
                next PRODUCT;
            }

            my $addon = $products{$addon_id};
            if (not $addon) {
                warn "Addon '$addon_id' does not exist for '$product->{id}' at $filename line $product->{line}.\n";
                next PRODUCT;
            }
            $addon = { %$addon }; # shallow copy to overwrite ->{price} later

            push @{ $product->{addons} }, $addon;
            push @addon_ids, @{ $addon->{_addon_ids} };
        }
    }

    # Calculate tag and total price
    PRODUCT: for my $id (keys %products) {
        next if $id =~ /^\+/;
        my $product = $products{$id};

        my $tag_price = $product->{price} || 0;
        my $hidden = 0;

        my @seen = ($product);
        for my $addon (@{ $product->{addons} }) {
            if ($addon->{percent}) {
                my $sum = List::Util::sum map {
                    $_->{price}
                } grep {
                    $_->{contra} eq $addon->{contra}
                } @seen;

                $addon->{price} = $addon->{percent} / 100 * $sum;
            }

            if ($addon->{tags}{OPAQUE}) {
                $hidden += $addon->{price};
            } else {
                $tag_price += $addon->{price};
            }

            push @seen, $addon;
        }

        $product->{tag_price} = $tag_price;
        $product->{hidden_fees} = $hidden;
        $product->{total_price} = $tag_price + $hidden;
    }

    if (%$cache) {
        for my $new (values %products) {
            next if $new->{is_alias};

            my $id = $new->{id};
            my $old = $cache->{$id};

            call_hooks("product_changed", $old, $new, $$mtime)
                if not defined $old or $new->{config} ne $old->{config};

            delete $cache->{$id};
        }

        for my $p (values %$cache) {
            next if $p->{is_alias};
            call_hooks("product_deleted", $p, $$mtime);
        }
    }

    %$cache = %products;
    return \%products;
}

1;
