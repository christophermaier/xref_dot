-module(xref_dot).

%% * Pass in formatting functions in a proplist.
%% * Have default functions for, say, call graphs
%% * Selectively disable certain things with no-op functions
%% * Stick all the purely dot-related functions in one module
%% * Unit tests!
%% * Functional tests! (can it generate something that dot can parse?)
%% * DONE erlang.mk
%% * Module for ready-made graph functions, bundling analysis with graph
%%   creation. Can override formatting functions as needed by passing in
%%   a proplist of options, which will get prepended onto any defaults.
%% * Stick xref queries into another module
%%   tests for them will be a little trickier... run it on a few
%%   open-source projects at specific tags?
%% * Toggle clustered subgraphs with a function that prepends "cluster"
%%   to a name function.
%% * Create an "extract cluster from node" function to pass into the
%%   dict-generating function
%% * extract call-graph-specific formatting functions to separate module
%% * Pass in attributes as a list of arbitrary functions; map over them
%%   all to generate a node's attributes, e.g.
%%
%% Further Graphviz ideas:
%% 1. Process tree of live server (see evernote note for some code)
%% 2. FSM state transition graph (Ulf Wiger has code floating around somewhere)
%%
-compile([export_all]).

%% xref:start(foo).
%% xref:add_directory(foo, "/path/to/some/interesting/ebin").
%% {ok, Edges} = xref:q(foo, "E | M || [mod_one, mod_two, mod_three]").
%% dot_graph:digraph_to_file("my_graph.dot", Edges).

%% {ok, Edges} = dot_graph:subgraph_to_mfa(foo, {deliv_git, ensure_repo_path, 1}).
%% dot_graph:digraph_to_file("my_graph.dot", Edges).

node_label({M,F,A}) ->
    [erlang:atom_to_list(M), ":",
     erlang:atom_to_list(F), "/",
     erlang:integer_to_list(A)].

node_name({M,F,A}) ->
    [erlang:atom_to_list(M), "_",
     erlang:atom_to_list(F), "_",
     erlang:integer_to_list(A)].

all_nodes(Edges) ->
    lists:usort(lists:flatmap(fun erlang:tuple_to_list/1, Edges)).

node_color(_) -> white.

%% empty iolist
no_op(_) -> [].

label_attr(ToBeLabeled, LabelFun) ->
    [ "label = \"", LabelFun(ToBeLabeled), "\";" ].

fillcolor_attr(Node, ColorFun) ->
    [ "fillcolor = \"", erlang:atom_to_list(ColorFun(Node)), "\";" ].

node_desc(Node, NameFun, LabelFun, ColorFun) ->
    [NameFun(Node), " [", label_attr(Node, LabelFun), ", ", fillcolor_attr(Node, ColorFun), "]\n" ].

node_list(Nodes, NameFun, LabelFun, ColorFun) ->
    [node_desc(N, NameFun, LabelFun, ColorFun) || N <- Nodes ].

nodes_only_list(Nodes, NameFun) ->
    [ [NameFun(Node), ";\n"] || Node <- Nodes ].

edge_list(Edges, NameFun) ->
    [[NameFun(From), " -> ", NameFun(To), ";", $\n] || {From, To} <- Edges].

subgraph_from_mfa({M,_,_}) -> M.

%% returns dict(Subgraph -> Node list)
nodes_to_subgraph(Nodes, SubgraphFun) ->
    lists:foldl(fun(Node, Dict) ->
                        Subgraph = SubgraphFun(Node),
                        dict:update(Subgraph,
                                    fun(Old) -> [Node | Old] end,
                                    [Node],
                                    Dict)
                end,
                dict:new(),
                Nodes).

cluster_subgraph_name(Atom) ->
    [ "cluster_", erlang:atom_to_list(Atom) ].

cluster_subgraph(Subgraph, Nodes) ->
    [ "subgraph \"cluster_", erlang:atom_to_list(Subgraph), "\" {\n",
      label_attr(Subgraph, fun erlang:atom_to_list/1),
      $\n,
      nodes_only_list(Nodes, fun node_name/1),
     "}\n"].

all_clusters(AllNodes) ->
    dict:fold(fun(Cluster,Nodes,IOList) ->
                      [ cluster_subgraph(Cluster, Nodes) | IOList ]
              end,
              [],
              nodes_to_subgraph(AllNodes, fun subgraph_from_mfa/1)).

digraph(Edges) ->
    Nodes = all_nodes(Edges),
    [
     "digraph {\n",
     node_list(Nodes, fun node_name/1, fun node_label/1, fun node_color/1),
     $\n,
     edge_list(Edges, fun node_name/1),
     $\n,
     all_clusters(Nodes),
     "}"
    ].

digraph_to_file(Filename, Edges) ->
    file:write_file(Filename, digraph(Edges)).

subgraph_to_mfa(XrefServer, {M,F,A}) ->
    CallersQ = io_lib:format("Domain := domain ((closure E) || ~p : ~p / ~p)", [M,F,A]),
    EdgesQ   = io_lib:format("(E | Domain || Domain) + (E || ~p : ~p / ~p)", [M,F,A]),

    {ok, _}     = xref:q(XrefServer, lists:flatten(CallersQ)),
    {ok, Edges} = xref:q(XrefServer, lists:flatten(EdgesQ)),

    xref:forget(XrefServer, 'Domain'),
    {ok, Edges}.
