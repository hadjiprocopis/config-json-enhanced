# NAME

Config::JSON::Enhanced - JSON-based config with C/Shell-style comments, verbatim sections and variable substitutions

# VERSION

Version 0.10

# SYNOPSIS

This module provides subroutine `config2perl()` for parsing configuration content,
from files or strings,  based on, what I call, "enhanced JSON" (see section
["ENHANCED JSON FORMAT"](#enhanced-json-format) for more details). Briefly, it is standard JSON which allows:

- `C`-style, `C++`-style, `shell`-style or custom comments.
- Template-style variables (e.g. `<% appdir %>`)
which are substituted with user-specified data during parsing.
- Verbatim sections which are a sort of here-doc for JSON,
allowing strings to span multiple
lines, to contain single and double quotes unescaped,
to contain template-style variables.

This module was created because I needed to include
long shell scripts containing lots of quotes and newlines,
in a configuration file which started as JSON.

The process is simple: so-called "enhanced JSON" is parsed
by [config2perl](https://metacpan.org/pod/config2perl). Comments are removed, variables are
substituted, verbatim sections become one line again
and standard JSON is created. This is parsed with
[JSON](https://metacpan.org/pod/JSON) (via [Data::Roundtrip::json2perl](https://metacpan.org/pod/Data%3A%3ARoundtrip%3A%3Ajson2perl)) to
produce a Perl data structure which is returned.

It has been tested with unicode data
(see `t/070-config2perl-complex-utf8.t`)
with success. But who knows ?!?!

Here is an example:

       use Config::JSON::Enhanced;

       # simple "enhanced" JSON with comments in 3 styles: C,shell,CPP
       my $configdata = <<'EOJ';
        {
           /* 'a' is ... */
           "a" : "abc",
           # b is ...
           "b" : [1,2,3],
           "c" : 12 // c is ...
        }
       EOJ
       my $perldata = config2perl({
           'string' => $configdata,
           'commentstyle' => "C,shell,CPP",
       });
       die "call to config2perl() has failed" unless defined $perldata;
       # the standard JSON:
       # {"a" : "abc","b" : [1,2,3], "c" : 12}


       # this "enhanced" JSON demonstrates the use of variables
       # which will be substituted during the transformation to
       # standard JSON with user-specified data.
       # Notice that the opening and closing tags enclosing variable
       # names can be customised using the 'tags' input parameter,
       # so as to avoid clashes with content in the JSON.
       my $configdata = <<'EOJ';
        {
          "d" : [1,2,<% tempvar0 %>],
          "configfile" : "<%SCRIPTDIR%>/config/myapp.conf",
          "username" : "<% username %>"
           }
        }
       EOJ
       my $perldata = config2perl({
           'string' => $configdata,
           'commentstyle' => "C,shell,CPP",
           # optionally customise the tags enclosing the variables
           # when you want to avoid clashes with other strings in JSON
           #'tags' => ['<%', '%>'], # <<< these are the default values
           # user-specified data to replace the variables in
           # the "enhanced" JSON above:
           'variable-substitutions' => {
               'tempvar0' => 42,
               'username' => getlogin(),
               'SCRIPTDIR' => $FindBin::Bin,
           },
       });
       die "call to config2perl() has failed" unless defined $perldata;
       # the standard JSON
       # (notice how all variables in <%...%> are now replaced):
       # {"d" : [1,2,42],
       #  "username" : "yossarian",
       #  "configfile" : "/home/yossarian/B52/config/myapp.conf"
       # }


       # this "enhanced" JSON demonstrates "verbatim sections"
       # the puprose of which is to make more readable JSON strings
       # by allowing them to span over multiple lines.
       # There is also no need for escaping double quotes.
       # template variables (like above) will be substituted
       # There will be no comments removal from the verbatim sections.
       my $configdata = <<'EOJ';
        {
         "a" : <%begin-verbatim-section%>
         This is a multiline
         string
         "quoted text" and 'quoted like this also'
         will be retained in the string escaped.
         White space from beginning and end will be chomped.
    
         <%end-verbatim-section%>
         ,
         "b" = 123
        }
       EOJ
       my $perldata = config2perl({
           'string' => $configdata,
           'commentstyle' => "C,shell,CPP",
       });
       die "call to config2perl() has failed" unless defined $perldata;
       # the standard JSON (notice that "a" value is in a single line,
       # here printed broken for readability):
       # {"a" :
       #   "This is a multiline\nstring\n\"quoted text\" and 'quoted like
       #   this also'\nwill be retained in the string escaped.\nComments
       #   will not be removed.\nWhite space from
       #   beginning and end will be chomped.",
       #  "b" : 123
       # };

# EXPORT

- `config2perl` is exported by default.

# SUBROUTINES

## `config2perl`

    my $ret = config2perl($params);
    die unless defined $ret;

Arguments:

- `$params` : a hashref of input parameters.

Return value:

- the parsed content as a Perl data structure
on success or `undef` on failure.

Given input content in ["ENHANCED JSON FORMAT"](#enhanced-json-format), this sub removes comments
(as per preferences via input parameters),
replaces all template variables, if any,
compacts ["Verbatim Sections"](#verbatim-sections), if any, into a single-line
string and then parses
what remains as standard JSON into a Perl data structure
which is returned to caller. JSON parsing is done with
[Data::Roundtrip::json2perl](https://metacpan.org/pod/Data%3A%3ARoundtrip%3A%3Ajson2perl), which uses [JSON](https://metacpan.org/pod/JSON).

Comments outside of JSON fields will always be removed,
otherwise JSON can not be parsed.

Comments inside of JSON fields, keys, values, strings etc.
will not be removed unless input parameter `remove-comments-in-strings`
is set to 1 by the caller.

Comments (or what looks like comments with the current input parameters)
inside ["Verbatim Sections"](#verbatim-sections) will never be removed.

The input content to-be-parsed can be specified
with one of the following input parameters (entries in the
`$params`):

- `filename` : content is read from a file with this name.
- `filehandle` : content is read from a file which has already
been opened for reading by the caller.
- `string` : content is contained in this string.

Additionally, input parameters can contain the following keys:

- `commentstyle` : specify what comment style(s) to be expected
in the input content (if any) as a **comma-separated string**. For example
`'C,CPP,shell,custom(<<)(>>),custom(REM)()'`.
These are the values it understands:
    - `C` : comments take the form of C-style comments which
    are exclusively within `/* and */`. For example `* I am a comment */`.
    This is the **default comment style** if none specified.
    - `CPP` : comments can the the form of C++-style comments
    which are within `/* and */` or after `//` until the end of line.
    For example `/* I am a comment */`, `// I am a comment to the end of line`.
    - `shell` : comments can be after `#` until the end of line.
    For example, `# I am a comment to the end of line`.
    - `custom` : comments are enclosed (or preceded) by custom,
    user-specified tags. The form is `custom(OPENINGTAG)(CLOSINGTAG)`.
    `OPENINGTAG` is required. `CLOSINGTAG` is optional meaning that
    the comment extends to the end of line (just like `shell` comments).
    For example `custom(<<)(>>)` or 
    `custom({{)(})` or `custom(REM)()` or `custom(<<<<)(>>)`.
    `OPENINGTAG` and `CLOSINGTAG` do not need to be of
    the same character length as it is
    obvious from the previous example. A word of warning:
    the regex for identifying comments (and variables and verbatim sections)
    has the custom tags escaped for special regex characters
    (with the `\Q ... \E` construct). So you are pretty safe in using
    any character. Please report weird behaviour.

        **Warning** : either opening or closing comment tags must not
        be the same as opening or closing variables / verbatim section tags.
- `variable-substitutions` : a hashref whose keys are
variable names as they occur in the input _Enhanced JSON_ content
and their corresponding values should substitute them. _Enhanced JSON_,
can contain template variables in the form `<% my-var-1 %>`. These
must be replaced with data which is supplied to the call of `config2perl()`
under the parameters key `variable-substitutions`, for example:

        config2perl({
          "variable-substitutions" => {
            "my-var-1" => 42,
            "SCRIPTDIR" => "/home/abc",
          },
          "string" => '{"a":"<% my-var-1 %>", "b":"<% SCRIPTDIR %>/app.conf"}',
        });

    Variable substitution will be performed in both
    keys and values of the input JSON, including ["Verbatim Sections"](#verbatim-sections).

- `remove-comments-in-strings` : by default no attempt
to remove what-looks-like-comments from JSON strings
(both keys and values). However, if this flag is set to
`1` anything that looks like comments (as per the '`commentstyle`'
parameter) will be removed from inside all JSON strings
(keys or values) unless they were part of verbatim section.

    This does not apply for the content verbatim sections.
    What looks like comments to us, inside verbatim sections
    will be left intact.

    For example consider the JSON string `"hello/*a comment*/"`
    (which can be a key or a value). If `remove-comments-in-strings` is
    set to 1, then the JSON string will become `hello`. If set to
    0 (which is the default) it will be unchanged.

- `tags` : specify the opening and closing tags for template
variables and verbatim section as an ARRAYref of exactly 2 items (the
opening and the closing tags). By default the opening tag is `>%`
and the closing tag is `%<`. A word of warning:
the regex for identifying variables and verbatim sections (and comments)
has the custom tags escaped for special regex characters
(with the `\Q ... \E` construct). So you are pretty safe in using
any character. Please report weird behaviour.

    If you set `tags =` \[ '\[::', '::\]' \]>
    then your template variables should look like this: `{:: var1 ::]` and
    verbatim sections like this: `[:: begin-verbatim-section ::]`.

- `debug` : set this to a positive integer to increase verbosity
and dump debugging messages. Default is zero for zero verbosity.

See section ["ENHANCED JSON FORMAT"](#enhanced-json-format) for details on the format
of **what I call** _enhanced JSON_.

`config2perl` returns the parsed content as a Perl data structure
on success or `undef` on failure.

# ENHANCED JSON FORMAT

This is JSON with added reasonable, yet completely ad-hoc, enhancements
(from my point of view).

These enhancements are:

- **Comments are allowed**:
    - `C`-style comments take the form of C-style comments which
    are exclusively within `/* and */`. For example `* I am a comment */`
    - `C++`-style comments can the the form of C++-style comments
    which are within `/* and */` or after `//` until the end of line.
    For example `/* I am a comment */`, `// I am a comment to the end of line.`
    - `shell`-style comments can be after `#` until the end of line.
    For example, `# I am a comment to the end of line.`
    - comments with `custom`, user-specified, opening and
    optional closing tags
    which allows fine-tuning the process of deciding on something being a
    comment.
- **Template variables support** : template-style
variables in the form of `<% HOMEDIR %>`
will be substituded with values specified by the
user during parsing. Note that variable
names are case sensitive, they can contain spaces, hyphens etc.,
for example: `<%   abc- 123 -  xyz   %>` (the variable
name is `abc- 123 -  xyz`, notice
the multiple spaces between `123` and `xyz` and
also notice the absence of any spaces before `abc` and after `xyz`).

    The tags for denoting a template variable
    are controled by the '`tags`' parameter to the sub [config2perl](https://metacpan.org/pod/config2perl).
    Defaults are `<%` and `%>`.

- **Verbatim Sections** : similar to here-doc, this feature allows
for string values to span over multiple lines and to contain
un-escpaed quotes. This is useful if you want a JSON value to
contain a shell script, for example. Verbatim sections can
also contain template variables which will be substituted. No
comment will be removed.
- Unfortunately, there is not support for ignoring **superfluous commas** in JSON,
in the manner of glorious Perl.

    **Warning** : either opening or closing comment tags must not
    be the same as opening or closing variables / verbatim section tags.

## Verbatim Sections

A **Verbaitm Section** in this ad-hoc, so-called _Enhanced JSON_ is content
enclosed within `<%begin-verbatim-section%>`
and `<%end-verbatim-section%>` tags.
A verbatim section's content may span multiple lines (which when converted to JSON will preserve them
by escaping. e.g. by replacing them with '`\n`') and can
contain template variables to be substituted with user-specified data.
All single and double quotes can be left un-escaped, the program will
escape them (hopefully correctly!).

The content of Verbatim Sections will have all its
template variables substituted. Comments will
be left untouched.

The tags for denoting the opening and closing a verbatim section
are controled by the '`tags`' parameter to the sub [config2perl](https://metacpan.org/pod/config2perl).
Defaults are `<%` and `%>`.

Here is an example of enhanced JSON which contains comments, a verbatim section
and template variables:

    my $con = <<'EOC';
    {
      "long bash script" : ["/usr/bin/bash",
    /* This is a verbatim section */
    <%begin-verbatim-section%>
      # save current dir, this comment remains
      pushd . &> /dev/null
      # following quotes will be escaped
      echo "My 'appdir' is \"<%appdir%>\""
      echo "My current dir: " $(echo $PWD) " and bye"
      # go back to initial dir
      popd &> /dev/null
    <%end-verbatim-section%>
    /* the end of the verbatim section */
      ],
      // this is an example of a template variable
      "expected result" : "<% expected-res123 %>"
    }
    EOC

    # Which, can be processed thusly:
    my $res = config2perl({
      'string' => $con,
      'commentstyle' => 'C,CPP',
      'variable-substitutions' => {
        'appdir' => Cwd::abs_path($FindBin::Bin),
        'expected-res123' => 42
      },
    });
    die "call to config2perl() has failed" unless defined $res;

    # following is the dump of $res, note the breaking of the lines
    # in the 'long bash script' is just for readability.
    # In reality, it is one long line:
    {
      "expected result" => 42,
      "long bash script" => [
        "/usr/bin/bash",
        "# save current dir, this comment remains\npushd . &> /dev/null\n
         # following quotes will be escaped\necho \"My 'appdir' is
         \\\"/home/babushka/Config-JSON-Enhanced/t\\\"\"\n
         echo \"My current dir: \" \$(echo \$PWD) \" and bye\"\n# go back to
         initial dir, this comment remains\npopd &> /dev/null"
      ]
    };

A JSON string can contain comments which
you may want to retain (note:
comments filtering will not apply to verbatim sections).

For example if the
content is a unix shell script it is
possible to contain comments like `# comment`.
These will be removed along with all other comments
in the entire JSON input if you are using
`shell` style comments. Another problem
is when JSON string contains comment opening
or closing tags. For example consider this
cron spec : `*/15 * * * *` which contains
the closing string of a C-style comment and
will cass a big mess.

You have two options
in order to deal with this problem:

- Set 'remove-comments-in-strings'
parameter to sub [config2perl](https://metacpan.org/pod/config2perl) to 0. This will
keep ALL comments in all strings (both keys and values).
This is a one-size-fits-all solution and it is not ideal.
- The **best solution** is to change the comment style
of the input, so called Enhanced, JSON to something
different to the comments you are trying to keep in your
strings. So, for example, if you want to retain the comments
in a unix shell script then use C as the comment style for
the JSON.

    Note that it is possible (since version 0.03) to
    use custom tags for comments. This greatly increases
    your chances to make [config2perl](https://metacpan.org/pod/config2perl) understand what
    comments you want to keep as part of your data.

    For example, make your comments like `[::: comment :::]`
    or even like `<!-- comment -->` using
    `'commentstyle' => 'custom([:::)(:::])'`
    and `'commentstyle' => 'custom(<!--)(-->)'`,
    respectively.

# TIPS

You can change the tags used in denoting the template variables
and verbatim sections with the `tags` parameter to the
sub [config2perl](https://metacpan.org/pod/config2perl). Use this feature to change tags
to something else if your JSON contains
the same character sequence for these tags and avoid clashes
and unexpected substitutions. `<%` and `%>` are the default
tags.

Similarly, `custom` comment style (specifying what should be
the opening and, optionally, closing tags) can be employed if your
JSON strings contain something that looks like comments
and you want to avoid their removal.

# WARNINGS/CAVEATS

In order to remove comments within strings, a simplistic regular
expression for
extracting quoted strings is employed. It finds anything
within two double quotes. It tries to handle escaped quotes within
quoted strings.
This regex may be buggy or may not
be complex enough to handle all corner cases. Therefore, it is
possible that setting parameter `remove-comments-in-strings` to 1
to sub [config2perl](https://metacpan.org/pod/config2perl) to cause unexpected results. Please
report these cases, see [SUPPORT](https://metacpan.org/pod/SUPPORT).

The regex for identifying comments, variables and verbatim sections
has the custom tags escaped for special regex characters
(with the `\Q ... \E` construct). So you are pretty safe in using
any character. Please report weird behaviour.

# AUTHOR

Andreas Hadjiprocopis, `<bliako at cpan.org>`

# HUGS

! Almaz !

# BUGS

Please report any bugs or feature requests to `bug-config-json-enhanced at rt.cpan.org`, or through
the web interface at [https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Config-JSON-Enhanced](https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Config-JSON-Enhanced).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Config::JSON::Enhanced

You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

    [https://rt.cpan.org/NoAuth/Bugs.html?Dist=Config-JSON-Enhanced](https://rt.cpan.org/NoAuth/Bugs.html?Dist=Config-JSON-Enhanced)

- Review this module at PerlMonks

    [https://www.perlmonks.org/?node\_id=21144](https://www.perlmonks.org/?node_id=21144)

- Search CPAN

    [https://metacpan.org/release/Config-JSON-Enhanced](https://metacpan.org/release/Config-JSON-Enhanced)

# ACKNOWLEDGEMENTS

# LICENSE AND COPYRIGHT

This software is Copyright (c) 2023 by Andreas Hadjiprocopis.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
