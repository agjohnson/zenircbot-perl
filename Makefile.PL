use 5.010;

use strict;
use warnings;
use inc::Module::Install;

name 'ZenIRCBot';

perl_version '5.010';

version_from 'lib/ZenIRCBot.pm';
license_from 'lib/ZenIRCBot.pm';
author 'Anthony Johnson <aj@ohess.org>';

homepage 'http://ohess.org/projects/zenircbot-perl';
bugtracker 'http://github.com/agjohnson/zenircbot-perl/issues';
repository 'http://github.com/agjohnson/zenircbot-perl.git';

requires 'AnyEvent::Redis';
requires 'JSON';

WriteAll;
