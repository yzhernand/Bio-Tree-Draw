#
# BioPerl module for Bio::Tree::Draw::gd
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Gabriel Valiente <valiente@lsi.upc.edu>
#
# Copyright Gabriel Valiente
#
# You may distribute this module under the same terms as Perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tree::Draw::gd - Tree::Draw implementation for drawing
phylogenetic trees in GD and producing a PNG (default), JPEG,
or GIF image formats, or simply retrieve the GD::Image object
created.

=head1 SYNOPSIS

  use Bio::Tree::Draw;
  use Bio::TreeIO;
  my $treeio = Bio::TreeIO->new('-format' => 'newick',
  			       '-file'   => 'input.nwk');
  my $t1 = $treeio->next_tree;
  my $t2 = $treeio->next_tree;

  my $obj1 = Bio::Tree::Draw->new(-tree => $t1,
                                  -format => 'gd');
  $obj1->print(-file => 'cladogram.png');

  # To draw a jpg instead...
  my $obj1 = Bio::Tree::Draw->new(-tree => $t1,
                                  -format => 'gd',
                                  -imgfmt => 'jpg');
  $obj1->print(-file => 'outtree.jpg');

=head1 DESCRIPTION

Bio::Tree::Draw::postscript is a Perl tool for drawing Bio::Tree::Tree
objects in Encapsulated PostScript (EPS) format. It can be utilized
both for displaying a single phylogenetic tree (a cladogram) and for
the comparative display of two phylogenetic trees (a tanglegram) such
as a gene tree and a species tree, a host tree and a parasite tree,
two alternative trees for the same set of taxa, or two alternative
trees for overlapping sets of taxa.

Phylogenetic trees are drawn as rectangular cladograms, with
horizontal orientation and ancestral nodes centered over their
descendents. The font used for taxa is Courier at 10 pt. A single
Bio::Tree::Tree object is drawn with ancestors to the left and taxa
flushed to the right. Two Bio::Tree::Tree objects are drawn with the
first tree oriented left-to-right and the second tree oriented
right-to-left, and with corresponding taxa connected by straight lines
in a shade of gray. Each correspondence between a $taxon1 of the first
tree and a $taxon2 of the second tree is established by setting
$taxon1-E<gt>add_tag_value('connection',$taxon2). Thus, a taxon of the
first tree can be connected to more than one taxon of the second tree,
and vice versa.

The branch from the parent to a child $node, as well as the child
label, can be colored by setting $node-E<gt>add_tag_value('Rcolor',$r),
$node-E<gt>add_tag_value('Gcolor',$g), and
$node-E<gt>add_tag_value('Bcolor',$b), where $r, $g, and $b are the
desired values for red, green, and blue (zero for lowest, one for
highest intensity).

This is a preliminary release of Bio::Tree::Draw::Cladogram. Future
improvements include an option to output phylograms instead of
cladograms. Beware that cladograms are automatically scaled according
to branch lengths, but the current release has only been tested with
trees having unit branch lengths.

# Now obsolete documentation?
The print method could be extended to output graphic formats other
than EPS, although there are many graphics conversion programs around
that accept EPS input. For instance, most Linux distributions include
epstopdf, a Perl script that together with Ghostscript, converts EPS
to PDF.

Do not use this module directly. Instead, create a new
Bio::Tree::Draw object using the -format=>'gd' flag.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 

Please direct usage questions or support issues to the mailing list:

I<bioperl-l@bioperl.org>

rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via
the web:

  http://bugzilla.open-bio.org/

=head1 AUTHOR - Gabriel Valiente

Email valiente@lsi.upc.edu

Code for coloring branches contributed by Georgii A Bazykin
(gbazykin@princeton.edu).

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::Tree::Draw::gd;
use strict;

use GD;

use base qw(Bio::Tree::Draw);

my %gd_fonts = ('gdSmallFont' => GD::Font->Small,
		        'gdLargeFont' => GD::Font->Large,
				'gdMediumBoldFont' => GD::Font->MediumBold,
				'gdTinyFont' => GD::Font->Tiny
		       );

my %gd_img_fmts = ('png' => 1,
                   'jpeg' => 1,
				   'gif' => 1
				  );
=head2 new

 Title   : new
 Function: Initialize internal variables. Some defaults are preset in
           Bio::Tree::Draw, but if the module writer believes other
		   defaults are more appropriate for the format, they should
		   be set here. This sub should always call $self->_plot_tree
		   with -tipwidth1 and -tipwidth2 calculated. This means this
		   sub must calculate the longest taxa label length (in pixels)
           and pass it as arguments to $self->_plot_tree
 Args    : none (for now)
=cut

