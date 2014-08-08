package Finance::Quote::Morningstar::AT;
require 5.004;

use strict;

use vars qw($VERSION $MORNINGSTAR_AT_FUNDS_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;

$VERSION = '0.14.6.12'; # 2014-06-12
$MORNINGSTAR_AT_FUNDS_URL = 'http://www.morningstar.at/at/snapshot/snapshot.aspx?id=';

sub methods { return (morningstar_at => \&morningstar_at); }

{
  my @labels = qw/date isodate method source name currency nav/;

  sub labels { return (morningstar_at => \@labels); }
}

sub morningstar_at {
  my $quoter  = shift;
  my @symbols = @_;

  return unless @symbols;
  my ($ua, $reply, $url, %funds, $te, $table, $row, $value, $currency, $name);

  foreach my $symbol (@symbols) {
    $name = $symbol;
    $url = $MORNINGSTAR_AT_FUNDS_URL;
    $url = $url . $name;
    $ua    = $quoter->user_agent;
    $reply = $ua->request(GET $url);
    unless ($reply->is_success) {
	  foreach my $symbol (@symbols) {
        $funds{$symbol, "success"}  = 0;
        $funds{$symbol, "errormsg"} = "HTTP failure";
	  }
	  return wantarray ? %funds : \%funds;
    }

    $te = new HTML::TableExtract();
    $te->parse($reply->content);
    my $counter = 0;
    my $dateset = 0;
    for my $table ($te->tables()) {
	  for my $row ($table->rows()) {
        if (defined(@$row[0])) {
		  if ('NAV' eq substr(@$row[0],0,3) || 'Schluss' eq substr(@$row[0],0,7) ) {
            $value = substr($$row[2],5);
            $value =~ s/,/./g;
            $currency = substr($$row[2],0,3);
            $funds{$name, 'method'}   = 'morningstar_at';
            $funds{$name, 'nav'}    = $value;
            $funds{$name, 'currency'} = $currency;
            $funds{$name, 'success'}  = 1;
            $funds{$name, 'symbol'}  = $name;
            $funds{$name, 'source'}   = 'Finance::Quote::Morningstar::AT';
            $funds{$name, 'name'}   = $name;
            $funds{$name, 'p_change'} = "";  # p_change is not retrieved (yet?)
            my $date = substr(@$row[0],4);
            if ( 'Schluss' eq substr(@$row[0],0,7) ) {
                $date = substr( @$row[0], 12 );
            }
            $date = substr($date,8) . "/" . substr($date,3,2) . "/" . substr($date,0,2);
            $quoter->store_date(\%funds, $name, {isodate => $date});
            $dateset = 1;
		  }
        }
	  }
	  $counter++;
    }

    # Check for undefined symbols
    foreach my $symbol (@symbols) {
	  unless ($funds{$symbol, 'success'}) {
        $funds{$symbol, "success"}  = 0;
        $funds{$symbol, "errormsg"} = "Fund name not found";
	  }
    }
  }
  return %funds if wantarray;
  return \%funds;
}

1;

=head1 NAME

Finance::Quote::Morningstar::AT - Obtain fund prices from
http://Morningstar.AT/

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("morningstar_at","morningstar fund id");

=head1 DESCRIPTION

This module obtains information about fund prices from
www.morningstar.at.

=head1 FUND NAMES

Morningstar.AT's fund IDs (in the URL!)

=head1 LABELS RETURNED

Information available from funds may include the following labels:
date method source name currency nav. The prices are updated at the
end of each bank day.

=head1 SEE ALSO

http://Morningstar.AT/

=cut
