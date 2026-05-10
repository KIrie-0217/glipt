-module(glipt_ffi).
-export([get_home_dir/0, sha256_hex/1]).

get_home_dir() ->
    case os:getenv("HOME") of
        false -> "/tmp";
        Home -> list_to_binary(Home)
    end.

sha256_hex(Input) ->
    Hash = crypto:hash(sha256, Input),
    list_to_binary(lists:flatten([io_lib:format("~2.16.0b", [B]) || <<B>> <= Hash])).
