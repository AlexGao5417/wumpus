:- module(wumpus, [initialState/5, guess/3, updateState/4]).

% visited places, pit, wall, shot, upperbound
initialState(NR, NC, XS, YS, State0) :-
    between(1, NC, XS),
    between(1, NR, YS),
    append([[(XS, YS)]], [[], [], [], [], [], [], [], [NR, NC]], State0).
%            0visited  1pit  2wall  3shot  4wumpus, 5upperbound
% State0 = [[(1, 3)],  [],   [],    [],      [],     [3, 8]].

%% given the current state 'State0' returns a new state 'State' and a 'Guess'
%           0visited   1pit  2wall  3shot  4wumpus   5damp   6smell   7stench  8upperbound
% State0 = [[(1, 3)],  [],   [],     [],     []       []      []        []      [3, 8]].
guess(State0, State, Guess) :-
    nth0(0, State0, Visited), % get all visited nodes.
    nth0(0, Visited, Start),
    nth0(1, State0, Pit), % get all pit nodes.
    nth0(2, State0, Wall),
    % nth0(3, State0, Shot),
    % nth0(4, State0, Wumpus),
    nth0(5, State0, Damp),
    nth0(6, State0, Smell),
    nth0(7, State0, Stench),
    nth0(8, State0, Bound),


    append(Smell, Stench, MaybeW),
    length(MaybeW, MWL),
    % length(Wumpus, WpLen),
    ( MWL > 0 ->
        random_member(End, MaybeW)
    ; MWL =:= 0 ->
        findall((XE, YE), randomNode(Visited, Pit, Wall, Bound, XE, YE), A),
        random_member(End, A)
    ),
    % findall((XE, YE), randomNode(Visited, Pit, Wall, Bound, XE, YE), A),
    % random_member(End, A),
    write(End),
    State = State0,
    findall(Guess5, findPath(Start, End, Guess5, Pit, Wall, Damp, Smell, Stench, Bound), AP),
    random_member(Guess3, AP),
    % findPath(Start, End, Guess3, Pit, Wall, Damp, Smell, Stench, Bound), !,  % get the first answer

    add_shoot(Start, Guess3, Damp, Smell, Stench, Bound, Guess2),
    % add_shoot(Start, Guess3, Damp, Smell, Stench, Bound, Guess2), !,
    delete(Guess2, [], Guess), !.


%% find a Path that the End node is randomly selected and not a Pit
findPath(Start, End, Path, Pit, Wall, Damp, Smell, Stench, [NR, NC]) :-
    findPath(Start, End, [Start], Path, Pit, Wall, Damp, Smell, Stench, [NR, NC], 100).
%%  findPath(Start, End, Previous, Path, Pit, [Energy, Row, Column]).
findPath(Start, Start, _, [], _, _, _, _, _, _, _).
findPath(Start, End, Prev, [Dirn|Path], Pit, Wall, Damp, Smell, Stench, [NR, NC], E) :-
    E > 0,
    move(Start, Dirn, Med, [NR, NC]), % find a Med as the next Start
    \+ member(Med, Prev), % dont visit previous nodes
    \+ member(Med, Pit), % dont go into Pit
    \+ member(Med, Wall), % dont hit the wall
    F is E - 1, % each move costs 1 energy
    findPath(Med, End, [Med|Prev], Path, Pit, Wall, Damp, Smell, Stench, [NR, NC], F).

%% move the robot to next node
move((X, Y), north, (XE, YE), _) :- XE is X, YE is Y - 1, YE > 0.
move((X, Y), east, (XE, YE), [_, NC]) :- YE is Y, XE is X + 1, XE =< NC.
move((X, Y), south, (XE, YE), [NR, _]) :- XE is X, YE is Y + 1, YE =< NR.
move((X, Y), west, (XE, YE), _) :- XE is X - 1, YE is Y, XE > 0.

%% pick a random End node that has not been visited and is not a Pit
randomNode(Visited, Pit, Wall, [NR, NC], X, Y) :-
    between(1, NC, X),
    between(1, NR, Y),
    \+ member((X, Y), Visited),
    \+ member((X, Y), Pit),
    \+ member((X, Y), Wall).

%           0visited   1pit  2wall  3shot  4wumpus   5damp   6smell   7stench  8upperbound
% State0 = [[(1, 3)],  [],   [],     [],     []       []      []        []      [3, 8]].
updateState(State0, Guess, Feedback, State) :-
    nth0(0, State0, Visited),
    nth0(1, State0, Pit),
    nth0(2, State0, Wall),
    nth0(3, State0, Shot),
    nth0(4, State0, Wumpus),
    nth0(5, State0, Damp),
    nth0(6, State0, Smell),
    nth0(7, State0, Stench),
    nth0(8, State0, Bound),
    nth0(0, Visited, LastPst), % get last position

    append([dh], Guess, Guess1),
    visited(Guess1, Feedback, LastPst, Bound, NewVstd, NewWall, NewShot, NewDamp, NewSmell, NewStench), % new visited nodes
    delete(NewVstd, [], UV),
    append(Visited, UV, UpdatedVstd), % update visited nodes
    append(Wall, NewWall, UW),
    remain(UW, UpdatedWall), % get rid of [] and duplicate walls

    delete(NewShot, [], US),
    append(Shot, US, UpdatedShot),

    delete(NewDamp, [], UD),
    append(Damp, UD, UpdatedDamp),

    delete(NewSmell, [], UM),
    append(Smell, UM, UpdatedSmell),

    delete(NewStench, [], UT),
    append(Stench, UT, UpdatedStench),



    last(Feedback, LastFB), % get the last feedback, wumpus or pit
    last(UpdatedVstd, LastVstd),
    secondLast(UpdatedVstd, SLV),
    dead(LastFB, LastVstd, SLV, Pit, Wumpus, UpdatedPit, UpdatedWumpus),


    State = [UpdatedVstd, UpdatedPit, UpdatedWall, UpdatedShot, UpdatedWumpus, UpdatedDamp, UpdatedSmell, UpdatedStench, Bound], !.



