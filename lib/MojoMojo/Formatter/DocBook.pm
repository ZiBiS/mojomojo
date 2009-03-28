package MojoMojo::Formatter::DocBook;

use base qw/MojoMojo::Formatter/;

use XML::LibXSLT;
use XML::SAX::ParserFactory (); # loaded for simplicity;
use HTML::Entities;
use XML::LibXML::Reader;
use MojoMojo::Formatter::DocBook::Colorize;

my $xsltfile="/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/xhtml/docbook.xsl";
my $debug=0;

=head1 NAME

MojoMojo::Formatter::DocBook - format part of content as DocBook

=head1 DESCRIPTION

This formatter will format content between two =docbook blocks as 
DocBook document.

=head1 METHODS

=over 4

=item format_content_order

Format order can be 1-99. The Pod formatter runs on 10

=cut

sub format_content_order { 12 }

=item format_content

calls the formatter. Takes a ref to the content as well as the
context object.

=cut

sub format_content {
    my ( $class, $content, $c ) = @_;

    my @lines = split /\n/, $$content;
    my $dbk;
    $$content = "";
    foreach my $line (@lines) {

        if ($dbk) {
            if ( $line =~ m/^=docbook\s*$/ ) {
                $$content .= MojoMojo::Formatter::DocBook->to_dbk( $dbk );
                $dbk = "";
            }
            else { $dbk .= $line . "\n"; }
        }
        else {
            if ( $line =~ m/^=docbook\s*$/ ) {
                $dbk = " ";    # make it true :)
            }
            else { $$content .= $line . "\n"; }
        }
    }

    return $$content;
}


=item to_dbk <dbk>

takes DocBook documentation and renders it as HTML.

=cut

sub to_dbk {
    my ( $class, $dbk ) = @_;
    my $result;

    $dbk =~ s/^\s//;
    # 1 - Mark lang 
    # <programlisting lang="..."> to <programlisting lang="...">[lang=...] code [/lang]
    my $my_Handler = MojoMojo::Formatter::DocBook::Colorize->new($debug);
    $my_Handler->step('marklang');

    my $parsersax = XML::SAX::ParserFactory->parser(
                                                    Handler => $my_Handler,
                                                );

    my @markeddbk = eval{ $parsersax->parse_string($dbk)};
    if ($@) {
        return "\nDocument malformed : $@\n" ;
    }
    ;


    # 2 - Transform with xslt
    my $parser = XML::LibXML->new();
    my $xslt   = XML::LibXSLT->new();

    my $source = eval {$parser->parse_string("@markeddbk")};


    if ($@) {
        return "\nDocument malformed : line $@\n" ;
    }
    ;


    my $style_doc = $parser->parse_file($xsltfile);
    my $stylesheet = 
      eval {
          $xslt->parse_stylesheet($style_doc);
      };

    #warn "@_" if @_;



    # C'est ici que l'on peut ajouter le css, LANG ...
    # voir http://docbook.sourceforge.net/release/xsl/current/doc/html/index.html
    # et   http://www.sagehill.net/docbookxsl
    my $results = $stylesheet->transform($source, XML::LibXSLT::xpath_to_string('section.autolabel' => '1', 'chapter.autolabel' => '1', 'suppress.navigation' => '1'));


    my $format=0;

    my $string=$results->toString($format);

    # 3 - Colorize Code [lang=...] ... code ... [/lang]
    $my_Handler->step('colorize');

    my @colorized=$parsersax->parse_string($string);

    $string="@colorized";


    # 4 - filter
    # To adapt to mojomojo
    # delete <?xml version ...>, <html>,</html>,<head>,</head>,<body>,</body>
    $string =~ s/^.*<body>//s;
    $string =~ s/<\/body>.*<\/html>//s;

    $string =~ s/clear:\sboth//g;

    return $string . "\n";;
}




=back

=head1 SEE ALSO

L<MojoMojo>,L<Module::Pluggable::Ordered>

=head1 AUTHORS

Daniel Brosseau <dab@catapulse.org>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.

=cut

1;
