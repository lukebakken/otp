%% 
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2003-2025. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%% 

%%----------------------------------------------------------------------
%% Purpose:
%%
%% Test:    ts:run(snmp, snmp_log_SUITE, [batch]).
%% Test:    ts:run(snmp, snmp_log_SUITE, log_to_txt2, [batch]).
%% 
%%----------------------------------------------------------------------
-module(snmp_log_SUITE).


%%----------------------------------------------------------------------
%% Include files
%%----------------------------------------------------------------------
-include_lib("common_test/include/ct.hrl").
-include("snmp_test_lib.hrl").
-define(SNMP_USE_V3, true).
-include_lib("snmp/include/snmp_types.hrl").
-include_lib("kernel/include/file.hrl").


%%----------------------------------------------------------------------
%% External exports
%%----------------------------------------------------------------------
-export([
         suite/0, all/0, groups/0,
         init_per_suite/1,    end_per_suite/1,
         init_per_group/2,    end_per_group/2, 
         init_per_testcase/2, end_per_testcase/2,

	 open_and_close/1,
	
	 open_write_and_close1/1,
	 open_write_and_close2/1,
	 open_write_and_close3/1,
	 open_write_and_close4/1,
	
	 log_to_io1/1,
	 log_to_io2/1,
	
	 log_to_txt1/1,
  	 log_to_txt2/1,
  	 log_to_txt3/1
	]).


%%----------------------------------------------------------------------
%% Internal exports
%%----------------------------------------------------------------------
-export([
	 log_writer_main/6,
	 log_reader_main/1,
	 next_seqno/2
        ]).


%%======================================================================
%% Common Test interface functions
%%======================================================================

suite() -> 
    [{ct_hooks, [ts_install_cth]}].

all() -> 
    [
     open_and_close, 
     {group, open_write_and_close},
     {group, log_to_io}, 
     {group, log_to_txt}].

groups() -> 
    [
     {open_write_and_close, [], owac_cases()},
     {log_to_io,            [], l2i_cases()},
     {log_to_txt,           [], l2t_cases()}
    ].


owac_cases() ->
    [
     open_write_and_close1,
     open_write_and_close2,
     open_write_and_close3,
     open_write_and_close4
    ].

l2i_cases() ->
    [
     log_to_io1,
     log_to_io2
    ].

l2t_cases() ->
    [
     log_to_txt1,
     log_to_txt2,
     log_to_txt3
    ].



%%
%% -----
%%

init_per_suite(Config0) when is_list(Config0) ->
    case ?LIB:init_per_suite(Config0) of
        {skip, _} = SKIP ->
            SKIP;

        Config1 when is_list(Config1) ->
            snmp_test_sys_monitor:start(),
            Config1
    end.

end_per_suite(Config) when is_list(Config) ->
    snmp_test_sys_monitor:stop(),
    ?LIB:end_per_suite(Config).



%%
%% -----
%%

init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, Config) ->
    Config.



%%
%% -----
%%

init_per_testcase(Case, Config) when is_list(Config) ->

    snmp_test_global_sys_monitor:reset_events(),
    
    Dir        = ?config(priv_dir, Config),
    LogTestDir = join(Dir,        ?MODULE),
    CaseDir    = join(LogTestDir, Case),
    case file:make_dir(LogTestDir) of
	ok ->
	    ok;
	{error, eexist} ->
	    ok;
	Error ->
	    ?FAIL({failed_creating_subsuite_top_dir, Error})
    end,
    ok = file:make_dir(CaseDir),
    Dog = ?WD_START(?MINS(5)),
    [{log_dir, CaseDir}, {watchdog, Dog}|Config].

end_per_testcase(_Case, Config) when is_list(Config) ->

    ?IPRINT("system events during test: "
            "~n   ~p", [snmp_test_global_sys_monitor:events()]),

    %% Leave the dirs created above (enable debugging of the test case(s))
    Dog = ?config(watchdog, Config),
    ?WD_STOP(Dog),
    lists:keydelete(watchdog, 1, Config).



%%======================================================================
%% Test functions
%%======================================================================

open_and_close(suite) -> [];
open_and_close(Config) when is_list(Config) ->
    ?P(open_and_close),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, trace),
                   ?config(log_dir, Config)
           end,
    TC   = fun(Dir) ->
                   do_open_and_close(Dir)
           end,
    Post = fun(_) ->
                   ok
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).

do_open_and_close(Dir) ->
    Name   = "snmp_test",
    File   = join(Dir, "snmp_test.log"),
    Size   = {1024, 10},
    Repair = true,
    ?IPRINT("~w -> create log", [?FUNCTION_NAME]),
    {ok, Log} = snmp_log:create(Name, File, Size, Repair),
    ?IPRINT("~w -> sync log", [?FUNCTION_NAME]),
    ok = snmp_log:sync(Log),
    ?IPRINT("~w -> get (log) info", [?FUNCTION_NAME]),
    {ok, Info} = snmp_log:info(Log),
    ?IPRINT("~w -> display (log) info", [?FUNCTION_NAME]),
    display_info(Info),
    ?IPRINT("~w -> close log", [?FUNCTION_NAME]),
    ok = snmp_log:close(Log),
    ?IPRINT("~w -> done", [?FUNCTION_NAME]),
    ok.
    

%%======================================================================

open_write_and_close1(suite) -> 
    [];