sub _initialize {
    my $self = shift;
	$self->SUPER::_initialize(@_);

    my $font = $self->_rearrange([qw(FONT)], @_);
    if ( $gd_fonts{ $font } ) {
	  $self->{'font'} = $gd_fonts{$font};
	} else {
      print STDERR "$font is not a valid GD font. Changing to gdSmallFont...\n"
	    if ( defined($font) );
      $self->{'font'} = GD::Font->Small;
    }

	my $img_fmt = lc($self->_rearrange([qw(IMGFMT)], @_)) || undef;
    if ( ! $gd_img_fmts{$img_fmt} ) {
       print STDERR "$img_fmt is not a valid GD format. Using 'png' instead...\n"
	       if ( defined($img_fmt) );
       $self->{'img_fmt'} = 'png';
	} else {
       $self->{'img_fmt'} = $img_fmt;
	}

    my ($maxtipwidth1, $maxtipwidth2);
    $maxtipwidth1 = $self->_get_max_tip_witdh($self->{'t1'});

	# Include check even though we don't support 2 trees yet
    if ($self->{'t2'}) {
        $maxtipwidth2 = $self->_get_max_tip_witdh($self->{'t2'});
    }

    $self->_plot_tree(@_, -tipwidth1 => $maxtipwidth1, -tipwidth2 => $maxtipwidth2);
}

=head2 _get_max_tip_witdh

 Title   : _get_max_tip_witdh
 Usage   : *INTERNAL Tree::Draw stuff*
 Function: Calculate the length of the longest taxa label
 Example :
 Returns :
 Args    :

=cut

sub _get_max_tip_witdh {
    my ($self, $tree) = @_;
    my ($max_width, $curr_width) = (0,0);

    foreach my $taxon ($tree->get_leaf_nodes) {
        $curr_width = length($taxon->id) * $self->{'font'}->width;
        if ( $curr_width > $max_width ) { $max_width = $curr_width; }
    }

    return $max_width;
}

=head2 draw

 Title   : draw
 Usage   : $obj->draw();
 Function: Outputs a PNG (default), GIF, or JPG image using GD library.
 Returns : 
 Args    : -file => filename (optional)

=cut

sub draw {
    my ($self, @args) = @_;

	my $img_fmt = $self->{'img_fmt'};
	my $filename = $self->_rearrange([qw(FILENAME)], @args) || "outtree" . "." . $img_fmt;
   	
	if ( ! defined ($self->{'gd_img'}) ) {
		$self->_draw_gd();
    }

    open OUTIMAGE, ">$filename";
    print OUTIMAGE $self->{'gd_img'}->$img_fmt;
    close OUTIMAGE;
}

=head2 _draw_gd

 Title   : _draw_gd
 Usage   : *Internal Draw stuff*
 Function: Draws the tree using GD and saves the GD::Image internally
 Returns : 
 Args    : -file => filename (optional)

=cut

