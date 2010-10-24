#
# BioPerl module for Bio::Tree::Draw
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Yozen Hernandez <yzhernand@gmail.com>
#
# Copyright Gabriel Valiente, Yozen Hernandez
#
# You may distribute this module under the same terms as Perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tree::Draw - An implementation of the Bio::Tree::DrawI interface 

=head1 SYNOPSIS

  my $treeio = Bio::TreeIO->new(-format => 'newick', -file => 'treefile.dnd');
  my $treeobj = $treeio->next_tree;

  # Bio::Tree::Draw by default uses GD and creates a png image
  my $treedrawer = Bio::Tree::Draw->new(-tree => $treeobj);
  $treedrawer->draw(-file => 'tree_image.png');

=head1 DESCRIPTION

This object can take a Bio::Tree::TreeI complaint object and
produce an output image in one of any available formats. The desired
format can be requested using the -format option.

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

=head1 AUTHORS - Gabriel Valiente, Yozen Hernandez

Email valiente@lsi.upc.edu
Email yzhernand@gmail.com

=head1 CONTRIBUTORS


=head1 APPENDIX

Nearly all the package variables and all the work done in the
_plot_tree function come from Gabriel Valiente's excellent
Bio::Tree::Draw::Cladogram module. I've adapted the work here to
provide a framework for more image file formats starting with the
addition of jpeg and png using Lincoln Stein's perl GD bindings.
Indeed, this would allow drawing trees in any of the formats supported
by GD, and for more complicated diagrams to be created using trees by
accessing the GD::Image object created.

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::Tree::Draw;
use strict;

# Object preamble - inherits from Bio::Root::Root

use base qw(Bio::Root::Root Bio::Tree::DrawI);

#our %xx;        # horizontal coordinate for each node
#our %yy;        # vertical coordinate for each node
#our $t1;        # first Bio::Tree::Tree object
#our $t2;        # second Bio::Tree::Tree object
#our $font;      # font name
#our $size;      # font size
#our $width;     # total drawing width
#our $height;    # total drawing height
#our $xstep;     # branch length in drawing
#our $tip;       # extra space between tip and label
#our $tipwidth1; # width of longest label among $t1 taxa (module MUST pass this)
#our $tipwidth2; # width of longest label among $t2 taxa (module must pass this if using two trees)
#our $compact;   # whether or not to ignore branch lengths
#our $ratio;     # horizontal to vertical ratio
#our $colors;    # use colors to color edges
#our %Rcolor;    # red color for each node
#our %Gcolor;    # green color for each node
#our %Bcolor;    # blue color for each node
#our $bootstrap; # Draw Bootstrap boolean
#our $tax_space; # Space between taxa (value for ystep)

=head2 new

 Title   : new
 Usage   : my $drawer = Bio::Tree::Draw->new(-tree => $treeobj);
 Function: Builds a new Bio::Tree::Draw object.
 Returns : Bio::Tree::Draw
 Args    : -tree => Bio::Tree::Tree object
           -format => Output file format. Currently supported formats are:
		           gd
				   postscript
           -second => Bio::Tree::Tree object (optional)
           -font => font name [string] (optional)
           -size => font size [integer] (optional)
           -top => top margin [integer] (optional)
           -bottom => bottom margin [integer] (optional)
           -left => left margin [integer] (optional)
           -right => right margin [integer] (optional)
           -tip => extra tip space [integer] (optional)
           -tax_space => space between taxa [integer] (optional)
           -column => extra space between cladograms [integer] (optional)
           -compact => ignore branch lengths [boolean] (optional)
           -ratio => horizontal to vertical ratio [integer] (optional)
           -colors => use colors to color edges [boolean] (optional)
           -bootstrap => draw bootstrap or internal ids [boolean]

=cut

