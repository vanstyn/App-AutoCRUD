use strict;
use warnings;

use Plack::Test;
use Test::More;
use HTTP::Request::Common;
use App::AutoCRUD;
use FindBin;
use DBI;

my $sqlite_path = "$FindBin::Bin/data/"
                . "Chinook_Sqlite_AutoIncrementPKs_empty_tables.tst_sqlite";

# connect to an in-memory copy of the database
my $in_memory_dbh_copy = sub  {
  my $connect_options = {
    RaiseError     => 1,
    sqlite_unicode => 1,
  };
  my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:", "", "", $connect_options);
  $dbh->sqlite_backup_from_file($sqlite_path);
  return $dbh;
};


# setup config
my $config = {
  app => { name => "Demo",
           title => "AutoCRUD demo application",
         },
  datasources => {
    Chinook => {
      dbh => {connect => $in_memory_dbh_copy},
     },
   },
};


# instantiate the app
my $crud = App::AutoCRUD->new(config => $config);
my $app  = $crud->to_app;

# start testing
test_psgi $app, sub {
  my $cb = shift;

  # homepage
  my $res = $cb->(GET "/home");
  like $res->content, qr/AutoCRUD demo application/, "Title from config";
  like $res->content, qr/Chinook/,                   "Home contains Chinook datasource";

  # schema page
  $res = $cb->(GET "/Chinook/schema/tablegroups");
  like $res->content, qr/Artist/,                    "Artist listed";
  like $res->content, qr/Album/,                     "Album listed";
  like $res->content, qr/Track/,                     "Track listed";

  # table description
  $res = $cb->(GET "/Chinook/table/MediaType/descr");
  like $res->content, qr(INTEGER\s+NOT\s+NULL),      "MediaTypeId datatype";

  # search form (display)
  $res = $cb->(GET "/Chinook/table/MediaType/search");
  like $res->content, qr(<span class="TN_label colname pk">MediaTypeId</span>),
                                                     "MediaTypeId present, pk detected";

  # search form (POST)
  $res = $cb->(POST "/Chinook/table/MediaType/search");
  is $res->code, 303,                                "redirecting POST search";
  like $res->header('location'), qr/^list\?/,        "redirecting to 'list'";

  # list
  $res = $cb->(GET "/Chinook/table/MediaType/list?");
  like $res->content, qr(records 1 - 5),             "found 5 records";
  like $res->content, qr(MPEG),                      "found MPEG";
  like $res->content, qr(AAC),                       "found AAC";
  $res = $cb->(GET "/Chinook/table/MediaType/list?Name=*MPEG*");
  like $res->content, qr(LIKE \?),                   "SQL LIKE";
  like $res->content, qr(records 1 - 2),             "found 2 records";
  like $res->content, qr(Protected MPEG),            "found Protected MPEG";

  # id
  $res = $cb->(GET "/Chinook/table/Album/id/1");
  like $res->content, qr(Album/update[^"]*">),       "update link";

  # TODO : test list outputs as xlsx, yaml, json, xml

  # TODO : test descr, update, insert, delete

  # update without a -where clause
  $res = $cb->(POST "/Chinook/table/Album/update", {'set.Title' => 'foobar'});
  is $res->code, 500;
  like $res->content, qr(without any '-where'),       "update without -where";

  # update with an empty -where clause
  $res = $cb->(POST "/Chinook/table/Album/update", {'set.Title'     => 'foobar',
                                                    'where.AlbumId' => ""});
  is $res->code, 500;
  like $res->content, qr(without any '-where'),       "update with empty -where";

  # delete without a -where clause
  $res = $cb->(POST "/Chinook/table/Album/delete");
  is $res->code, 500;
  like $res->content, qr(without any '-where'),       "delete without -where";

  # delete with an empty -where clause
  $res = $cb->(POST "/Chinook/table/Album/delete", {'where.AlbumId' => ""});
  is $res->code, 500;
  like $res->content, qr(without any '-where'),       "delete with empty -where";

};

# signal end of tests
done_testing;


