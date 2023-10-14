#! /usr/bin/perl

############################################################################
# Script to extract the metadata from BG3 mod .pak files that are needed for
# manual addition to 'modsettings.lsx'.  The only argument is the path to
# the module .pak file.  Intended for us poor Mac users, as it should run
# on a Mac without any other dependencies.  It also doesn't use any externally
# licensed code, so have at it...
#
# This script is given as arguments the .pak files in the BG3 Mod folder,
# the default game .pak (Gustav,pak), and an existing modsettings.lsx file.
# Upon completion, it outputs a new modsettings.lsx file.  To use it, you need
# overwrite the existing modsettings.lsx file.  You can edit the mod order in
# the “ModOrder” section of the file before saving, if desired.
#
# Any mod ordering in an existing modsettings.lsx file that is used will be
# maintained.  If the game “Gustav.pak” is read in, the new “Gustav” entry
# will be generated from it.  If not, any “Gustav” entry in an existing
# modsettings.lsx file that is read in will be preserved.  If neither is done,
# “Gustav” will not be present - probably not good!
############################################################################

# This is free and unencumbered software released into the public domain.

# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.

# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# For more information, please refer to <https://unlicense.org>


use File::Basename;
use Getopt::Long;

my $debug = 0;

# Some constants - there are others embedded! ;)
my $FILE_HDR_LEN = 24;
my $TBL_HDR_LEN = 8;
my $TBL_ENT_LEN = 272;
my @SUP_VER = (15,18);
my $GAME_PAK = "Gustav.pak";

# Sanity check provided file
if (!@ARGV) {
  die("No filename provided!");
}

my %pakInfo;
my $modSet;
my @mods;
foreach my $fileName (@ARGV) {
  my $bname = basename($fileName);
  if ($bname =~ m/[.]pak$/) {
    if (! -R $fileName) {
      die("'$ARGV[0]' can't be read!");
    }
    $pakInfo{$bname} = getMeta4Pak($fileName);
    push(@mods, $bname);
  }
  elsif ($fileName =~ m/modsettings[.]lsx/) {
    if (! -R $fileName) {
      die("'$ARGV[0]' can't be read!");
    }
    $modSet = getModSet($fileName);
    $modSet->{"fileName"} = $fileName;
    
    if (!defined($pakInfo{$GAME_PAK}) && $modSet->{"GustavDev"}) {
      unshift(@mods, $GAME_PAK);
      $pakInfo{$GAME_PAK} = $modSet->{"GustavDev"};
    }
  }
  else {
    print(STDERR "Warning: ignoring unknown file type: '$fileName'\n");
  }
}

# Default modsettings, if one not passed in
if (!defined($modSet)) {
  $modSet = {};
  $modSet->{"setLines"} = getDefModSet();
  $modSet->{"UUIDS"} = [];
}

# Create module order.  Existing order first, then new of order on command line.
my @modOrder;
foreach my $uuid (@{$modSet->{"UUIDS"}}) {
  foreach my $mod (@mods) {
    if (index($pakInfo{$mod}->{"UUID"}, $uuid) >= 0) {
      push (@modOrder, $mod);
      $pakInfo{$mod}->{"Preorder"} = 1;
    }
  }
}

# Unless already ordered, but game pack first
if (defined($packInfo{$GAME_PAK}) && !$packInfo{$GAME_PAK}->{"Preorder"}) {
  unshift(@modOrder, $GAME_PAK);
  $packInfo{$GAME_PAK}->{"Preorder"} = 1;
}

foreach my $mod (@mods) {
  if (!$pakInfo{$mod}->{"Preorder"}) {
    push (@modOrder, $mod);
  }
}

my $inOrd = 0;
my $inMod = 0;
foreach my $line (@{$modSet->{"setLines"}}) {
  chomp($line);
  if ($line =~ m|</children>|) {
    $inOrd = 0;
    $inMod = 0;
  }
  if ($inOrd < 2 && $inMod < 2) {
    print($line,"\n");
  }
  if ($line =~ m/"ModOrder"/) {
    $inOrd = 1;
  }
  if ($line =~ m/"Mods"/) {
    $inMod = 1;
  }
  if ($line =~ m/<children>/) {
    $inOrd *= 2;
    $inMod *= 2;
  }

  if ($inOrd == 2) {
    foreach my $mod (@modOrder) {
      if ($pakInfo{$mod}->{"UUID"}) {
        print("\n                        <!-- $mod --> \n");
        print('                        <node id="Module">',"\n");
        print("                            ", $pakInfo{$mod}->{"UUID"});
        print("                        </node>\n");
      }
    }
    $inOrd++;
  }

  if ($inMod == 2) {
    foreach my $mod (@modOrder) {
      if ($pakInfo{$mod}->{"UUID"}) {
        print("\n                        <!-- $mod --> \n");
        print('                        <node id="ModuleShortDesc">', "\n");
        print("                            ", $pakInfo{$mod}->{"Folder"});
        print("                            ", $pakInfo{$mod}->{"Name"});
        print("                            ", $pakInfo{$mod}->{"UUID"});
        print("                            ", $pakInfo{$mod}->{"Version"});
        print("                            ", $pakInfo{$mod}->{"MD5"});
        print("                        </node>\n");
      }
    }
    $inMod++;
  }
}

