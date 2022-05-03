# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# LoremIpsumPlugin is Copyright (C) 2013-2022 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::LoremIpsumPlugin;

use strict;
use warnings;

use Foswiki::Func ();

our $VERSION = '1.01';
our $RELEASE = '03 May 2022';
our $SHORTDESCRIPTION = 'Lorem ipsum generator';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub initPlugin {

  Foswiki::Func::registerTagHandler('LOREM', sub { return getCore()->LOREM(@_); });

  return 1;
}

sub getCore {

  unless (defined $core) {
    require Foswiki::Plugins::LoremIpsumPlugin::Core;
    $core = new Foswiki::Plugins::LoremIpsumPlugin::Core();
  }

  return $core;
}

sub finishPlugin {
  if ($core) {
    $core->finish();
    undef $core;
  }
}

1;
