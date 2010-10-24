#
# BioPerl module for Bio::Tree::DrawFeatures
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Yozen Hernandez <yzhernand@gmail.com>
#
# Copyright Yozen Hernandez
#
# You may distribute this module under the same terms as Perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tree::DrawFeatures - Draw a Tree alongside a given set of SeqFeatures
using Bio::Graphics.

=head1 SYNOPSIS

  use Bio::SeqFeature::Generic;
  use Bio::Tree::DrawFeatures;

  # Open a tree file using Bio::TreeIO and get a TreeI object.
  my $treeio = Bio::TreeIO->new(-format => 'newick', -file => 'treefile.dnd');
  my $treeobj = $treeio->next_tree;

  # Create/get some Bio::SeqFeature objects somehow and add them as tracks to
  # a Bio::Graphics::Panel object as you like, for any/all taxa in the desired
  # Tree file.
  $panel->add_track(arrow => Bio::SeqFeature::Generic->new(-start=>1,
                                                           -end=>$seq->length),
														   -bump => 0,
														   -double=>1,
														   -tick => 2);
  # and so on, until all tracks are added

  # Save each Bio::Graphics::Panel to a hash with a key the same as the
  # corresponding taxon id on the input tree file
  $panel_hash{$taxon_id} = $panel;

  # If your panel hash doesn't use leaf_ids as keys, you need to create a mapping hash
  # For example:
  foreach my $leaf_id ( @tree_leaves ) {
    $id_map{$leaf_id} = get_feature_key($leaf_id)
  }
  # Or make a mapping file and parse it into a hash which you then pass to DrawFeatures

  # Now create the DrawFeatures object:
  # Bio::Tree::DrawFeatures by default creates a png image
  my $tree_feat_draw = Bio::Tree::DrawFeatures->new(-tree => $treeobj,
                                                    -feat_hash => \%panel_hash,
                                                    -id_map => \%id_map);

  # And draw the diagram (don't include a leading '>')
  $tree_feat_draw->draw(-file => 'tree_image.png');

=head1 DESCRIPTION

This object can take a Bio::Tree::TreeI complaint object and
a hash of taxon ids -> Bio::Graphics objects to produce an
image aligning tree leaves with the corresponding feature tracks.

It uses Bio::Tree::Draw and Bio::Graphics/GD to produce the image.

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

=head1 AUTHORS - Yozen Hernandez

Email yzhernand@gmail.com

=head1 CONTRIBUTORS


=head1 APPENDIX

This module is the end result of trying to find some way of lining
up visual features, like orf plots, next to a tree. Such a diagram
would simultaneously show both synteny and phylogeny. This module
was built to use Bio::Tree::Draw, (in turn built upon Gabriel Valiente's
excellent Bio::Tree::Draw::Cladogram) and Lincoln Stein's Bio::Graphics
and GD libraries for perl.

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::Tree::DrawFeatures;
use strict;
#use Bio::Graphics;
#use Bio::Tree::Draw;
#use GD;
#use Data::Dumper;

# Object preamble - inherits from Bio::Root::Root

use base qw(Bio::Root::Root);

# Global package variable
my $tree;
my %param;
my %panel_hash;
my %id_map;
my $tree_gd;
my %y_coords;
my $max_feat_height = 0;
my $max_feat_width = 0;
my $filename;

=head2 new

 Title   : new
 Usage   : my $tr_ft_drawer = Bio::Tree::DrawFeatures->new(-tree => $treeobj);
 Function: Builds a new Bio::Tree::DrawFeatures object.
 Returns : Bio::Tree::DrawFeatures
 Args    : -tree => Bio::Tree::Tree object [required]
           -feat_hash => reference to a hash of id's -> Bio::Graphics objects. [required]
           -id_map => reference to a hash of taxon id's -> feat_hash keys. [optional]

		   This module also accepts options for Bio::Tree::Draw. See documentation
		   for that module for details.
=cut

sub new {
    my ($self, @args) = @_;
	#_initialize(@args);
    %param = @args;

    @param{ map { lc $_ } keys %param } = values %param; # lowercase keys
	$tree = $param{'-tree'} || $self->throw("Missing required argument -tree");
	$param{'-font'} ||= 'gdLargeFont';

	%panel_hash = %{$param{'-feat_hash'}} || $self->throw("Missing required argument -feat_hash");
	%id_map = exists($param{'-id_map'}) ? %{$param{'-id_map'}} : undef;

	_get_max_feat_dims();
	$param{'-tax_space'} ||= $max_feat_height + ($max_feat_height * 0.25);

	return $self;
}

