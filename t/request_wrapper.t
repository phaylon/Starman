use Test::TCP;
use LWP::UserAgent;
use Test::More;
use Plack::Handler::Starman;
use File::Temp;

my $tmp = File::Temp->new;
my $tmp_file = $tmp->filename;
my $log = sub {
    open my $fh, '>>', $tmp_file
        or die "Unable to write temp file '$tmp_file': $!\n";
    print $fh join '', @_, "\n";
    close $fh;
};

my $app = sub {
    $log->('request');
    [200, [], ['OK']];
};

my $wrap = sub {
    my ($conn, $req) = @_;
    $log->('pre request');
    $log->('conn ', $conn->isa('IO::Socket') ? 'Y' : 'N');
    $req->();
    $log->('post request');
};

test_tcp(
    server => sub {
        my $port = shift;
        Starman::Server
            ->new(request_wrapper => $wrap)
            ->run($app, { port => $port });
    },
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new(timeout => 3);
        my $res = $ua->get('http://localhost:' . $port);
        is $res->content, 'OK', 'response content';
        open my $fh, '<', $tmp_file
            or die "Unable to read temp file '$tmp_file': $!\n";
        my $logged = do { local $/; <$fh> };
        is $logged, "pre request\nconn Y\nrequest\npost request\n",
            'action order';
    },
);

done_testing;