open_write_and_close1(doc) -> 
    "Open a plain (no sequence-numbering) log file";
open_write_and_close1(Config) when is_list(Config) ->
    ?P(?FUNCTION_NAME),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, trace),
                   ?config(log_dir, Config)
           end,
    TC   = fun(Dir) ->
                   SeqNoGen = none, 
                   ok = open_write_and_close(SeqNoGen, Dir)
           end,
    Post = fun(_) ->
                   ok
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).
    

%%======================================================================

open_write_and_close2(suite) -> 
    [];
open_write_and_close2(doc) -> 
    "Open a log file with sequence-numbering explicitly disabled";
open_write_and_close2(Config) when is_list(Config) ->
    ?P(?FUNCTION_NAME),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, trace),
                   ?config(log_dir, Config)
           end,
    TC   = fun(Dir) ->
                   SeqNoGen = disabled, 
                   ok = open_write_and_close(SeqNoGen, Dir)
           end,
    Post = fun(_) ->
                   ok
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).


%%======================================================================

open_write_and_close3(suite) -> 
    [];
open_write_and_close3(doc) -> 
    "Open a log file with sequence-numbering using MFA";
open_write_and_close3(Config) when is_list(Config) ->
    ?P(?FUNCTION_NAME),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, trace),
                   ?config(log_dir, Config)
           end,
    TC   = fun(Dir) ->
                   seqno_init(), 
                   SeqNoGen = {?MODULE, next_seqno, [10, 100]}, 
                   ok = open_write_and_close(SeqNoGen, Dir)
           end,
    Post = fun(_) -> 
                   seqno_finish()
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).



%%======================================================================

open_write_and_close4(suite) -> 
    [];
open_write_and_close4(doc) -> 
    "Open a log file with sequence-numbering using fun";
open_write_and_close4(Config) when is_list(Config) ->
    ?P(?FUNCTION_NAME),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, trace),
                   ?config(log_dir, Config)
           end,
    TC   = fun(Dir) ->
                   seqno_init(), 
                   SeqNoGen = fun() -> next_seqno(10, 100) end, 
                   ok = open_write_and_close(SeqNoGen, Dir)
           end,
    Post = fun(_) ->
                   seqno_finish()
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).


%%======================================================================

seqno_init() ->
    ets:new(snmp_log_test_seqno_tab, [named_table, set, protected]).

seqno_finish() ->
    ets:delete(snmp_log_test_seqno_tab).

next_seqno(Initial, Max) ->
    Key       = seqno, 
    Position  = 2, 
    Increment = 1, 
    Threshold = Max,
    SetValue  = Initial, 
    UpdateOp  = {Position, Increment, Threshold, SetValue},
    Tab       = snmp_log_test_seqno_tab, 
    case (catch ets:update_counter(Tab, Key, UpdateOp)) of
	{'EXIT', {badarg, _}} ->
	    ets:insert(Tab, {seqno, Initial}),
	    Initial;
	Next when is_integer(Next) ->
	    Next
    end.

pretty_seqnogen(SeqNoGen) when is_atom(SeqNoGen) ->
    atom_to_list(SeqNoGen);
pretty_seqnogen({_Mod, _Func, _Args} = _SeqNoGen) ->
    "tuple";
pretty_seqnogen(SeqNoGen) when is_function(SeqNoGen) ->
    "function".
    
open_write_and_close(SeqNoGen, Dir) ->
    ?IPRINT("~w(~s) -> entry", [?FUNCTION_NAME, pretty_seqnogen(SeqNoGen)]),

    Name   = "snmp_test",
    File   = join(Dir, "snmp_test.log"),
    Size   = {1024, 10},
    Repair = true,

    ?IPRINT("~w(~s) -> create log",
            [?FUNCTION_NAME, pretty_seqnogen(SeqNoGen)]),
    {ok, Log} =
	case SeqNoGen of
	    none -> 
		snmp_log:create(Name, File, Size, Repair);
	    _ ->
		snmp_log:create(Name, File, SeqNoGen, Size, Repair)
	end,

    Vsn       = 'version-2',
    Community = "all-rights",

    ?IPRINT("~w(~s) -> create messages to log",
            [?FUNCTION_NAME, pretty_seqnogen(SeqNoGen)]),
    %% A request
    Req = get_next_request(Vsn, Community, [1,1], 1, 235779012),

    %% A reply
    Rep = get_response(Vsn, Community,
			     [1,3,6,1,2,1,1,1,0], 'OCTET STRING',
			     "Erlang SNMP agent", 1, 235779012),
    
    %% Create a list of messages to log:
    Msgs = lists:flatten(lists:duplicate(1002,[Req,Rep])),

    %% And now log them:
    ?IPRINT("~w(~s) -> log ~p messages, ~p bytes",
            [?FUNCTION_NAME, pretty_seqnogen(SeqNoGen),
             length(Msgs), size(list_to_binary(Msgs))]),
    Addr = ?LOCALHOST(),
    Port = 162,
    Logger = fun(Packet) ->
		     ok = snmp_log:log(Log, Packet, Addr, Port)
	     end,
    lists:foreach(Logger, Msgs),
    ?IPRINT("~w(~s) -> check notify",
            [?FUNCTION_NAME, pretty_seqnogen(SeqNoGen)]),
    check_notify(),
    
    ?IPRINT("~w(~s) -> display (log) info",
            [?FUNCTION_NAME, pretty_seqnogen(SeqNoGen)]),
    {ok, Info} = snmp_log:info(Log),
    display_info(Info),

    ?IPRINT("~w(~s) -> close log",
            [?FUNCTION_NAME, pretty_seqnogen(SeqNoGen)]),
    ?DBG("open_write_and_close1 -> close log", []),
    ok = snmp_log:close(Log),

    ?IPRINT("~w(~s) -> done",
            [?FUNCTION_NAME, pretty_seqnogen(SeqNoGen)]),
    ok.
    


