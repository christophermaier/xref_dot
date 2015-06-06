-module(xref_dot_tests).
-include_lib("eunit/include/eunit.hrl").

mfa_node_label_test() ->
    assert_iolist("foo:bar/3",
                 xref_dot:node_label({foo,bar,3})).

assert_iolist(ExpectedString, ActualIOList) ->
    ?assertEqual(ExpectedString, lists:flatten(ActualIOList)).
