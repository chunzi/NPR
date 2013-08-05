package NPR::Query;
use strict;
use HTTP::Tiny;
use JSON;
use Class::Date qw/ date /;
use DateTime::Format::RSS;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(
    qw/
        id url title teaser rss
        stories
        /
);

sub new {
    my $class = shift;
    my $id    = shift;
    my $self  = bless {}, $class;
    $self->id($id);

    my $url = sprintf 'http://api.npr.org/query?id=%s&fields=title,storyDate,transcript&dateType=story&sort=dateDesc&output=JSON&apiKey=MDExMTA1NDUwMDEzNjQyNjc4NDFmZjZkOA001', $id;
    $self->url($url);

    my $res = HTTP::Tiny->new->get($url);
    die "Failed wget $url\n" unless $res->{success};

    my $json = $res->{content};
    my $hash = decode_json $json;
    $self->rss($hash);

    my $title   = $hash->{list}{title}{'$text'};
    $self->title( $title );
    $self->teaser( $hash->{list}{teaser}{'$text'});

    my $fmt = DateTime::Format::RSS->new;

    my @stories;
    for ( @{$hash->{list}{story}} ){
        my $id             = $_->{id};
        my $title          = $_->{title}{'$text'};
        my $date_str          = $_->{storyDate}{'$text'};
        my $date  = $fmt->parse_datetime($date_str);
        my $url_transcript = $_->{transcript}{link}{'$text'};
        push @stories, { id => $id, title => $title, date => $date, url => $url_transcript };
    }

    $self->stories( \@stories );
    return $self;
}

1;