####################
# Reads an existing modsettings file
####################
sub getModSet() {
  my ($fName) = @_;
  my @setLines;
  my @UUIDS = ();
  
  # Open the file
  open(my $setFile, "<", $fName) or die("Can't open '$fName' for reading: $!");

  my $inOrder = 0;
  my $inNode;
  my $node;
  my $gustavDev;
  while (my $line = <$setFile>) {
    push(@setLines, $line);
    if ($line =~ m/"ModOrder"/) {
      $inOrder = 1;
    }
    if ($line =~ m|</children>|) {
      $inOrder = 0;
    }
    if ($inOrder && $line =~ m/"UUID".*value\s*=\s*"([^"]+)"/) {
      push(@UUIDS, $1);
    }

    if ($inNode) {
      $node .= $line;
    }
    if ($line =~ m|<node|) {
      $inNode = 1;
      $node = $line;
    }
    if ($line =~ m|</node>|) {
      $inNode = 0;
      if ($node =~ m|"GustavDev"|) {
        $gustavDev = getModAttr($node,1);
      }
    }
  }
  close($setFile);
  return({"setLines" => \@setLines, "UUIDS" => \@UUIDS, "GustavDev" => $gustavDev});
}

####################
# Gets the metadata from the given .pak file
####################
sub getMeta4Pak() {
  my ($pakName) = @_;
  
  # Open the file
  open(my $pakFile, "<", $pakName) or die("Can't open '$pakName' for reading: $!");
  binmode($pakFile);
  
  # Read the file header
  my $fileHdr;
  if (read($pakFile, $fileHdr, $FILE_HDR_LEN) < $FILE_HDR_LEN) {
    die("Unable to read file header from '$pakName': $!");
  }
  
  # Check ID
  my $id = substr($fileHdr, 0, 4);
  if ($id ne "LSPK") {
    die("Invalid file ID, need 'LSPK', got '$id'!");
  }
  
  # Check version
  my $ver = unpack("L", substr($fileHdr, 4, 4));
  if ($ver < $SUP_VER[0] || $ver > $SUP_VER[1]) {
    print(STDERR "Warning: file version '$ver' is outside of values believed to work [$SUP_VER[0],$SUP_VER[1]]!\n");
  }
  
  # Get table offset
  my $tblOff = unpack("Q", substr($fileHdr, 8, 8));
  
  # Read the table header
  seek($pakFile, $tblOff, SEEK_SET);
  my $tblHdr;
  if (read($pakFile, $tblHdr, $TBL_HDR_LEN) < $TBL_HDR_LEN) {
    die("Unable to read table header from '$pakName': $!");
  }
  my ($numFiles, $tblCmpLen) = unpack("LL", $tblHdr);
  my $tblLen = $numFiles * $TBL_ENT_LEN;
  
  # Read in the (compressed) table entries
  my $cmpTblEnts;
  if (read($pakFile, $cmpTblEnts, $tblCmpLen) < $tblCmpLen) {
    die("Unable to read table entries from '$pakName': $!");
  }
  
  if ($debug > 5) {
    open(my $of, ">", "ctbl.bin");
    print($of $cmpTblEnts);
    close($of);
  }
  
  # Uncompress the table entries
  my $tblEntsRef = lz4Uncmp(\$cmpTblEnts, $tblCmpLen);
  
  if ($debug > 5) {
    open($of, ">", "uctbl.bin");
    print($of ${$tblEntsRef});
    close($of);
  }
  
  # Iterate through the files, looking for "meta.lsx".
  my $fOfst = 0;
  my $fcLen = 0;
  my $fLen = 0;
  for (my $i = 0; $i < $numFiles; $i++) {
    my $entOff = $i * $TBL_ENT_LEN;
    my $fName = unpack("Z*", substr(${$tblEntsRef}, $entOff, $TBL_ENT_LEN));
    if ($debug > 1) {
      print("File $i = $fName\n");
    }
    if ($fName =~ m/meta.lsx$/) {
      $entOff += 256;
      $fOfst = unpack("Q", substr(${$tblEntsRef}, $entOff, 8)) & 0x00ffffffffffffff;
      $fcLen = unpack("L", substr(${$tblEntsRef}, $entOff + 8, 4));
      $fLen = unpack("L", substr(${$tblEntsRef}, $entOff + 12, 4));
      if ($debug > 2) {
        printf("$i offset/cmplen/len = 0x%x/0x%x/0x%x\n", $fOfst, $fcLen, $fLen);
      }
      last;
    }
  }
  
  # Couldn't find it!
  if (!$fOfst) {
    print(STDERR "Warning: Was not able to find 'meta.lsx' in '$pakName'!\n");
  }
  
  # Now read the file
  seek($pakFile, $fOfst, SEEK_SET);
  my $rawFile;
  if (read($pakFile, $rawFile, $fcLen) < $fcLen) {
    die("Unable to read 'meta.lsx' file from '$pakName': $!");
  }
  close($pakFile);
  
  my $ucFile;
  if (!$fLen) {
    $ucFile = unpack("a$fcLen", $rawFile);
  }
  else {
    my $cfRef = lz4Uncmp(\$rawFile, $fcLen);
    $ucFile = unpack("a$fLen", ${$cfRef});
  }
  
  if ($debug > 0) {
    print("\nmeta.lsx:\n$ucFile\n\n");
  }
  
  my $info = getModAttr($ucFile,0);
  
  return($info);
}