%%======================================================================

log_to_io1(suite) -> [];
log_to_io1(doc) -> "Log to io from the same process that opened "
		       "and wrote the log";
log_to_io1(Config) when is_list(Config) ->
    ?P(?FUNCTION_NAME),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, debug),
                   ?config(log_dir, Config)
           end,
    TC   = fun(Dir) ->
                   do_log_to_io1(Dir)
           end,
    Post = fun(_) ->
                   ok
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).


do_log_to_io1(Dir) ->
    ?IPRINT("~w -> entry", [?FUNCTION_NAME]),

    Name   = "snmp_test_l2i1",
    File   = join(Dir, "snmp_test_l2i1.log"),
    Size   = {1024, 10},
    Repair = true,

    ?IPRINT("~w -> create log", [?FUNCTION_NAME]),
    {ok, Log} = snmp_log:create(Name, File, Size, Repair),

    ?IPRINT("~w -> create messages to log", [?FUNCTION_NAME]),
    Msgs = messages(),

    ?IPRINT("~w -> create logger fun(s)", [?FUNCTION_NAME]),
    Addr = ?LOCALHOST(),
    Port = 162,
    Logger = fun(Packet) ->
		     ok = snmp_log:log(Log, Packet, Addr, Port)
	     end,
    BatchLogger = fun(Time) ->
			  lists:foreach(Logger, Msgs),
			  ?SLEEP(Time),
			  ok
		  end,
    To = lists:duplicate(100, 100),

    ?IPRINT("~w -> log the messages", [?FUNCTION_NAME]),
    lists:foreach(BatchLogger, To),

    ?IPRINT("~w -> get (log) info", [?FUNCTION_NAME]),
    {ok, Info} = snmp_log:info(Log),

    ?IPRINT("~w -> display (log) info", [?FUNCTION_NAME]),
    display_info(Info),

    ?IPRINT("~w -> do the convert to io (stdout)", [?FUNCTION_NAME]),
    ? line ok = snmp:log_to_io(Dir, [], Name, File, false),

    ?IPRINT("~w -> close log", [?FUNCTION_NAME]),
    ok = snmp_log:close(Log),

    ?IPRINT("~w -> done", [?FUNCTION_NAME]),
    ok.


%%======================================================================
%% Start a logger-process that logs messages with a certain interval.
%% Start a reader-process that reads messages from the log at a certain
%% point in time.

log_to_io2(suite) -> [];
log_to_io2(doc) -> "Log to io from a different process than which "
		       "opened and wrote the log";
log_to_io2(Config) when is_list(Config) ->
    ?P(?FUNCTION_NAME),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, debug),
                   Dir    = ?config(log_dir,     Config),
                   Factor = ?config(snmp_factor, Config),
                   {Dir, Factor}
           end,
    TC   = fun({Dir, Factor}) ->
                   do_log_to_io2(Dir, Factor)
           end,
    Post = fun(_) ->
                   ok
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).

do_log_to_io2(Dir, Factor) ->
    ?IPRINT("~w -> entry", [?FUNCTION_NAME]),

    process_flag(trap_exit, true),

    Name   = "snmp_test_l2i2",
    File   = join(Dir, "snmp_test_l2i2.log"),
    Size   = {1024, 10},
    Repair = true,
    
    ?IPRINT("~w -> create log writer process", [?FUNCTION_NAME]),
    {ok, Log, Logger} =
        log_writer_start(Name, File, Size, Repair, Factor),

    ?IPRINT("~w -> create log reader process", [?FUNCTION_NAME]),
    {ok, Reader} = log_reader_start(),

    ?DBG("log_to_io2 -> wait some time", []),
    ?SLEEP(5000),

    ?IPRINT("~w -> display log info", [?FUNCTION_NAME]),
    log_writer_info(Logger),

    ?IPRINT("~w -> instruct the log writer to sleep some", [?FUNCTION_NAME]),
    ok = log_writer_sleep(Logger, 5000),

    ?IPRINT("~w -> instruct the log reader to log to io", [?FUNCTION_NAME]),
    Res = 
	log_reader_log_to(Reader, 
			  fun() -> 
				  I = disk_log:info(Log),
				  R = snmp:log_to_io(Dir, [], Name, File, true),
				  {R, I}
			  end),

    case Res of
	{ok, Info} ->
            ?IPRINT("~w -> successs:"
                    "~n   Info: ~p", [?FUNCTION_NAME, Info]),
	    ok;
	{Error, Info} ->
            ?EPRINT("~w -> failure:"
                    "~n   Error: ~p"
                    "~n   Info:  ~p", [?FUNCTION_NAME, Error, Info]),
	    ?FAIL({log_lo_io_failed, Error, Info})
    end,

    ?IPRINT("~w -> instruct the log writer to stop", [?FUNCTION_NAME]),
    log_writer_stop(Logger),

    ?IPRINT("~w -> instruct the log reader to stop", [?FUNCTION_NAME]),
    log_reader_stop(Reader),

    ?IPRINT("~w -> done", [?FUNCTION_NAME]),
    ok.


