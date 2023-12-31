#!perl

use 5.010;
use strict;
use warnings;

use Test::More;
use Test2::Plugin::UTF8; # rids of the Wide Character in TAP message!
use FindBin;
use Cwd qw/abs_path/;

our $VERSION = '0.08';

use Config::JSON::Enhanced;

# this json is in the module's pod
# Testing it works
my $con = <<'EOJ';
  {
    "long bash script" : ["/usr/bin/bash",
  /* This is a verbatim section */
  <%begin-verbatim-section%>
    pushd . &> /dev/null
    echo "My 'appdir' is \"<%appdir%>\""
    echo "My current dir: " $(echo $PWD) " and bye"
    popd &> /dev/null
    ],
    // this is an example of a template variable
    "expected result" : "<% expected-res123 %>"
  }
EOJ

my $json = config2perl({
	'string' => $con,
	'commentstyle' => 'C,CPP',
	'variable-substitutions' => {
		'appdir' => Cwd::abs_path($FindBin::Bin),
		'expected-res123' => 42
	},
});
ok(!defined $json, 'config2perl()'." : called and got defined result.") or BAIL_OUT;

done_testing();