####################
# Default setting template if one not read in
####################
sub getDefModSet() {
  # Default modsettings, if one not passed in
  my $tmpSet = << 'ENDHERE';
<?xml version="1.0" encoding="UTF-8"?>
<save>
    <version major="4" minor="3" revision="0" build="300"/>
    <region id="ModuleSettings">
        <node id="root">
            <children>
                <node id="ModOrder">
                    <children>
                    </children>
                </node>
                <node id="Mods">
                    <children>
                    </children>
                </node>
            </children>
        </node>
    </region>
</save>
ENDHERE
  @tmpSet = split(/\n/,$tmpSet);
  return(\@tmpSet);
}

####################
# Parse mod attributes from string
####################
sub getModAttr() {
  my ($attrStr, $mode) = @_;
  my $gotModInfo = 0;
  my %seenAttr;
  my %info;
  my $attrKey = $mode ? "ModuleShortDesc" : "ModuleInfo";
  while ($attrStr =~ m/<([^>]*)>/g) {
    my $attr = $1;
    if ($attr =~ m/$attrKey/) {
      $gotModInfo = 1;
    }
    if ($gotModInfo && $attr =~ m/"(Folder|MD5|Name|UUID|Version)/) {
      my $keyword = $1;
      if (!$seenAttr{$keyword}) {
        $info{$keyword} = "<$attr>\n";
      }
      $seenAttr{$keyword} = $attr;
    }
  }
  return(\%info);
}



####################
# Simple LZ4 uncompressor.  No header - starts with the data block:
# https://github.com/lz4/lz4/blob/dev/doc/lz4_Block_format.md
####################
sub lz4Uncmp() {
  my ($inD, $inDLen) = @_;
  my $outD;
  my $ip = 0;
  
  while ($ip < $inDLen) {
    my $ib=getByte($inD, $ip++);

    # Process a token
    my $litLen = ($ib & 0xf0) >> 4;
    my $mtchLen = ($ib & 0x0f);

    # Process literals
    $ip = lz4Lits($litLen, $inD, $ip, \$outD);

    # Process matches.  By definition, last token has no match.
    if ($ip < $inDLen) {
      $ip = lz4Mtch($mtchLen, $inD, $ip, \$outD);
    }

  }
  return(\$outD);
}

####################
# Handle any literals
####################
sub lz4Lits() {
  my ($len, $inD, $ip, $outD) = @_;
  if ($len) {
    # More length to go?
    if ($len == 15) {
      do {
        my $ib = getByte($inD, $ip++);
        $len += $ib;
      } while ($ib == 0xff);
    }

    # Now copy over the literals
    ${$outD} .= substr(${$inD}, $ip, $len);
    $ip += $len;    
  }
  return($ip);
}

####################
# Handle any matches
####################
sub lz4Mtch() {
  my ($len, $inD, $ip, $outD) = @_;
  
  # Match offset
  my $ofst = unpack("S", substr(${$inD}, $ip, 2));
  $ofst *= -1; # Indexes from the end of out data
  $ip +=2;

  # Process match copy
  $len += 4;
  # More length to go?
  if ($len == 19) {
    do {
      my $ib = getByte($inD, $ip++);
      $len += $ib;
    } while ($ib == 0xff);
  }
  
  # Now copy over the matches (can overlap with itself)
  for (my $i = 0; $i < $len; $i++) {
    ${$outD} .= substr(${$outD}, $ofst, 1);
  }
  return($ip);
}

####################
# Return one byte at pos
####################
sub getByte() {
  return(unpack("C", substr(${$_[0]}, $_[1], 1)));
}