%%======================================================================

log_to_txt1(suite) -> [];
log_to_txt1(Config) when is_list(Config) ->
    ?P(?FUNCTION_NAME),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, debug),
                   ?config(log_dir, Config)
           end,
    TC   = fun(Dir) ->
                   Name     = "snmp_test_l2t1",
                   SeqNoGen = disabled, 
                   log_to_txt(Name, SeqNoGen, Dir)
           end,
    Post = fun(_) ->
                   ok
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).


%%======================================================================

log_to_txt2(suite) -> [];
log_to_txt2(Config) when is_list(Config) ->
    ?P(?FUNCTION_NAME),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, debug),
                   ?config(log_dir, Config)
           end,
    TC   = fun(Dir) ->
                   Name = "snmp_test_l2t2",
                   seqno_init(), 
                   SeqNoGen = {?MODULE, next_seqno, [1, 100]}, 
                   log_to_txt(Name, SeqNoGen, Dir)
           end,
    Post = fun(_) ->
                   seqno_finish()
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).


%%======================================================================

log_to_txt(Name, SeqNoGen, Dir) ->
    ?IPRINT("~w -> entry", [?FUNCTION_NAME]),

    File   = join(Dir, Name ++ ".log"),
    Size   = {10240, 10},
    Repair = true,

    ?IPRINT("~w -> create log", [?FUNCTION_NAME]),
    {ok, Log} =
	case SeqNoGen of
	    none -> 
		snmp_log:create(Name, File, Size, Repair);
	    _ ->
		snmp_log:create(Name, File, SeqNoGen, Size, Repair)
	end,

    ?IPRINT("~w -> create messages to log", [?FUNCTION_NAME]),
    Msgs = messages(),

    ?IPRINT("~w -> create logger fun(s)", [?FUNCTION_NAME]),
    Addr = ?LOCALHOST(),
    Port = 162,
    Logger = fun(Packet) ->
		     ok = snmp_log:log(Log, Packet, Addr, Port)
	     end,
    BatchLogger = fun(Time) ->
			  lists:foreach(Logger, Msgs),
			  ?SLEEP(Time),
			  ok
		  end,
    To = lists:duplicate(10, 5000),

    ?IPRINT("~w -> log the messages", [?FUNCTION_NAME]),
    Start = calendar:local_time(),
    lists:foreach(BatchLogger, To),
    Stop  = calendar:local_time(),

    ?IPRINT("~w -> get (log) info", [?FUNCTION_NAME]),
    {ok, Info} = snmp_log:info(Log),
    ?IPRINT("~w -> display (log) info", [?FUNCTION_NAME]),
    display_info(Info),

    Out1a = join(Dir, "snmp_text-1-unblocked.txt"),
    ?IPRINT("~w -> do the convert to a text file (~s) unblocked",
            [?FUNCTION_NAME, Out1a]),
    ok = snmp:log_to_txt(Dir, [], Out1a, Log, File, false),

    {ok, #file_info{size = Size1a}} = file:read_file_info(Out1a),
    ?IPRINT("~w -> text file size: ~p",
            [?FUNCTION_NAME, Size1a]),
    validate_size(Size1a),

    Out1b = join(Dir, "snmp_text-1-blocked.txt"),
    ?IPRINT("~w -> do the convert to a text file (~s) blocked",
            [?FUNCTION_NAME, Out1b]),
    ok = snmp:log_to_txt(Dir, [], Out1b, Log, File, true),

    {ok, #file_info{size = Size1b}} = file:read_file_info(Out1b),
    ?IPRINT("~w -> text file size: ~p",
            [?FUNCTION_NAME, Size1b]),
    validate_size(Size1b, {eq, Size1a}),

    Out2 = join(Dir, "snmp_text-2.txt"),
    ?IPRINT("~w -> do the convert to a text file when"
            "~n   Start: ~p"
            "~n   Stop:  ~p"
            "~n   Out2:  ~p",
            [?FUNCTION_NAME, Start, Stop, Out2]),
    ok = snmp:log_to_txt(Dir, [], Out2, Log, File, Start, Stop),

    {ok, #file_info{size = Size2}} = file:read_file_info(Out2),
    ?IPRINT("~w -> text file size: ~p",
            [?FUNCTION_NAME, Size2]),
    validate_size(Size2, {le, Size1a}),

    %% Calculate new start / stop times...
    GStart = calendar:datetime_to_gregorian_seconds(Start),
    ?IPRINT("~w -> GStart: ~p",
            [?FUNCTION_NAME, GStart]),
    GStop  = calendar:datetime_to_gregorian_seconds(Stop),
    ?IPRINT("~w -> GStop: ~p",
            [?FUNCTION_NAME, GStop]),
    Diff4 = (GStop - GStart) div 4,
    ?IPRINT("~w -> Diff4: ~p",
            [?FUNCTION_NAME, Diff4]),
    GStart2 = GStart + Diff4,
    GStop2  = GStop - Diff4,
    if 
	GStop2 > GStart2 ->
	    ok;
	true ->
            ?EPRINT("~w -> invalid diff", [?FUNCTION_NAME]),
	    ?FAIL({date_calc_failure, GStart2, GStop2})
    end,
    
    Start2 = calendar:gregorian_seconds_to_datetime(GStart2),
    Stop2  = calendar:gregorian_seconds_to_datetime(GStop2),
    
    Out3 = join(Dir, "snmp_text-3.txt"),
    ?IPRINT("~w -> do the convert to a text file when"
            "~n   Start2: ~p"
            "~n   Stop2:  ~p"
            "~n   Out3:   ~p",
            [?FUNCTION_NAME, Start2, Stop2, Out3]),
    ok = snmp:log_to_txt(Dir, [], Out3, Log, File, Start2, Stop2),

    {ok, #file_info{size = Size3}} = file:read_file_info(Out3),
    ?IPRINT("~w -> text file size: ~p",
            [?FUNCTION_NAME, Size3]),
    validate_size(Size3, {l, Size1a}),    

    ?IPRINT("~w -> close log", [?FUNCTION_NAME]),
    ok = snmp_log:close(Log),

    ?IPRINT("~w -> done", [?FUNCTION_NAME]),
    ok.


%%======================================================================
%% Start a logger-process that logs messages with a certain interval.
%% Start a reader-process that reads messages from the log at a certain
%% point of time.
%%
%% Test: ts:run(snmp, snmp_log_test, log_to_txt2, [batch]).

log_to_txt3(suite) -> 
    [];
log_to_txt3(doc) -> 
    "Log to txt file from a different process than which "
	"opened and wrote the log";
log_to_txt3(Config) when is_list(Config) ->
    ?P(?FUNCTION_NAME),
    Cond = fun() -> ok end,
    Pre  = fun() ->
                   put(sname,     ?FUNCTION_NAME),
                   put(verbosity, debug),
                   Dir    = ?config(log_dir,     Config),
                   Factor = ?config(snmp_factor, Config),
                   {Dir, Factor}
           end,
    TC   = fun({Dir, Factor}) ->
                   do_log_to_txt3(Dir, Factor)
           end,
    Post = fun(_) ->
                   ok
           end,
    ?TC_TRY(?FUNCTION_NAME, Cond, Pre, TC, Post).

do_log_to_txt3(Dir, Factor) ->
    ?IPRINT("~w -> entry", [?FUNCTION_NAME]),

    process_flag(trap_exit, true),

    Name    = "snmp_test_l2t3",
    LogFile = join(Dir, "snmp_test_l2t3.log"),
    TxtFile = join(Dir, "snmp_test_l2t3.txt"),
    Meg     = 1024*1024,
    Size    = {10*Meg, 10},
    Repair  = true,

    StdMibDir = filename:join(code:priv_dir(snmp), "mibs") ++ "/",
    Mibs = [join(StdMibDir, "SNMPv2-MIB")],

    ?IPRINT("~w -> create log writer process", [?FUNCTION_NAME]),
    {ok, Log, Logger} =
        log_writer_start(Name, LogFile, Size, Repair, Factor),

    ?IPRINT("~w -> create log reader process", [?FUNCTION_NAME]),
    {ok, Reader} = log_reader_start(),

    ?IPRINT("~w -> wait some time", [?FUNCTION_NAME]),
    ?SLEEP(5000),

    ?IPRINT("~w -> display (log) info", [?FUNCTION_NAME]),
    log_writer_info(Logger),

    ?IPRINT("~w -> instruct the log writer to sleep some", [?FUNCTION_NAME]),
    ok = log_writer_sleep(Logger, 5000),

    ?IPRINT("~w -> instruct the log reader to log to txt", [?FUNCTION_NAME]),
    ?DBG("log_to_txt3 -> ", []),
    Res = 
	log_reader_log_to(Reader, 
			  fun() -> 
				  I = disk_log:info(Log),
				  T1 = snmp_misc:now(ms),
				  R = snmp_log:log_to_txt(Log, LogFile, Dir, 
							  Mibs, TxtFile),
				  T2 = snmp_misc:now(ms),
				  ?IPRINT("Time converting file: ~w ms",
                                          [T2 - T1]),
				  {R, I}
			  end),

    case Res of
	{ok, Info} ->
            ?IPRINT("~w -> success: "
                    "~n   Info: ~p", [?FUNCTION_NAME, Info]),
	    {ok, #file_info{size = FileSize}} =
		file:read_file_info(TxtFile),
            ?IPRINT("~w -> validate file size: ~p", [?FUNCTION_NAME, FileSize]),
	    validate_size(FileSize);
	{Error, Info} ->
	    ?EPRINT("~w -> log to txt failed: "
                    "~n   Error: ~p"
                    "~n   Info:  ~p", [?FUNCTION_NAME, Error, Info]),
	    ?FAIL({log_lo_txt_failed, Error, Info})
    end,

    ?IPRINT("~w -> instruct the log writer to stop", [?FUNCTION_NAME]),
    log_writer_stop(Logger),

    ?DBG("log_to_txt3 -> instruct the log writer to stop", []),
    log_reader_stop(Reader),

    ?DBG("log_to_txt3 -> done", []),
    ok.


validate_size(0 = A) ->
    ?EPRINT("Size validation failed: "
            "~n   A: ~p", [A]),
    ?FAIL(invalid_size);
validate_size(_) ->
    ok.

validate_size(0 = A, B) ->
    ?EPRINT("Size validation failed: "
            "~n   A: ~p"
            "~n   B: ~p", [A, B]),
    ?FAIL(invalid_size);
validate_size(A, {eq, A}) ->
    ok;
validate_size(A, {le, B}) when A =< B ->
    ok;
validate_size(A, {l, B}) when A < B ->
    ok;
validate_size(A, B) ->
    ?EPRINT("Size validation failed: "
            "~n   A: ~p"
            "~n   B: ~p", [A, B]),
    ?FAIL({invalid_size, A, B}).

    
%%======================================================================
%% Internal functions
%%======================================================================

log_writer_start(Name, File, Size, Repair, Factor) ->
    {Pid, _} = spawn_monitor(?MODULE, log_writer_main, 
		             [Name, File, Size, Repair, self(), Factor]),
    receive
	{log, Log, Pid} ->
	    {ok, Log, Pid};
	{'DOWN', _MRef, process, Pid, Reason} ->
	    {error, Reason}
    after 30000 ->
	    Msg  = receive Any -> Any after 0 -> nothing end,
	    Info = (catch process_info(Pid)),
	    exit({failed_starting_writer, timeout, Msg, Info})
    end.

log_writer_stop(Pid) ->
    Pid ! {stop, self()},
    _T1 = snmp_misc:now(ms),
    receive
	{'DOWN', _MRef, process, Pid, normal} ->
	    _T2 = snmp_misc:now(ms),
	    ?IPRINT("it took ~w ms to stop the writer", [_T2 - _T1]),
	    ok
    after 60000 ->
	    Msg  = receive Any -> Any after 0 -> nothing end,
	    Info = (catch process_info(Pid)),
	    ?IPRINT("failed stop writer - kill it: "
	    	    "~n      Msg:  ~p"
	    	    "~n      Info: ~p", [Msg, Info]),
	    exit(Pid, kill),
	    ok
    end.

log_writer_info(Pid) ->
    Pid ! {info, self()}.

log_writer_sleep(Pid, Time) ->
    Pid ! {sleep, Time, self()},
    _T1 = snmp_misc:now(ms),
    receive 
	{sleeping, Pid} ->
	    _T2 = snmp_misc:now(ms),
	    ?IPRINT("it took ~w ms to put the writer to sleep", [_T2 - _T1]),
	    ok;
	{'DOWN', _MRef, process, Pid, Reason} ->
	    _T2 = snmp_misc:now(ms),
	    ?IPRINT("writer error while attempting to put it to sleep (~w): "
	            "~n      ~p", [_T2 - _T1, Reason]),
	    {error, Reason}
    after 60000 ->
	    Msg  = receive Any -> Any after 0 -> nothing end,
	    Info = (catch process_info(Pid)),
	    ?IPRINT("failed to put writer to sleep - kill it"),
	    exit(Pid, kill),
	    exit({failed_put_writer_to_sleep, timeout, Msg, Info})
    end.

log_writer_main(Name, File, Size, Repair, P, Factor) ->
    process_flag(trap_exit, true),
    put(tname, "LOG-WRITER"),
    {ok, Log} = snmp_log:create(Name, File, Size, Repair),
    P ! {log, Log, self()},
    Msgs   = lists:flatten(lists:duplicate(if 
                                               (Factor > 10) -> 1;
                                               true   -> 10 div Factor
                                           end,
                                           messages())),
    Addr   = ?LOCALHOST(),
    Port   = 162,
    Logger =  fun(Packet) ->
		     ok = snmp_log:log(Log, Packet, Addr, Port)
	      end,
    BatchLogger = fun(Time) ->
			  lists:foreach(Logger, Msgs),
			  ?SLEEP(Time),
			  ok
		  end,
    log_writer(Log, BatchLogger, P).

log_writer(Log, Fun, P) ->
    ?IPRINT("entry"),
    receive 
	{stop, P} ->
	    ?IPRINT("received stop request"),
	    ok = snmp_log:close(Log),
	    exit(normal);
	{info, P} ->
	    ?IPRINT("received info request"),
	    {ok, Info} = snmp_log:info(Log),
	    display_info(Info),
	    log_writer(Log, Fun, P);
	{sleep, Time, P} ->
	    ?IPRINT("received sleep (~w) request", [Time]),
	    P ! {sleeping, self()},
	    ?SLEEP(Time),
	    ?IPRINT("done sleeping"),
	    log_writer(Log, Fun, P);
	ELSE ->
	    ?EPRINT("Received unknown message: "
                    "~n   ~p", [ELSE]),
	    log_writer(Log, Fun, P)
    after 1000 ->
	    ?IPRINT("log some messages"),
	    To = lists:duplicate(100, 100),
	    lists:foreach(Fun, To),
	    log_writer(Log, Fun, P)
    end.


%% --

log_reader_start() ->
    Pid = spawn_link(?MODULE, log_reader_main, [self()]),
    _T1 = snmp_misc:now(ms),
    receive 
	{started, Pid} ->
	    _T2 = snmp_misc:now(ms),
	    ?IPRINT("it took ~w ms to start the reader", [_T2 - _T1]),
	    {ok, Pid};
	{'EXIT', Pid, Reason} ->
	    {error, Reason}
    after 1000 ->
	    error
    end.

log_reader_stop(Pid) ->
    Pid ! {stop, self()},
    _T1 = snmp_misc:now(ms),
    receive
	{'EXIT', Pid, normal} ->
	    _T2 = snmp_misc:now(ms),
	    ?IPRINT("it took ~w ms to stop the reader", [_T2 - _T1]),
	    ok
    after 1000 ->
	    Msg = receive Any -> Any after 0 -> nothing end,
	    exit({failed_stopping_reader, timeout, Msg})
    end.

log_reader_log_to(Pid, LogToFun) when is_function(LogToFun) ->
    Pid ! {log_to, LogToFun, self()},
    receive
	{log_to_reply, Res, Pid} ->
	    Res
    end.

log_reader_main(P) ->
    put(tname, "LOG-READER"),
    P ! {started, self()},
    log_reader(P).

log_reader(P) ->
    ?IPRINT("entry"),
    receive 
	{stop, P} ->
	    ?IPRINT("received stop request"),
	    exit(normal);
	{log_to, F, P} ->
	    ?IPRINT("received log_to request"),
	    Res = F(),
	    ?IPRINT("done with log_to - sending reply"),
	    P ! {log_to_reply, Res, self()}, 
	    log_reader(P);
	ELSE ->
	    ?EPRINT("Received unknown message: "
                    "~n   ~p", [ELSE]),
	    log_reader(P)
    end.
    

%%======================================================================

check_notify() ->
    receive
	{disk_log, Node, LogName, Info} ->
	    io:format("disk_log notify: "
		      "~n   Node:    ~p"
		      "~n   LogName: ~s"
		      "~n   Info:    ~p"
		      "~n", [Node, LogName, Info]),
	    check_notify()
    after 1000 ->
	    done
    end.


messages() ->
    [get_next_request('version-1', "all-rights", 
		      [1,13], 1, 1101),
     get_response('version-1', "all-rights", 
		  [1,3,6,1,2,1,1,1,0], 
		  'OCTET STRING', "Erlang SNMP agent",
		  1, 1101),
     get_request('version-1', "all-rights", 
		 [1,3,6,1,2,1,1,1,0], 1, 1102),
     get_response('version-1', "all-rights", 
		  [1,3,6,1,2,1,1,1,0], 
		  'OCTET STRING', "Erlang SNMP agent",
		  1, 1102),
     set_request('version-1', "all-rights", 
		 [1,3,6,1,2,1,1,6,0], 
		 'OCTET STRING', "new_value",
		 1, 1003),
     get_response('version-1', "all-rights", 
		  [1,3,6,1,2,1,1,6,0], 
		  'OCTET STRING', "new_value",
		  1, 1103),
     get_bulk_request("all-rights", 1104),
     bulk_get_response('version-1', "all-rights", 
		       [48,29,6,8,43,6,1,2,1,1,1,0,4,17,69,114,108,97,
			110,103,32,83,78,77,80,32,97,103,101,110,116,
			48,7,6,3,43,7,1,130,0], 1104),
     inform_request("all-rights", 1105),
     get_response('version-1', "all-rights", 
		  [{[1,3,6,1,2,1,1,3,0],
		    'TimeTicks',
		    4046,
		    1},
		   {[1,3,6,1,6,3,1,1,4,1,0],
		    'OBJECT IDENTIFIER',
		    [1,3,6,1,2,1,1,0,1],2}],
		  1105),
     snmpv2_trap("all-rights", 1106),
     trap("all-rights")].


get_request(Vsn, Community, Oid, OrgIdx, ReqId) ->
    Varbind = #varbind{oid          = Oid, 
		       variabletype = 'NULL',
		       value        = 'NULL',
		       org_index    = OrgIdx},
    Pdu     = #pdu{type         = 'get-response',
		   request_id   = ReqId, 
		   error_status = noError, 
		   error_index  = 0,
		   varbinds     = [Varbind]},
    enc_message(Vsn, Community, Pdu).

get_next_request(Vsn, Community, Oid, OrgIdx, ReqId) ->
    Varbind = #varbind{oid          = Oid, 
		       variabletype = 'NULL',
		       value        = 'NULL',
		       org_index    = OrgIdx},
    Pdu     = #pdu{type         = 'get-next-request',
		   request_id   = ReqId, 
		   error_status = noError, 
		   error_index  = 0,
		   varbinds     = [Varbind]},
    enc_message(Vsn, Community, Pdu).

bulk_get_response(Vsn, Community, Bulk, ReqId) ->
    Pdu     = #pdu{type         = 'get-response',
		   request_id   = ReqId,
		   error_status = noError,
		   error_index  = 0,
		   varbinds     = Bulk},
    enc_message(Vsn, Community, Pdu).
    