sub new {
    my ($caller, @args) = @_;
    my $class = ref($caller) || $caller;

    # or do we want to call SUPER on an object if $caller is an
    # object?
    if ( $class =~ /Bio::Tree::Draw::(\S+)/ ) {
        my ($self) = $class->SUPER::new(@args);
		$self->_initialize(@args); # Don't have/(need?) and initialization sub right now.

        return $self;
    } else {
        my %param = @args;
        @param{ map { lc $_ } keys %param } = values %param; # lowercase keys
		my $format = $param{'-format'} || 'gd';
		$format = "\L$format"; # normalize capitalization to lower case

		return unless( $class->_load_format_module($format) );
		return "Bio::Tree::Draw::$format"->new(@args);
    }
}

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
    $self->throw("Cannot call method draw on Bio::Tree::Draw object. Must use a subclass.");
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
    my $self = shift;
	#print STDERR "Self ", %{$self->{'yy'}}, "\n";
    return %{ $self->{'yy'} };
}

=head2 _plot_tree
 
 Title   : _plot_tree
 Usage   : Internal use.
 Function: A format module would call this to get the tree plot/dimensions and use that
           to draw the tree in the appropriate format. Before a module calls this method,
		   they should initialize the font to be used.
 Returns : none
 Args    : none

=cut

