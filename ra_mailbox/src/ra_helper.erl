-module(ra_helper).
-export([start_cluster/4]).

%% @doc Starts a Ra cluster with a single server ID, avoiding Elixir's keyword list issue.
%% This function constructs the server IDs list in pure Erlang and calls Ra's start_cluster.
%% Parameters:
%%   System - the Ra system name (atom, e.g. 'default')
%%   ClusterName - the cluster name (atom or binary)
%%   Machine - the machine configuration tuple {module, Module, Args} or {simple, Fun, InitialState}
%%   ServerId - a single server ID tuple {Name, Node}
%% Returns: Same as ra:start_cluster/4
start_cluster(System, ClusterName, Machine, ServerId) ->
    % Construct server IDs list in pure Erlang
    % This avoids Elixir's keyword list interpretation
    ServerIds = [ServerId],
    % Call Ra's start_cluster/4 which calls start_cluster/5 internally with default timeout
    ra:start_cluster(System, ClusterName, Machine, ServerIds).