get_response(Vsn, Community, VarbindData, ReqId) ->
    Varbinds = varbinds(VarbindData, []),
    Pdu     = #pdu{type         = 'get-response',
		   request_id   = ReqId,
		   error_status = noError,
		   error_index  = 0,
		   varbinds     = Varbinds},
    enc_message(Vsn, Community, Pdu).
    
get_response(Vsn, Community, Oid, Type, Value, OrgIdx, ReqId) ->
    Varbind = #varbind{oid          = Oid, 
		       variabletype = Type,
		       value        = Value,
		       org_index    = OrgIdx},
    Pdu     = #pdu{type         = 'get-response',
		   request_id   = ReqId,
		   error_status = noError,
		   error_index  = 0,
		   varbinds     = [Varbind]},
    enc_message(Vsn, Community, Pdu).

set_request(Vsn, Community, Oid, Type, Value, OrgIdx, ReqId) ->
    Varbind = #varbind{oid          = Oid, 
		       variabletype = Type,
		       value        = Value,
		       org_index    = OrgIdx},
    Pdu     = #pdu{type         = 'set-request',
		   request_id   = ReqId,
		   error_status = noError,
		   error_index  = 0,
		   varbinds     = [Varbind]},
    enc_message(Vsn, Community, Pdu).


get_bulk_request(Community, ReqId) ->
    Varbinds = [#varbind{oid          = [1,3,6,1,2,1,1,1],
			 variabletype = 'NULL',
			 value        = 'NULL',
			 org_index    = 1},
		#varbind{oid          = [1,3,7,1],
			 variabletype = 'NULL',
			 value        = 'NULL',
			 org_index    = 2}],
    Pdu = #pdu{type         = 'get-bulk-request',
	       request_id   = ReqId,
	       error_status = 1,
	       error_index  = 1,
	       varbinds     = Varbinds},
    enc_message('version-2', Community, Pdu).

