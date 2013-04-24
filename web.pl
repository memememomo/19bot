use Mojolicious::Lite;
use utf8;

app->plugin('tt_renderer');

app->config(hypnotoad => {listen => ['http://*:5555']});

my $config = do 'config.pl';

get '/' => sub {
    my $self = shift;
    $self->render;
} => 'index';

post '/upload' => sub {
    my $self = shift;

    my $music = $self->req->upload('music');

    unless ($music) {
        $self->flash('message' => 'ファイルを選択して下さい(>_<)');
        return $self->redirect_to('index');
    }

    my $max_size = 10 * 1024 * 1024;
    if ($music->size > $max_size) {
        $self->flash('message' => 'ファイルサイズが大きすぎます(>_<)');
        return $self->redirect_to('index');
    }


    my $playlist_dir = $config->{playlist_dir};
    my $save_path = "$playlist_dir/" . $music->filename;

    $music->move_to($save_path);

    $self->flash('message' => 'アップロードできました。');
    $self->redirect_to('index');
} => 'upload';


app->start;