=head2 draw

 Title   : draw
 Usage   : $tr_ft_draw->draw(-file '>$tree_graphic');
 Function: Draws a tree to the given file in the given format
 Returns : none
 Args    : a hash. Useful keys:
           -file => the desired output file where the tree drawing should be saved.


=cut

sub draw {
	my ($self, @args) = @_;
    my @leaf_nodes = $tree->get_leaf_nodes;
	$filename = $self->_rearrange([qw(FILE)], @args) || 'outtree-feature.png';
	
    #<<Use Bio::Tree::Draw to create a GD image>>  
   	my $tree_drawer = Bio::Tree::Draw->new(-right => 0,
										   -tip => 0,
										   -format => 'gd',
								           %param);

	#<<Get tree GD::Image>>
	my $tree_image = $tree_drawer->gd_img();

	# Make white background transparent
	my $white = $tree_image->colorClosest(255,255,255);
	$tree_image->transparent($white);

	#<<Get coordinates for all leaf nodes>>
	my %leaf_coords = $self->_get_leaf_coords($tree_drawer, \@leaf_nodes);

    #<<New canvas>>
    # Canvas size: width = tree.width + max_feat_width, height = tree.height
    my $tree_synteny_gd = new GD::Image($tree_image->width + $max_feat_width, $tree_image->height);
    my $background = $tree_synteny_gd->colorAllocate(255,255,255);

    # In module, make it possible to add dashed lines from leaf to track beginning
    # Also, make this an option
    #my $alt_row = 0;
    #my $ypos = 0;
    ## FOR MAKING ALTERNATING SHADED ROWS
    #foreach my $leaf_node (@leaf_nodes) {
    #	$ypos = $leaf_coords{$leaf_node->id};
    #	if ( $alt_row ) {
    #		$tree_synteny_gd->filledRectangle(0, $ypos - ($max_feat_height * 0.25),
    #						$tree_synteny_gd->width, $ypos + ($max_feat_height * 0.75), $shaded);
    #		$alt_row = 0;
    #	} else {
    #		$alt_row = 1;
    #	}
    #}
 
    #<<Attach each orf feature GD::Image object at appropriate position>>
    my $dstY = 0;
    my $dstX = $tree_image->width;
   
	#<<Use leaf_id's to match with corresponding features>>
    foreach my $leaf_id (keys %leaf_coords) {
		# If an id map was not given, assume $panel_hash has leaf_ids as keys
        my $track = $panel_hash{ $id_map{$leaf_id} } || $panel_hash{$leaf_id}; #$track is a GD::Image;

        if ( defined $track ) {
		    $dstY = $leaf_coords{$leaf_id};
		    my $white = $track->colorClosest(255,255,255);
		    $track->transparent($white);

		    $tree_synteny_gd->copy($track, $dstX, $dstY - ( $track->height * 0.25 ),
                                   0, 0, $track->width, $track->height);
	    }
    }

    #<<Attach tree GD::Image (flush left)
    #If we need to add extra features to the background, make images to be copied have a
    #transparent background and add features to $tree_synteny_gd

    $tree_synteny_gd->copy($tree_image, 0, 0, 0, 0, $tree_image->width, $tree_image->height);

    open OUTTRSYN, ">$filename";
    binmode OUTTRSYN;
    print OUTTRSYN $tree_synteny_gd->png;
    close OUTTRSYN;
}

=head2 _initialize

 Title   : _initialize
 Usage   : *INTERNAL Tree::DrawFeature stuff*
 Function: Assign initial parameters
 Example :
 Returns :
 Args    :

=cut

sub _initialize {
}

=head2 _get_max_feat_dims

 Title   : _get_max_feat_dims
 Usage   : *INTERNAL Tree::DrawFeature stuff*
 Function: Assign initial parameters
 Example :
 Returns :
 Args    :

=cut

sub _get_max_feat_dims {
    my $self = shift;

	foreach my $panel (values %panel_hash ) {
    	$max_feat_height = $panel->height() if ( $panel->height > $max_feat_height );
    	$max_feat_width = $panel->width() if ( $panel->width > $max_feat_width );
	}
}

=head2 _get_leaf_coords

 Title   : _get_leaf_coords
 Usage   : *INTERNAL Tree::DrawFeature stuff*
 Function: Create a hash associating leaf nodes and y-coordinates
 Example :
 Returns : a hash of leaf nodes as keys and y-coordinates as values
 Args    :

=cut

sub _get_leaf_coords {
	my $self = shift;
	my $tree_drawer = shift;
	my $leaf_nodes = shift;

	my %yy = %{ $tree_drawer->get_ycoordinates };
	my %leaf_coords = ();

	foreach my $leaf (@$leaf_nodes) {
		$leaf_coords{$leaf->id} = $yy{$leaf};
	}

	return %leaf_coords;
}

1;
