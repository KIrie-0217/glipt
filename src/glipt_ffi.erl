-module(glipt_ffi).
-export([get_home_dir/0, sha256_hex/1, unix_timestamp/0, resolve_path/1, get_env/1]).

get_home_dir() ->
    case os:getenv("HOME") of
        false -> "/tmp";
        Home -> list_to_binary(Home)
    end.

sha256_hex(Input) ->
    Hash = crypto:hash(sha256, Input),
    list_to_binary(lists:flatten([io_lib:format("~2.16.0b", [B]) || <<B>> <= Hash])).

unix_timestamp() ->
    erlang:system_time(second).

resolve_path(Path) ->
    list_to_binary(filename:absname(binary_to_list(Path))).

get_env(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, list_to_binary(Value)}
    end.