inform_request(Community, ReqId) ->
    Varbinds = [#varbind{oid          = [1,3,6,1,2,1,1,3,0],
			 variabletype = 'TimeTicks',
			 value        = 4046,
			 org_index    = 1},
		#varbind{oid          = [1,3,6,1,6,3,1,1,4,1,0],
			 variabletype = 'OBJECT IDENTIFIER',
			 value        = [1,3,6,1,2,1,1,0,1],
			 org_index    = 2}],
    Pdu = #pdu{type         = 'inform-request',
	       request_id   = ReqId,
	       error_status = noError,
	       error_index  = 0,
	       varbinds     = Varbinds},
    enc_message('version-2', Community, Pdu).

snmpv2_trap(Community, ReqId) ->
    Varbinds = [#varbind{oid          = [1,3,6,1,2,1,1,3,0],
			 variabletype = 'TimeTicks',
			 value        = 3945,
			 org_index    = 1},
		#varbind{oid          = [1,3,6,1,6,3,1,1,4,1,0],
			 variabletype = 'OBJECT IDENTIFIER',
			 value        = [1,3,6,1,2,1,11,1],
			 org_index    = 2}],
    Pdu = #pdu{type         = 'snmpv2-trap',
	       request_id   = ReqId,
	       error_status = noError,
	       error_index  = 0,
	       varbinds     = Varbinds},
    enc_message('version-2', Community, Pdu).