% deduce the new Visited nodes according to the Feedback
visited(_, [], _, _, [], [], [], [], [], []).
visited([D,Dirn|RestG], [FB|RestF], LastPst, Bound, [NV|RestNV], [NW|RestNW], [NS|RestNS], [ND|RestND], [NM|RestNM], [NT|RestNT]) :-
    checkFB(FB, LastPst, [D,Dirn], NV, Bound, NewPst, NW, NS, ND, NM, NT),
    visited([Dirn|RestG], RestF, NewPst, Bound, RestNV, RestNW, RestNS, RestND, RestNM, RestNT).


checkFB(wall, LastPst, [_,Dirn], NV, Bound, NewPst, NW, NS, ND, NM, NT) :-
    NV = [],
    NS = [],
    ND = [],
    NM = [],
    NT = [],
    NewPst = LastPst,
    move(LastPst, Dirn, NW, Bound).
checkFB(miss, LastPst, [D,_], NV, _, NewPst, NW, NS, ND, NM, NT) :-
    NV = [],
    NewPst = LastPst,
    NW = [],
    ND = [],
    NM = [],
    NT = [],
    NS = D-NewPst.
checkFB(empty, LastPst, [_,Dirn], NV, Bound, NewPst, NW, NS, ND, NM, NT) :-
    move(LastPst, Dirn, (NextX, NextY), Bound),
    NV = (NextX, NextY),
    NewPst = NV,
    ND = [],
    NM = [],
    NT = [],
    NW = [],
    NS = [].
checkFB(pit, LastPst, [_,Dirn], NV, Bound, NewPst, NW, NS, ND, NM, NT) :-
    move(LastPst, Dirn, (NextX, NextY), Bound),
    NV = (NextX, NextY),
    NewPst = NV,
    ND = [],
    NM = [],
    NT = [],
    NW = [], NS = [].
checkFB(wumpus, LastPst, [_,Dirn], NV, Bound, NewPst, NW, NS, ND, NM, NT) :-
    move(LastPst, Dirn, (NextX, NextY), Bound),
    NV = (NextX, NextY),
    NewPst = NV,
    ND = [],
    NM = [],
    NT = [],
    NW = [], NS = [].
checkFB(damp, LastPst, [_,Dirn], NV, Bound, NewPst, NW, NS, ND, NM, NT) :-
    move(LastPst, Dirn, (NextX, NextY), Bound),
    NV = (NextX, NextY),
    NewPst = NV,
    ND = (NextX, NextY),
    NM = [],
    NT = [],
    NW = [], NS = [].
checkFB(stench, LastPst, [_,Dirn], NV, Bound, NewPst, NW, NS, ND, NM, NT) :-
    move(LastPst, Dirn, (NextX, NextY), Bound),
    NV = (NextX, NextY),
    NewPst = NV,
    ND = [],
    NM = [],
    NT = (NextX, NextY),
    NW = [], NS = [].
checkFB(smell, LastPst, [_,Dirn], NV, Bound, NewPst, NW, NS, ND, NM, NT) :-
    move(LastPst, Dirn, (NextX, NextY), Bound),
    NV = (NextX, NextY),
    NewPst = NV,
    ND = [],
    NM = (NextX, NextY),
    NT = [],
    NW = [], NS = [].




dead(pit, LastVstd, _, Pit, Wumpus, UpdatedPit, UpdatedWumpus) :-
    append(Pit, [LastVstd], UpdatedPit),
    UpdatedWumpus = Wumpus.
dead(wumpus, LastVstd, SLV, Pit, Wumpus, UpdatedPit, UpdatedWumpus) :-
    append(Wumpus, [SLV, LastVstd], UpdatedWumpus),
    UpdatedPit = Pit.
dead(_, _, _, Pit, Wumpus, UpdatedPit, UpdatedWumpus) :-
    UpdatedPit = Pit,
    UpdatedWumpus = Wumpus.


remain(X, Y) :- sort(X, Z), delete(Z, [], Y).

secondLast(L, X) :-
    append(_, [X, _], L).

add_shoot(_, [], _, _, _, _, []).
add_shoot(Pst, [Dirn|Rest], Damp, Smell, Stench, Bound, [Dirn, A|After]) :-
    move(Pst, Dirn, NewPst, Bound),
    append(Damp, Smell, DS),
    append(DS, Stench, ShootPst),
    ( member(NewPst, ShootPst) ->
        A = shoot,
        add_shoot(NewPst, Rest, Damp, Smell, Stench, Bound, After)
    ; A = [],
      add_shoot(NewPst, Rest, Damp, Smell, Stench, Bound, After)
    ).
    % ( member(NewPst, Damp) ->
    %     A = shoot,
    %     add_shoot(NewPst, Rest, Damp, Smell, Stench, Bound, After)
    % ; member(NewPst, Smell) ->
    %     A = shoot,
    %     add_shoot(NewPst, Rest, Damp, Smell, Stench, Bound, After)
    % ; member(NewPst, Stench) ->
    %     A = shoot,
    %     add_shoot(NewPst, Rest, Damp, Smell, Stench, Bound, After)
    % ; A = [],
    %   add_shoot(NewPst, Rest, Damp, Smell, Stench, Bound, After)
    % ).
