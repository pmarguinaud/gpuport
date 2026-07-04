#!/usr/bin/perl -w
#
use strict;
use File::Path;
use File::Basename;
use File::Spec;
use Data::Dumper;
use File::stat;

my @F = grep { !/^-/o } @ARGV;

my $UID = $<;

for my $F (@F)
  {
    $F = 'File::Spec'->rel2abs ($F);
    my $B = basename ($F);
    my @dir = 'File::Spec'->splitdir (dirname ($F));
    my $top = shift (@dir);
    for (@dir)
      {
        $top .= "/$_";
        my $st = stat ($top);
        last if ($st->uid () == $UID);
      }
    my $trh = "$top/.Trash-$UID";
    mkpath ($trh);
    my ($ext, $i) = ('', 0);
    while (-f "$trh/$B$ext" || -d "$trh/$B$ext")
      {
        $ext = ".$i";
        $i++;
      }
    rename ($F, "$trh/$B$ext");
  }








