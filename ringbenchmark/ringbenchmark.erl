-module(ringbenchmark).
-author(wangkexiong@gmail.com).
-vsn(1.0).

-define(SEC2MICROSEC(X), X/1000000).

-ifdef(DEBUG).
    -compile(export_all).
    -define(TRACE(X), log4erl:debug(X)).
    -define(TRACE(X, Y), log4erl:debug(X, Y)).
-else.
    -export([start/1]).
    -define(TRACE(X), void).
    -define(TRACE(X, Y), void).
-endif.

%%%-----------------------------------------------------------------------------
%%Start Ring manager process in main process
%%%-----------------------------------------------------------------------------
start([N, M]) ->
    application:start(log4erl),
    log4erl:conf("log4erl.conf"),
    log4erl:info(simple, "Programming Erlang Chap.08 - Ring process benchmark"),

    %% Returns the maximum number of simultaneously 
    %% existing processes at the local node as an integer.
    %% This limit can be configured at startup
    %% by using the +P command line flag of erl(1).
    Max = erlang:system_info(process_limit),

    TotalProcess = list_to_integer(atom_to_list(N)),
    Repeat = list_to_integer(atom_to_list(M)),

    if TotalProcess > Max ->
            log4erl:info("Maximum number of processes: ~p", [Max]),
            init:stop();
       TotalProcess =< Max ->
            log4erl:info("Start Ring Manager in main process: ~p", [self()]),
            spawn(fun() -> spawnRing(TotalProcess, Repeat) end)
    end,

    log4erl:info("Destroy Main task process: ~p", [self()]),
    ok.

%%%-----------------------------------------------------------------------------
%% Create N processes in a ring. 
%% Send a message round the ring M times,
%% so that N * M messages get sent. 
%% Time performance for different values of N and M.
%%%-----------------------------------------------------------------------------
spawnRing(N, M) ->
    log4erl:info("Ring Manager process: ~p", [self()]),

    %% run-time is the sum of the run-time for all threads
    %% in the Erlang run-time system and may therefore be greater than
    %% the wall-clock time. wall_clock can be used in the same manner as runtime,
    %% except that real time is measured as opposed to runtime or CPU time.
    statistics(runtime),
    statistics(wall_clock),
    NextPid = spawnNext(self(), N),

    receive
        ringCreatedDone ->
            {_, RT} = statistics(runtime),
            {_, WC} = statistics(wall_clock),
            log4erl:info("Linked Ring created finished, time=~p (~p) milliseconds", [RT, WC]),
            RoundStartTime = now(),
            NextPid!{M, RoundStartTime},
            startLoop({NextPid, M}, RoundStartTime)
    end,

    ok.

%%%-----------------------------------------------------------------------------
%% Start new round trip when receive ringLoopDone until M times
%%%-----------------------------------------------------------------------------
startLoop({_, 0}, TestStart) ->
    Duration = ?SEC2MICROSEC(timer:now_diff(now(), TestStart)),
    log4erl:info("** Total Testing Duration: ~p seconds **", [Duration]),
    init:stop();
startLoop({_, 1}, TestStart) ->
    receive
        {ringLoopDone, RoundStart} ->
            Duration = ?SEC2MICROSEC(timer:now_diff(now(), RoundStart)),
            log4erl:info("** Round looped Finished in ~p seconds**~n", [Duration])
    end,

    startLoop({0, 0}, TestStart);
startLoop({NextPid, M}, TestStart) ->
    receive
        {ringLoopDone, RoundStart} ->
            NextRoundStart = now(),
            Duration = ?SEC2MICROSEC(timer:now_diff(NextRoundStart, RoundStart)),
            log4erl:info("** Round looped Finished in ~p seconds**~n", [Duration]),
            NextPid!{M-1, NextRoundStart}
    end,

    startLoop({NextPid, M-1}, TestStart).

%%%-----------------------------------------------------------------------------
%% Create process and define process manner
%%%-----------------------------------------------------------------------------
spawnNext(RingManager, 0) ->
    RingManager!ringCreatedDone,
    RingManager;
spawnNext(RingManager, N) ->
    spawn_link(fun() ->
                    NextPid = spawnNext(RingManager, N-1),
                    loopMsg(NextPid, N)
               end).

%%%-----------------------------------------------------------------------------
%% Process behavior: transmit whatever received until the last process
%% return ringLoopDone to ring manager process
%%%-----------------------------------------------------------------------------
loopMsg(NextPid, 1) ->
    receive
        {Seq, RoundStart} ->
            %% Because output log for each process will consume lot of time,
            %% Only enable this when in debug mode.
            %% And in debug mode, the benchmark time will be larger than your think.
            ?TRACE("Process ~p received #~p", [self(), Seq]),
            NextPid!{ringLoopDone, RoundStart}
    end,
    loopMsg(NextPid, 1);
loopMsg(NextPid, N) ->
    receive
        Message ->
            {Seq, _} = Message,
            %% Because output log for each process will consume lot of time,
            %% Only enable this when in debug mode.
            %% And in debug mode, the benchmark time will be larger than your think.
            ?TRACE("Process ~p received #~p", [self(), Seq]),
            NextPid!Message
    end,
    loopMsg(NextPid, N).
