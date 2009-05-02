#!/usr/bin/perl -w
use Test::More tests => 17;
use HTTP::Request::Common;
use Test::Differences;

my $original_formatter
  ;    # used to save/restore whatever formatter is set up in mojomojo.db
my $c;       # the Catalyst object of this live server
my $test;    # test description

BEGIN {
    $ENV{CATALYST_CONFIG} = 't/var/mojomojo.yml';
    use_ok('MojoMojo::Formatter::Textile')
      and note(
'Comprehensive/chained test of formatters, with the main formatter set to Textile'
      );
    use_ok( 'Catalyst::Test', 'MojoMojo' );
}

END {
    ok( $c->pref( main_formatter => $original_formatter ),
        'restore original formatter' );
}

( undef, $c ) = ctx_request('/');
ok( $original_formatter = $c->pref('main_formatter'),
    'save original formatter' );

ok( $c->pref( main_formatter => 'MojoMojo::Formatter::Textile' ),
    'set preferred formatter to Textile' );

my $content = '';
my $body = get( POST '/.jsrpc/render', [ content => $content ] );
is( $body, 'Please type something', 'empty body' );

#----------------------------------------------------------------------------
$test = 'headings';

#----------------------------------------------------------------------------
$content = <<'TEXTILE';
h1. Welcome to MojoMojo!

This is your front page. Create
a [[New Page]] or edit this one 
through the edit link at the bottom.

h2. Need some assistance?

Check out our [[Help]] section.
TEXTILE
$body = get( POST '/.jsrpc/render', [ content => $content ] );
is( $body, <<'HTML', $test );
<h1>Welcome to MojoMojo!</h1>

<p>This is your front page. Create<br />
a <span class="newWikiWord">New Page<a title="Not found. Click to create this page." href="/New_Page.edit">?</a></span> or edit this one <br />
through the edit link at the bottom.</p>

<h2>Need some assistance?</h2>

<p>Check out our <a class="existingWikiWord" href="/help">Help</a> section.</p>
HTML

$test = 'Test > in <pre lang="HTML"> section.';
# The behavior of this test is different from what appears on the page
# when browsing. > is maintained in the test while it's encoded as &gt; in the page.
# I don't see the encoding as un-desirable here.
$content = <<'TEXTILE';
<pre lang="Perl">
if (1 > 2) {
  print "test";
}
</pre>
TEXTILE
$body = get( POST '/.jsrpc/render', [ content => $content ] );
is( $body, <<'HTML', $test );
<pre>
<b>if</b>&nbsp;(<span class="kateFloat">1</span>&nbsp;>&nbsp;<span class="kateFloat">2</span>)&nbsp;{
&nbsp;&nbsp;<span class="kateFunction">print</span>&nbsp;<span class="kateOperator">"</span><span class="kateString">test</span><span class="kateOperator">"</span>;
}
</pre>
HTML

#----------------------------------------------------------------------------
$test = "Have <pre> sections behave like normal pre sections.  Don't do entities
on < and > so one can use <span> and such";
# The behavior of this test is different from what appears on the page
# when browsing. > is maintained in the test while it's encoded in the page.
$content = <<'TEXTILE';
<pre>
<span>
if (1 < 2) {
  print "pre section & no lang specified";
}
</span>
</pre>
TEXTILE
$body = get( POST '/.jsrpc/render', [ content => $content ] );
is( $body, $content, $test );

#----------------------------------------------------------------------------
$test = 'Is <br /> preserved?';

# NOTE: Textile turns \n in to <br /> so you don't need or want to do
# blab
# <br /> blah because you'll end up with:
# blab
# <br /><br />blah
$content = <<'TEXTILE';
Roses are red<br />Violets are blue
TEXTILE
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>Roses are red<br />Violets are blue</p>
HTML


# This test is asking for a bit much perhaps.  Use <pre lang="code"> </pre> instead.
#----------------------------------------------------------------------------
$test = '<code> behave like normal wrt to <span> - Use textile escape ==';
$content = <<'TEXTILE';
==<code><span style="font-size: 1.5em;">alguna cosa</span></code>
==
TEXTILE
$body = get(POST '/.jsrpc/render', [content => $content]);
eq_or_diff($body, <<'HTML', $test);
<code><span style="font-size: 1.5em;">alguna cosa</span></code>
HTML

