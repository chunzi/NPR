package NPR;
use Dancer ':syntax';

use YAML;
use Class::Date qw/ date /;
use JSON;
use File::Slurp;
use XML::RSS::LibXML;
use Web::Scraper::LibXML;
use Mojo::UserAgent;
use DateTime::Format::RSS;
our $VERSION = '0.1';

#--------------------------------------------------------------------------------
my $ua      = new Mojo::UserAgent;
my $rss     = XML::RSS::LibXML->new;
my $rss_dtf = DateTime::Format::RSS->new;

#--------------------------------------------------------------------------------
get '/' => sub {

    # my $url = 'https://www.npr.org/rss/podcast.php';
    # my $form  = { id => 510313 };
    # my $html = $ua->get( $url, form => $form )->result->content;

    my $html = read_file( ',podcast.xml' );

    #----------------------------------------
    $rss->parse( $html );
    my $channel = $rss->channel;
    my $podcast = {};
    $podcast->{title} = $channel->{title};

    #----------------------------------------
    my @items;
    for ( @{ $rss->items } ) {

        #----------------------------------------
        my $url_params = $_->{enclosure}{url};
        my ( $url_mp3, $params ) = split /\?/, $url_params, 2;

        #----------------------------------------
        my $p = {};
        for ( split /\&/, $params ) {
            my ( $k, $v ) = split /\=/, $_;
            $p->{$k} = $v;
        }
        my $sid = $p->{story};

        #----------------------------------------
        my $pubdate = $_->{pubDate};
        my $ctime   = $rss_dtf->parse_datetime( $pubdate );

        #----------------------------------------
        my $this = {};
        $this->{title}       = $_->{title};
        $this->{description} = $_->{description};
        $this->{url_mp3}     = $url_mp3;
        $this->{url_cover}   = $_->{itunes}{image}{href};
        $this->{sid}         = $sid;
        $this->{ctime}       = $ctime->strftime( '%F' );
        push @items, $this;
    }
    $podcast->{items} = \@items;

    #----------------------------------------
    var podcast => $podcast;
    template 'index', vars;
};

#--------------------------------------------------------------------------------
get '/sid/:id' => sub {
    my $id = param 'id';

    #----------------------------------------
    my $url = 'https://www.npr.org/templates/transcript/transcript.php';
    my $form = { storyId => $id };

    #----------------------------------------
    use Path::Tiny;
    my $path = path( 'npr/' . $id );
    -d $path or $path->mkpath( 0, 0777 );
    my $file = path( 'npr/' . $id . '/story.html' );

    unless ( -f $file ) {
        my $res = $ua->get( $url, form => $form )->result;
        my $html = $res->body;
        $file->spew( $html );
    }
    my $html = $file->slurp;

    #----------------------------------------
    my $now = scraper {
        process ".transcript p", 'paras[]' => 'HTML';
        process ".audio-tool a", 'mp3'     => '@href';
        process "title",         'title'   => 'TEXT';
    };
    my $res = $now->scrape( $html );
    var res => $res;

    #----------------------------------------
    my $paras = $res->{paras};
    my @paras;
    for ( @$paras ) {
        s{^([A-Z\s,]*?):}{<small class="text-info">$1:</small><br/>}sg;
        push @paras, $_;
    }
    pop @paras;
    pop @paras;
    var paras => \@paras;

    template 'story', vars;
};

true;
