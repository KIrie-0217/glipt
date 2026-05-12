-module(glipt_ffi).
-export([get_home_dir/0, sha256_hex/1, unix_timestamp/0, resolve_path/1, get_env/1, run_module/3]).

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

run_module(EbinPaths, Module, ScriptArgs) ->
    lists:foreach(fun(P) -> code:add_patha(binary_to_list(P)) end, EbinPaths),
    inject_argv(ScriptArgs),
    ModAtom = binary_to_atom(Module, utf8),
    code:purge(ModAtom),
    code:delete(ModAtom),
    code:load_file(ModAtom),
    try
        apply(ModAtom, main, []),
        {ok, <<>>}
    catch
        Class:Reason:Stack ->
            Msg = io_lib:format("~p:~p~n~p", [Class, Reason, Stack]),
            {error, list_to_binary(lists:flatten(Msg))}
    end.

inject_argv(ScriptArgs) ->
    ArgsBin = [A || A <- ScriptArgs],
    {ok, Cwd} = file:get_cwd(),
    CwdBin = unicode:characters_to_binary(Cwd, utf8),
    Runtime = <<>>,
    LoadFun = fun() -> {Runtime, CwdBin, ArgsBin} end,
    Forms = [
        {attribute, 1, module, argv_ffi},
        {attribute, 2, export, [{load, 0}]},
        {function, 3, load, 0, [
            {clause, 3, [], [], [
                erl_parse:abstract(LoadFun())
            ]}
        ]}
    ],
    {ok, argv_ffi, Bin} = compile:forms(Forms),
    code:purge(argv_ffi),
    code:load_binary(argv_ffi, "argv_ffi.beam", Bin),
    ok.