sub _draw_gd {
  my $self = shift;
  my $image = new GD::Image($self->{'width'}, $self->{'height'});
  my $white = $image->colorAllocate(255,255,255);
  my $black = $image->colorAllocate(0,0,0);
  my $foreground = $black;

  #<<Draw taxa labels>>
  # taxa labels are centered to 1/3 the font font->height
  for my $taxon (reverse $self->{'t1'}->get_leaf_nodes) {
    if ($self->{'colors'}) {
      $foreground = $image->colorAllocate($self->{'Rcolor'}->{$taxon},$self->{'Gcolor'}->{$taxon},$self->{'Bcolor'}->{$taxon});
    }
    $image->string($self->{'font'}, $self->{'xx'}->{$taxon} + $self->{'tip'}, $self->{'yy'}->{$taxon} - $self->{'font'}->height / 3, $taxon->id, $foreground)
  }

  # Draw branches/node id's
  my $root1 = $self->{'t1'}->get_root_node;
  for my $node ($self->{'t1'}->get_nodes) {
    if ($node->ancestor) {
      if ($self->{'colors'}) {
        $foreground = $image->colorAllocate($self->{'Rcolor'}->{$node},$self->{'Gcolor'}->{$node},$self->{'Bcolor'}->{$node});
      }

      $image->line($self->{'xx'}->{$node}, $self->{'yy'}->{$node}, $self->{'xx'}->{$node->ancestor}, $self->{'yy'}->{$node}, $foreground);
      
      # Print id if 'bootstrap' option was given
      if( $self->{'bootstrap'} ) {
        $image->string($self->{'font'}, $self->{'xx'}->{$node->ancestor}+ $self->{'font'}->height / 10,
                       $self->{'yy'}->{$node->ancestor} - ($self->{'font'}->height / 3),
                       $node->ancestor->id, $foreground);
      }
      $image->line($self->{'xx'}->{$node->ancestor}, $self->{'yy'}->{$node}, $self->{'xx'}->{$node->ancestor}, $self->{'yy'}->{$node->ancestor}, $foreground);

    }
  }

  # Draw line to root
  my $ymin = $self->{'yy'}->{$root1};
  my $ymax = $self->{'yy'}->{$root1};
  foreach my $child ($root1->each_Descendent) {
    $ymax = $self->{'yy'}->{$child} if $self->{'yy'}->{$child} > $ymax;
    $ymin = $self->{'yy'}->{$child} if $self->{'yy'}->{$child} < $ymin;
  }
  my $zz = ($ymin + $ymax)/2;
  if ($self->{'colors'}) {
    $foreground = $image->colorAllocate($self->{'Rcolor'}->{$root1},$self->{'Gcolor'}->{$root1},$self->{'Bcolor'}->{$root1});
  }
  $image->line($self->{'xx'}->{$root1}, $zz, $self->{'xx'}->{$root1} - $self->{'xstep'}, $zz, $foreground);

  # If there is a second tree...
#  if ($self->{'t2'}) {
#
#    for my $taxon (reverse $self->{'t2'}->get_leaf_nodes) {
#      my $self->{'tiplen2'} = $taxon->id * $self->{'font'}->width;
#      $image->string($self->{'font'}, $self->{'xx'}->{$taxon} - $self->{'tiplen2'} - $self->{'tip'},
#                     $self->{'yy'}->{$taxon} - $self->{'font'}->height / 3, $taxon->id,
#                     $foreground);
#    }
#
#    # TODO
#    for my $node ($self->{'t2'}->get_nodes) {
#      if ($node->ancestor) {
#        print $INFO $self->{'xx'}->{$node}, " ", $self->{'yy'}->{$node}, " moveto\n";
#        print $INFO $self->{'xx'}->{$node->ancestor}, " ", $self->{'yy'}->{$node}, " lineto\n";
#        print $INFO $self->{'xx'}->{$node->ancestor}, " ",
#          $self->{'yy'}->{$node->ancestor}, " lineto\n";
#      }
#    }
#
#    my $root2 = $self->{'t2'}->get_root_node;
#    my $ymin = $self->{'yy'}->{$root2};
#    my $ymax = $self->{'yy'}->{$root2};
#    foreach my $child2 ($root2->each_Descendent) {
#      $ymax = $self->{'yy'}->{$child2} if $self->{'yy'}->{$child2} > $ymax;
#      $ymin = $self->{'yy'}->{$child2} if $self->{'yy'}->{$child2} < $ymin;
#    }
#    my $zz = ($ymin + $ymax)/2;
#    print $INFO $self->{'xx'}->{$root2}, " ", $zz, " moveto\n";
#    print $INFO $self->{'xx'}->{$root2} + $xstep, " ", $zz, " lineto\n";
#
#    my @taxa1 = $self->{'t1'}->get_leaf_nodes;
#    my @taxa2 = $self->{'t2'}->get_leaf_nodes;
#
#    # set default connection between $self->{'t1'} and $self->{'t2'} taxa, unless
#    # overridden by the user (the latter not implemented yet)
#
#    foreach my $taxon1 (@taxa1) {
#      foreach my $taxon2 (@taxa2) {
#	if ($taxon1->id eq $taxon2->id) {
#	  $taxon1->add_tag_value('connection',$taxon2);
#	  last;
#	}
#      }
#    }
#
#    # draw connection lines between $self->{'t1'} and $self->{'t2'} taxa
#
#    print $INFO "stroke\n";
#    print $INFO "0.5 setgray\n";
#
#    foreach my $taxon1 (@taxa1) {
#      my @match = $taxon1->get_tag_values('connection');
#      foreach my $taxon2 (@match) {
#	my $x0 = $self->{'xx'}->{$taxon1} + $self->{'tip'}
#	  + PostScript::Metrics::stringwidth($taxon1->id,$self->{'font'},$self->{'font'}->height) + $self->{'tip'};
#	my $x1 = $self->{'xx'}->{$taxon1} + $self->{'tip'} + $self->{'tipwidth1'} + $self->{'tip'};
#        my $y1 = $self->{'yy'}->{$taxon1};
#        my $x2 = $self->{'xx'}->{$taxon2} - $self->{'tip'} - $self->{'tipwidth2'} - $self->{'tip'};
#        my $x3 = $self->{'xx'}->{$taxon2} - $self->{'tip'}
#	  - PostScript::Metrics::stringwidth($taxon2->id,$self->{'font'},$self->{'font'}->height) - $self->{'tip'};
#        my $y2 = $self->{'yy'}->{$taxon2};
#        print $INFO $x0, " ", $y1, " moveto\n";
#        print $INFO $x1, " ", $y1, " lineto\n";
#        print $INFO $x2, " ", $y2, " lineto\n";
#        print $INFO $x3, " ", $y2, " lineto\n";
#      }
#    }
#
#  }

    $self->{'gd_img'} = $image;
}

=head2 gd_img

 Title   : gd_img
 Usage   : $obj->gd_img();
 Function: Returns $obj as a GD::Image object
 Returns : GD::Image object
 Args    : 

=cut

sub gd_img {
    my $self = shift;

	if ( ! defined ($self->{'gd_img'}) ) {
		$self->_draw_gd();
    }

	return $self->{'gd_img'};
}

1;
