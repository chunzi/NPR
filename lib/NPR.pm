package NPR;
use Dancer ':syntax';

use HTTP::Tiny;
use XML::Tiny::Simple qw/ parsestring /;
use Data::Dumper;
use Class::Date qw/ date /;
use JSON;

our $VERSION = '0.1';

hook 'before_template_render' => sub {
    my $tokens = shift;
    my $base   = uri_for('/');
    $base =~ s/\/$//;
    $base =~ s{^http://}{https://} if request->header('X-Forwarded-Proto') eq 'https';
    $tokens->{'base'} = $base;
};

get '/' => sub {
    my $url_stories = 'http://api.npr.org/query?id=1056&fields=title,storyDate,transcript&dateType=story&sort=dateDesc&output=JSON&apiKey=MDExMTA1NDUwMDEzNjQyNjc4NDFmZjZkOA001';

    my $res = HTTP::Tiny->new->get($url_stories);
    die "Failed wget $url_stories\n" unless $res->{success};

    my $json    = $res->{content};
    my $hash    = decode_json $json;
    my $stories = $hash->{list}{story};
    my $title   = $hash->{list}{title}{'$text'};

    my @stories;
    for (@$stories) {
        my $id             = $_->{id};
        my $title          = $_->{title}{'$text'};
        my $url_transcript = $_->{transcript}{link}{'$text'};
        push @stories, { id => $id, title => $title, url => $url_transcript };

        # printf "%s - %s %s\n", $id, $title, $url_transcript;
    }
    var title   => $title;
    var stories => \@stories;
    template 'index', vars;
};

get '/story/:id' => sub {
    my $id = param 'id';
    my $url = sprintf 'http://api.npr.org/transcript?id=%s&apiKey=MDExMTA1NDUwMDEzNjQyNjc4NDFmZjZkOA001', $id;

    my $res = HTTP::Tiny->new->get($url);
    die "Failed wget $url\n" unless $res->{success};

    my $xml = $res->{content};
    my $doc = parsestring($xml);

    my $story_url = $doc->{transcript}{story}{link}[0]{content};
    my ( $yy, $mm, $dd, $sid, $slug ) = ( $story_url =~ m{\.org/(.*?)/(.*?)/(.*?)/(.*?)/(.*)$} );
    my $day = date [$yy, $mm, $dd];

    # printf "%s: %s - %s\n", $sid, $day->ymd, $slug;

    my @paras = map { $_->{content} } @{ $doc->{transcript}{paragraph} };
    my @paras_new = map {
        if (/:/) {
            my ( $who, $what ) = split /:\s+/, $_, 2;
            if ( length $who < 30 ) {
                { who => $who, what => $what };
            }
            else {
                { what => $_ };
            }
        }
        else {
            { what => $_ };
        }
    } @paras;
    var paras => \@paras_new;
    var paras_orig => \@paras;
    template 'story', vars, { layout => undef };
};

true;
