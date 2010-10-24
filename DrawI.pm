#
# BioPerl module for Bio::Tree::DrawI
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

Bio::Tree::DrawI - A Tree-drawing object designed for drawing
  Bio::Tree:TreeI compliant objects.

=head1 SYNOPSIS

  my $treeio = Bio::TreeIO->new(-format => 'newick', -file => 'treefile.dnd');
  my $treeobj = $treeio->next_tree;

  # Bio::Tree::Draw by default uses GD and creates a png image
  my $treedrawer = Bio::Tree::Draw->new(-tree => $treeobj);
  $treedrawer->draw(-file => 'tree_image.png');

=head1 DESCRIPTION

This object can take a Bio::Tree::TreeI complaint object and
produce an output image in one of any available formats. The desired
format can be requested using the -format option. Currently accepted
formats are jpeg, png, and postscript. By leaving the format at its
default (png) or choosing jpg, it is also possible to retrieve a
GD::Image object representing the tree, for further manipulation.

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

=head1 AUTHOR - Yozen Hernandez	

Email yzhernand@gmail.com

=head1 CONTRIBUTORS


=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::Tree::DrawI;
use strict;

# Object preamble - inherits from Bio::Root::RootI

use base qw(Bio::Root::RootI);

=head2 draw

 Title   : draw
 Usage   : $tree_drawer->draw(-file '>$tree_graphic');
 Function: Draws a tree to the given file in the given format
 Returns : none
 Args    : a hash. Useful keys:
           -file => the desired output file where the tree drawing should be saved.


=cut

sub draw {
    my ($self) = @_;
    $self->throw_not_implemented;
}

=head2 get_ycoordinates

 Title   : get_ycoordinates
 Usage   : my %ycoords = $tree_drawer->get_ycoordinates();
 Function: Returns the y-coordinates for each node in the output image
           as a hash
 Returns : A hash
 Args    : 

=cut

sub get_ycoordinates {
    my ($self) = @_;
    $self->throw_not_implemented;
}

1;