sub _plot_tree {
  my($self,@args) = @_;

  ($self->{'top'}, $self->{'bottom'}, $self->{'left'}, $self->{'right'},
    $self->{'tip'}, $self->{'column'}, $self->{'compact'}, $self->{'ratio'}, $self->{'colors'},
	$self->{'bootstrap'}, $self->{'tax_space'}, $self->{'tipwidth1'}, $self->{'tipwidth2'}) = 
	$self->_rearrange([qw(TOP BOTTOM LEFT RIGHT 
			      TIP COLUMN COMPACT RATIO COLORS BOOTSTRAP TAX_SPACE
			      TIPWIDTH1 TIPWIDTH2)], 
				   @args);
  $self->{'top'} ||= 10;
  $self->{'bottom'} ||= 10;
  $self->{'left'} ||= 10;
  $self->{'right'} ||= 10;
  $self->{'tip'} ||= 5;
  $self->{'column'} ||= 60;
  $self->{'compact'} ||= 0;
  $self->{'ratio'} ||= 1 / 1.6180339887;
  $self->{'colors'} ||= 0;
  $self->{'bootstrap'} ||= 0;
  $self->{'tax_space'} ||= 20;

  # Roughly, a cladogram is set according to the following parameters.

  #################################
  #                           # T #   $top (T, top margin)
  #        +---------+ XXX    #   #   $bottom (B, bottom margin)
  #        |                  #   #   $left (L, left margin)
  #        |                  #   #   $right (R, right margin)
  #   +----+                  #   #   $tip (X, extra tip space)
  #        |    +----+ XXXX   #   #   $width (total drawing width)
  #        |    |             #   #   $height (total drawing height)
  #        +----+             # Y #   $xstep (S, stem length)
  #             |             #   #   $ystep (Y, space between taxa)
  #             +----+ XX     #   #   $tiplen (string length of longest name)
  #                           # B #   $tipwidth (N, size of longest name)
  #################################
  # L         S       X  N  R #
  #############################

  # A tanglegram is roughly set as follows. The only additional
  # parameter is $column (C, length of connection lines between taxa
  # of the two trees), but $tip occurs four times, and $tiplen and
  # $tipwidth differ for the first and the second tree.

  ###########################################################
  #                                                         #
  #        +---------+ XXX  ----- XXXXXX +----+             #
  #        |                                  |             #
  #        |                                  +----+        #
  #   +----+                                  |    |        #
  #        |    +----+ XXXX -----    XXX +----+    |        #
  #        |    |                                  +----+   #
  #        +----+                                  |        #
  #             |                                  |        #
  #             +----+ XX   -----   XXXX +---------+        #
  #                                                         #
  ###########################################################
  # L                 X    X  C  X      X                 R #
  ###########################################################

  # An alternative would be to let the user set $width and $height in
  # points and to scale down everything to fit the desired
  # dimensions. However, the final EPS can later be scaled down to any
  # desired size anyway.

  my @taxa1 = $self->{'t1'}->get_leaf_nodes;
  my $root1 = $self->{'t1'}->get_root_node;

  my @taxa2;
  my $root2;

  my $ystep = $self->{'tax_space'};

  if ($self->{'t2'}) {
    @taxa2 = $self->{'t2'}->get_leaf_nodes;
    $root2 = $self->{'t2'}->get_root_node;
  }

  my $stems = $root1->height + 1;
  if ($self->{'t2'}) { $stems += $root2->height + 1; }
  my $labels = $self->{'tipwidth1'};
  if ($self->{'t2'}) { $labels += $self->{'tipwidth2'}; }
  $self->{'xstep'} = 20;
  $self->{'width'} = $self->{'left'} + $stems * $self->{'xstep'} + $self->{'tip'} + $labels + $self->{'right'};
  if ($self->{'t2'}) { $self->{'width'} += $self->{'tip'} + $self->{'column'} + $self->{'tip'} + $self->{'tip'}; }
  $self->{'height'} = $self->{'bottom'} + $ystep * (@taxa1 - 1) + $self->{'top'};
  if ($self->{'t2'}) {
    if ( scalar(@taxa2) > scalar(@taxa1) ) {
      $self->{'height'} = $self->{'bottom'} + $ystep * (@taxa2 - 1) + $self->{'top'};
    }
  }
  my $ystep1 = $self->{'height'} / scalar(@taxa1);
  my $ystep2;
  if ($self->{'t2'}) {
    $ystep2 = $self->{'height'} / scalar(@taxa2);
  }

  my $x = $self->{'left'} + $self->{'xstep'} * ($root1->height + 1) + $self->{'tip'};
  my $y = $self->{'bottom'};

  for my $taxon (reverse @taxa1) {
    $self->{'xx'}->{$taxon} = $x - $self->{'tip'};
    $self->{'yy'}->{$taxon} = $y;
    $y += $ystep1;
  }
  $x -= $self->{'xstep'};

  my @stack;
  my @queue; # postorder traversal
  push @stack, $self->{'t1'}->get_root_node;
  while (@stack) {
    my $node = pop @stack;
    push @queue, $node;
    foreach my $child ($node->each_Descendent(-sortby => 'internal_id')) {
      push @stack, $child;
    }
  }
  @queue = reverse @queue;

  for my $node (@queue) {
    if (!$node->is_Leaf) {
      my @children = $node->each_Descendent;
      my $child = shift @children;
      my $xmin = $self->{'xx'}->{$child};
      my $ymin = my $ymax = $self->{'yy'}->{$child};
      foreach $child (@children) {
	$xmin = $self->{'xx'}->{$child} if $self->{'xx'}->{$child} < $xmin;
	$ymax = $self->{'yy'}->{$child} if $self->{'yy'}->{$child} > $ymax;
	$ymin = $self->{'yy'}->{$child} if $self->{'yy'}->{$child} < $ymin;
      }
      $self->{'xx'}->{$node} = $xmin - $self->{'xstep'};
      $self->{'yy'}->{$node} = ($ymin + $ymax)/2;
    }
  }

  $self->{'xx'}->{$self->{'t1'}->get_root_node} = $self->{'left'} + $self->{'xstep'};

  my @preorder = $self->{'t1'}->get_nodes(-order => 'depth');

  for my $node (@preorder) {
    #print "\n$node";
    if ($self->{'colors'}) {
      if ($node->has_tag('Rcolor')) {
        $self->{'Rcolor'}->{$node} = $node->get_tag_values('Rcolor')
      } else {
        $self->{'Rcolor'}->{$node} = 0
      }
      if ($node->has_tag('Gcolor')) {
        $self->{'Gcolor'}->{$node} = $node->get_tag_values('Gcolor')
      } else {
        $self->{'Gcolor'}->{$node} = 0
      }
      if ($node->has_tag('Bcolor')) {
        $self->{'Bcolor'}->{$node} = $node->get_tag_values('Bcolor')
      } else {
        $self->{'Bcolor'}->{$node} = 0
      }
      #print "\t$self->{'Rcolor'}->{$node}\t$self->{'Gcolor'}->{$node}\t$self->{'Bcolor'}->{$node}";
    }
  }

  if ($self->{'compact'}) { # ragged right, ignoring branch lengths

    $self->{'width'} = 0;
    shift @preorder; # skip root
    for my $node (@preorder) {
      $self->{'xx'}->{$node} = $self->{'xx'}->{$node->ancestor} + $self->{'xstep'};
      $self->{'width'} = $self->{'xx'}->{$node} if $self->{'xx'}->{$node} > $self->{'width'};
    }
    $self->{'width'} += $self->{'tip'} + $self->{'tipwidth1'} + $self->{'right'};

  } else { # set to aspect ratio and use branch lengths if available

    my $total_height = (scalar($self->{'t1'}->get_leaf_nodes) - 1) * $ystep;
    my $scale_factor = $total_height * $self->{'ratio'} / $self->{'t1'}->get_root_node->height;    

    $self->{'width'} = $self->{'t1'}->get_root_node->height * $scale_factor;
    $self->{'width'} += $self->{'left'} + $self->{'xstep'};
    $self->{'width'} += $self->{'tip'} + $self->{'tipwidth1'} + $self->{'right'};

    shift @preorder; # skip root
    for my $node (@preorder) {
      my $bl = $node->branch_length;
      $bl = 1 unless (defined $bl && $bl =~ /^\-?\d+(\.\d+)?$/);
      $self->{'xx'}->{$node} = $self->{'xx'}->{$node->ancestor} + $bl * $scale_factor;
    }

  }

  if ($self->{'t2'}) {

    $x = $self->{'left'} + $self->{'xstep'} * ($root1->height + 1) + $self->{'tip'};
    $x += $self->{'tipwidth1'} + $self->{'tip'} + $self->{'column'} + $self->{'tip'};
    my $y = $self->{'bottom'};

    for my $taxon (reverse @taxa2) {
      $self->{'xx'}->{$taxon} = $x + $self->{'tipwidth2'} + $self->{'tip'};
      $self->{'yy'}->{$taxon} = $y;
      $y += $ystep2;
    }
    $x += $self->{'xstep'};

    my @stack;
    my @queue; # postorder traversal
    push @stack, $self->{'t2'}->get_root_node;
    while (@stack) {
      my $node = pop @stack;
      push @queue, $node;
      foreach my $child ($node->each_Descendent(-sortby => 'internal_id')) {
	push @stack, $child;
      }
    }
    @queue = reverse @queue;

    for my $node (@queue) {
      if (!$node->is_Leaf) {
	my @children = $node->each_Descendent;
	my $child = shift @children;
	my $xmax = $self->{'xx'}->{$child};
	my $ymin = my $ymax = $self->{'yy'}->{$child};
	foreach $child (@children) {
	  $xmax = $self->{'xx'}->{$child} if $self->{'xx'}->{$child} > $xmax;
	  $ymax = $self->{'yy'}->{$child} if $self->{'yy'}->{$child} > $ymax;
	  $ymin = $self->{'yy'}->{$child} if $self->{'yy'}->{$child} < $ymin;
	}
	$self->{'xx'}->{$node} = $xmax + $self->{'xstep'};
	$self->{'yy'}->{$node} = ($ymin + $ymax)/2;
      }
    }

  }

}

