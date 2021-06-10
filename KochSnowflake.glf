#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

############################################################################
# Generate an unstructured domain for a Koch Snowflake fractal.
# Create the boundary as database lines.  Starting with an equilateral 
# triangle, iterative replace the middle third of each edge with another 
# equilateral triangle.  Create a domain from connectors on the perimeter 
# and then mesh it.
############################################################################

package require PWI_Glyph 2.3
pw::Application reset

##############################
# User Customizable Parameters
##############################
# edge lengths of initial equilateral triangle
set L 10
# maximum number of levels to iterate (after 5 it gets really slow)
set iMax 3
# number of grid points on each edge of the resulting shape
set numGPperEdge 3
# maximum triangle edge length on unstructured domain interior relative 
# to spacing on perimeter
set maxTriFactor 5
# boundary decay factor for uns dom 
# (pushes clustering farther into interior)
set decay 0.8
# domain color
set domColor 0x00c0fff

# degree-radian conversion factors
set d2r [expr 3.141592653589793238 / 180]
set r2d [expr 180 / 3.141592653589793238 ]

############################################################################
# Create a database line entity between two points.
proc makeLine { A B } {
   set seg [pw::SegmentSpline create]
   $seg addPoint $A
   $seg addPoint $B
   set E [pw::Curve create]
   $E addSegment $seg
   unset seg
   return $E
}

############################################################################
# MAIN
############################################################################

# Make the initial triangle

set rads [expr 60 * $d2r]
set d [expr $L * sin($rads)]
set e [expr $L * cos($rads)]
 
set A [list 0 0 0]
set B [list [expr 0 + $e] $d 0]
set C [list [expr 0 - $e] $d 0]

makeLine $A $B
makeLine $B $C
makeLine $C $A

pw::Display resetRotationPoint
pw::Display resetView -Z
pw::Display update

# Iteratively insert new triangles in the middle of each edge

for {set i 0} {$i<$iMax} {incr i} {
   foreach e [pw::Database getAll] {
      # split the edge in thirds
      set Edges [$e split [list .333 .666]]
      set e1 [lindex $Edges 0]
      set e2 [lindex $Edges 1]
      set e3 [lindex $Edges 2]
      # get length of middle third then delete it
      set L [$e2 getLength -arc 1]
      pw::Entity delete $e2
      
      # define points at either end of gap
      set A [$e1 getXYZ -arc 1]
      set Ax [lindex $A 0]
      set Ay [lindex $A 1]
      set Az [lindex $A 2]
      set C [$e3 getXYZ -arc 0]
      set Cx [lindex $C 0]
      set Cy [lindex $C 1]
      set Cz [lindex $C 2]

      # midpoint of gap
      set dx [expr $Cx - $Ax]
      set dy [expr $Cy - $Ay]
      set Mx [expr $Ax + $dx/2]
      set My [expr $Ay + $dy/2]
      set Mz 0

      # angle of edge and height of new triangle
      set alpha [expr atan( $dy / $dx )]
      # puts "   alpha = [expr $alpha * $r2d]"
      set h [expr $L * sqrt(3)/2]

      # temp point B1
      set B1x $Mx
      if { $dx < 0 } {
         set B1y [expr $My + $h]
      } else {
         set B1y [expr $My - $h]
      }
      set B1z 0

      # create line from midpoint to temp point, then rotate it
      set MB [makeLine [list $Mx $My $Mz] [list $B1x $B1y $B1z]]
      pw::Entity transform [pwu::Transform rotation -anchor [list $Mx $My 0] {0 0 1} [expr $alpha * $r2d]] $MB

      # make new triangle edges
      set B [$MB getXYZ -arc 1]
      set Bx [lindex $B 0]
      set By [lindex $B 1]
      set Bz [lindex $B 2]
      makeLine [list $Ax $Ay $Az] [list $Bx $By $Bz]
      makeLine [list $Bx $By $Bz] [list $Cx $Cy $Cz]

      # delete the extra line
      pw::Entity delete $MB

      # update the display at the end of an iteration
      pw::Display resetView -Z
      pw::Display update
   }
}

# rename all the database ilnes 
set DB [pw::Database getAll]
set dbCollection [pw::Collection create]
$dbCollection set $DB
$dbCollection do setName {Koch}
$dbCollection delete

# set meshing parameters
# L is the last edge length from iterations above
set maxTri [expr $L / $numGPperEdge * $maxTriFactor * max($iMax,1)]
# create an uns dom 
pw::Connector setDefault Dimension $numGPperEdge
set Cons [pw::Connector createOnDatabase -merge 0 $DB]
set Dom [pw::DomainUnstructured createFromConnectors $Cons]
# apply the uns solver to the dom
set solverMode [pw::Application begin UnstructuredSolver $Dom]
   $Dom setUnstructuredSolverAttribute EdgeMaximumLength $maxTri
   $solverMode run Decimate
   $Dom setUnstructuredSolverAttribute BoundaryDecay $decay
   $solverMode run Refine
$solverMode end

# make a nice picture
pw::Display setShowConnectors 0
pw::Display setShowNodes 0
pw::Display setShowDatabase 0
pw::Display setShowBodyAxes 0
pw::Display resetView -Z
$Dom setRenderAttribute ColorMode Entity
$Dom setColor $domColor

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
