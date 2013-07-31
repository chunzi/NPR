package NPR::Transcript;
use strict;
use HTTP::Tiny;
use XML::Tiny::Simple qw/ parsestring /;
use Class::Date qw/ date /;
use Text::Trim;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw/
    doc
/);

sub new { 
    my $class = shift;
    my $id = shift;
    my $self = bless {}, $class;

    my $url = sprintf 'http://api.npr.org/transcript?id=%s&apiKey=MDExMTA1NDUwMDEzNjQyNjc4NDFmZjZkOA001', $id;
    my $res = HTTP::Tiny->new->get($url);
    die "Failed wget $url\n" unless $res->{success};

    my $xml = $res->{content};
    my $doc = parsestring($xml);
    $self->doc( $doc );

    my $story_url = $doc->{transcript}{story}{link}[0]{content};
    my ( $yy, $mm, $dd, $sid, $slug ) = ( $story_url =~ m{\.org/(.*?)/(.*?)/(.*?)/(.*?)/(.*)$} );
    my $day = date [$yy, $mm, $dd];

    # printf "%s: %s - %s\n", $sid, $day->ymd, $slug;

    return $self;
}

sub paras {
    my $self = shift;
    my @paras = map { $_->{content} } @{ $self->doc->{transcript}{paragraph} };

    my @paras_new;
    my $speaker_previous = '';
    for my $para ( @paras ){
        my $speaker; 
        my $words; 

        if ( $para =~ /:/ ){
            ( $speaker, $words ) = map { trim } ( $para =~ /^([^a-z]*?):(.*)/ );
            if ( not defined $speaker ){
                $speaker = $speaker_previous;
            }
            next if not defined $words;

        }else{
            $words = $para;
        }

        my $background = ( $words =~ /^\(.*?\)$/ ) ? 1 : 0; 

        push @paras_new, { speaker => $speaker, words => $words, background => $background };
    }

    return \@paras_new;
}



1;