# Check that @ transforms to <code>
#----------------------------------------------------------------------------
$test = '@word@ behavior';
$content = <<'TEXTILE';
@mot@
TEXTILE
$body = get(POST '/.jsrpc/render', [content => $content]);
eq_or_diff($body, <<'HTML', $test);
<p><code>mot</code></p>
HTML

#----------------------------------------------------------------------------
$test = 'blockquotes';

#----------------------------------------------------------------------------
$content = <<'TEXTILE';
Below is a blockquote:

bq. quoted text

A quote is above.
TEXTILE
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>Below is a blockquote:</p>

<blockquote><p>quoted text</p></blockquote>

<p>A quote is above.</p>
HTML

#----------------------------------------------------------------------------
$test = 'Handle # as first character in a line while using Perl highlight';

# TODO: This test demonstrates that Syntax Highlight is adding an empty span.
#       Investigate further and clean it up.
$content = <<'TEXTILE';
<pre lang="Perl">
# comment
</pre>
TEXTILE
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<pre>
<span class="kateComment"><i>#&nbsp;comment</i></span><span class="kateComment"><i>
</i></span></pre>
HTML

#----------------------------------------------------------------------------
$test = 'Simple html table tags. Use textile escape ==';
# NOTE: The opening escape string '==' turns into a \n when textile
#       is applied.  colgroup was moved as it confused Defang.
$content = <<'TEXTILE';
==<table>
    <tr>
      <th>Vegetable</th>
    </tr>
    <tr>
      <td>Mr Potato</td>
    </tr>
</table>
==
TEXTILE

$expected = <<'HTML';
<table>
    <tr>
      <th>Vegetable</th>
    </tr>
    <tr>
      <td>Mr Potato</td>
    </tr>
</table>
HTML
# We expect textile to leave this table as is, EXCPEPT for the escape lines (==).
$body = get( POST '/.jsrpc/render', [ content => $content ] );
is( $body, $expected, $test );


#----------------------------------------------------------------------------
$test = 'Maintain complete set of html table tags. Use textile escape ==';
# NOTE: The opening escape string '==' turns into a \n when textile
#       is applied.  colgroup was removed as it confused Defang.
$content = <<'TEXTILE';
==<table>
<caption>Vegetable Price List</caption>
<thead>
    <tr>
      <th>Vegetable</th>
      <th>Cost per kilo</th>
    </tr>
</thead>
<tbody>
    <tr>
      <td>Lettuce</td>
      <td>$1</td>
    </tr>
    <tr>
      <td>Silver carrots</td>
      <td>$10.50</td>
    </tr>
    <tr>
      <td>Golden turnips</td>
      <td>$108.00</td>
    </tr>
</tbody>
</table>
==
TEXTILE

$expected = <<'HTML';
<table>
<caption>Vegetable Price List</caption>
<thead>
    <tr>
      <th>Vegetable</th>
      <th>Cost per kilo</th>
    </tr>
</thead>
<tbody>
    <tr>
      <td>Lettuce</td>
      <td>$1</td>
    </tr>
    <tr>
      <td>Silver carrots</td>
      <td>$10.50</td>
    </tr>
    <tr>
      <td>Golden turnips</td>
      <td>$108.00</td>
    </tr>
</tbody>
</table>
HTML
# We expect textile to leave this table as is, EXCPEPT for the escape lines (==).
$body = get( POST '/.jsrpc/render', [ content => $content ] );
is( $body, $expected, $test );


#-------------------------------------------------------------------------------
$test = 'POD while Textile is the main formatter';
$content = <<'TEXTILE';
{{pod}}

=head1 NAME

Some POD here

=cut

{{end}}
TEXTILE
$body = get( POST '/.jsrpc/render', [ content => $content ] );
like($body, qr'<h1><a.*NAME.*/h1>'s, "POD: there is an h1 NAME");