% report() ->
%     Varbind = #varbind{oid          = ?snmpUnknownPDUHandlers,
% 		       variabletype = 'Counter32',
% 		       value        = 111},
%     Pdu = #pdu{type         = report, 
% 	       request_id   = 991199,
% 	       error_status = noError, 
% 	       error_index  = 0,
% 	       varbinds     = [Varbind]},
%     enc_message('version-3', Community, Pdu).

trap(Community) ->
    Enterp    = [1,3,6,1,2,1,1],
    Oid       = [1,3,6,1,2,1,1,4,0],
    Type      = 'OCTET STRING',
    Value     = "{mbj,eklas}@erlang.ericsson.se",
    SysUpTime = 4379, 
    Spec      = 1,
    Generic   = 6, 
    AgentIp   = [127,0,0,1],
    trap(Community, Enterp, Oid, Type, Value, SysUpTime, 
	 Spec, Generic, AgentIp, 1).

%% V1 trap
trap(Community, Enterp, Oid, Type, Value, SysUpTime, 
     Spec, Generic, AgentIp, OrgIdx) ->
    Varbind = #varbind{oid          = Oid, 
		       variabletype = Type, 
		       value        = Value,
		       org_index    = OrgIdx},
    Trap = #trappdu{enterprise    = Enterp,
		    agent_addr    = AgentIp,
		    generic_trap  = Generic,
		    specific_trap = Spec,
		    time_stamp    = SysUpTime,
		    varbinds      = [Varbind]},
    enc_message('version-1', Community, Trap).