=head2 _initialize

 Title   : _initialize
 Usage   : *INTERNAL Tree::Draw stuff*
 Function: Assign initial parameters
 Example :
 Returns :
 Args    :

=cut

sub _initialize {
    my $self = shift;
    ( $self->{'t1'}, $self->{'t2'} ) = $self->_rearrange([qw(TREE SECOND)], @_);
    $self->{'xx'} = {}; # horizontal coordinate for each node
    $self->{'yy'} = {}; # vertical coordinate for each node
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
    my ($self) = @_;
    $self->throw("Cannot call method _get_max_tip_witdh on Bio::Tree::Draw object. Must use a subclass.");
}

=head2 _load_format_module

 Title   : _load_format_module
 Usage   : *INTERNAL Tree::Draw stuff*
 Function: Loads up (like use) a module at run time on demand
 Example :
 Returns :
 Args    :

=cut

sub _load_format_module {
  my ($self,$format) = @_;
  my $module = "Bio::Tree::Draw::" . $format;
  my $ok;
  
  eval {
      $ok = $self->_load_module($module);
  };
  if ( $@ ) {
    print STDERR <<END;
$self: $format cannot be found
Exception $@
You likely did not provide a valid format. You can check which formats
are available by looking at the files available under Bio::Tree::Draw.
END
  ;
  }
  return $ok;
}

1;
