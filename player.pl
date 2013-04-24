use strict;
use warnings;
use AnyEvent;
use AnyEvent::Util;
use AnyEvent::IRC;
use AnyEvent::IRC::Connection;
use AnyEvent::IRC::Client;

my $config = do 'config.pl';

my $playlist_dir = $config->{playlist_dir};
my $fin_dir = $config->{fin_dir};
my $botname = 'zyukubot_beta';
my $irc_server = '192.168.100.116';
my $chan = '#bottest';

my $cv = AnyEvent->condvar;

my %boo_counter;
my $con; $con = AnyEvent::IRC::Client->new;
$con->reg_cb(
    connect => sub {
        my ( $con, $err ) = @_;
        if ( defined $err ) {
            warn "Connect ERROR! => $err\n";
            $cv->broadcast;
        }
        else {
            warn "Connected! Yay!\n";
        }
    },
    registered => sub {
        my ($self) = @_;
        warn "registered!\n";
        $con->enable_ping(60);
        $con->send_srv("JOIN", $chan);
    },
    irc_privmsg => sub {
        my ( $self, $msg ) = @_;
        my $user = $msg->{prefix};
        my $text = $msg->{params}->[1];
        if ($text =~ /boo+/) {
            $boo_counter{$user}++;
        }
    },
    disconnect => sub {
        die "Oh, got a disconnect: $_[1], exiting...\n";
    }
);
#$con->connect( $irc_server, 6667, { nick => 'bot', 'user' => 'bot', real => 'the bot' });
$con->connect( $irc_server, 6667, { nick => $botname, 'user' => $botname, real => $botname});

my $no_music_counter = 0;
my $playing = 0;
my $cmd;
my $cmd_pid;
my $loop; $loop = AnyEvent->timer(
    after => 1,
    interval => 1,
    cb => sub {
        opendir my $dh, $playlist_dir or die "";
        my @list = grep /^[^\.]/, readdir $dh;
        closedir $dh;

        my $num = @list;
        if ($num && !$cmd) {
            $no_music_counter = 0;
            my $music = $list[int(rand($num))];

            my $path = "$playlist_dir/$music";
            $cmd = run_cmd ['afplay', $path], '$$' => \$cmd_pid;
            send_message($con, $chan, "Now playing: $music");
            $cmd->cb(sub {
                         send_message($con, $chan, "Finish playing: $music");
                         move_fin($path);
                         undef $cmd;
                     });
        }
        else {
            my $boo = keys %boo_counter;
            if ($boo >= 1) {
                $cmd->end;
                `kill -TERM $cmd_pid`;
                undef $cmd;
                undef $cmd_pid;
                %boo_counter = ();
                send_message($con, $chan, "再生が中断されました。");
                return;
            }

            if (!$playing && !$num) {
                if (!$no_music_counter) {
                    send_message($con, $chan, "プレイリストに何も入ってません(>_<)");
                }
                $no_music_counter++;
            }
        }
    }
);

sub move_fin {
    my ($music) = @_;
    `mv $music $fin_dir`;
}

sub send_message {
    my ($conn, $chan, $msg) = @_;
    $con->send_chan($chan, 'NOTICE', $chan, $msg);
}

$cv->recv;