varbinds([], Varbinds) ->
    lists:reverse(Varbinds);
varbinds([{Oid, Type, Value, Idx}|T], Acc) ->
    Varbind = #varbind{oid          = Oid, 
		       variabletype = Type, 
		       value        = Value,
		       org_index    = Idx},
    varbinds(T, [Varbind|Acc]).

enc_message(Vsn, Community, Pdu) ->
    PduBytes = snmp_pdus:enc_pdu(Pdu),
    Msg      = #message{version = Vsn,
			vsn_hdr = Community,
			data    = PduBytes},
    list_to_binary(snmp_pdus:enc_message_only(Msg)).

display_info(Info) ->
    {SinceOpened, SinceLastInfo} = get_info(no_overflows, Info, {-1,-1}),
    CurrentFile = get_info(current_file, Info, -1),
    NoItems = get_info(no_current_items, Info, -1),
    NoBytes = get_info(no_current_bytes, Info, -1),
    ?NPRINT("Disk log info: "
            "~n   Number of filled since opened:    ~p"
            "~n   Number of filled since last info: ~p"
            "~n   Current file:                     ~p"
            "~n   Number of items in file:          ~p"
            "~n   Number of bytes in file:          ~p", 
            [SinceOpened, SinceLastInfo, CurrentFile, NoItems, NoBytes]).

get_info(Key, Info, Def) ->
    case lists:keysearch(Key, 1, Info) of
	{value, {Key, Val}} ->
	    Val;
	false ->
	    Def
    end.

join(D, F) ->
    filename:join(D, F).

