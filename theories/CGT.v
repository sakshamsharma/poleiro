(* begin hide *)

Require Import Coq.Lists.List.

Notation "[]" := nil : list_scope.
Notation "[ x , .. , y ]" := (cons x .. (cons y nil) .. ) : list_scope.

Open Scope bool_scope.

(* end hide *)

(* In this post, I will show how to formalize a small part of #<a
href="http://en.wikipedia.org/wiki/Combinatorial_game_theory>#
_combinatorial game theory_#</a># using Coq. Combinatorial game theory
attempts to model sequential, deterministic games between two players,
both of which take turns causing the game state to change. It
restricts itself to _perfect information_ games, where the current
configuration of the game is known to both players. Thus, it can be
used to study games such as chess, tic-tac-toe, and go, but not games
such as poker or blackjack.

The foundations of combinatorial game theory are simple yet
powerful. We represent a game configuration as the set of moves that
are available to each player. Each move, on the other hand, is just
another possible game configuration. A game ends when a player has to
play but doesn't have any moves left, in which case the other player
wins. This definition, although minimal, allows us to represent and
reason about combinatorial games generically, abstracting away from
the details of individual games.

Here's how one can translate the above definition as a Coq datatype:
*)

Inductive game := Game {
  left_moves : list game;
  right_moves : list game
}.


(* We can now define some standard games... *)

Definition zero : game := Game [] [].
Definition one : game := Game [zero] [].
Definition two : game := Game [one] [].
Definition minus_one : game := Game [] [zero].
Definition star : game := Game [zero] [zero].

(* ... and some useful functions on them, such as negate, which flips a game. *)

Fixpoint negate (g : game) : game :=
  match g with
    | Game l r =>
      Game (map negate r) (map negate l)
  end.

(* Notice that negate is not obviously structurally recursive, but the
Coq termination checker is smart enough to understand this is OK. This
will be very handy on the rest on this development. *)

Lemma negate_test : negate one = minus_one.
Proof. reflexivity. Qed.

(* The downside of using just one inductive type for game is that the
induction principle generated by Coq is too weak to be useful. You
don't have to worry too much about this, it's just here for
completeness *)

Lemma lift_forall :
  forall T (P : T -> Prop),
    (forall t, P t) ->
    forall l, Forall P l.
Proof. induction l; auto. Defined.

Definition game_ind' (P : game -> Prop)
                     (H : forall l r, Forall P l -> Forall P r -> P (Game l r)) :
  forall g : game, P g :=
  fix F (g : game) : P g :=
  match g with
    | Game l r =>
      H l r (lift_forall _ P F l) (lift_forall _ P F r)
  end.

(* Using this principle, one can prove some fun facts about negate: *)

Lemma negate_involutive :
  forall g, negate (negate g) = g.
Proof.
  induction g as [l r IHl IHr] using game_ind'.
  simpl.
  f_equal.
  - clear IHr.
    induction IHl as [|g gs Hg _ IH]; simpl; eauto.
    rewrite Hg, IH.
    reflexivity.
  - clear IHl.
    induction IHr as [|g gs Hg _ IH]; simpl; eauto.
    rewrite Hg, IH.
    reflexivity.
Qed.

(* Let's define a more interesting function on games: sum. As we've
seen, Coq rejects the direct definition of sum, because it's not
structurally recursive on a single argument. We use the trick here of
passing an additional parameter to sum. *)

Fixpoint height (g : game) :=
  match g with
    | Game l r =>
      S (max (fold_left max (map height l) 0)
             (fold_left max (map height r) 0))
  end.

Fixpoint sum_aux (sum_of_heights : nat) (g1 g2 : game) :=
  match sum_of_heights with
    | 0 =>
      (* We'll never reach 0 normally, so we just return some arbitrary value here *)
      zero
    | S n =>
      match g1, g2 with
        | Game l1 r1, Game l2 r2 =>
          Game (map (fun g1 => sum_aux n g1 g2) l1 ++
                map (fun g2 => sum_aux n g1 g2) l2)
               (map (fun g1 => sum_aux n g1 g2) r1 ++
                map (fun g2 => sum_aux n g1 g2) r2)
      end
  end.

Definition sum (g1 g2 : game) : game :=
  sum_aux (height g1 + height g2) g1 g2.

(* Using sum, we can define minus *)

Definition minus (g1 g2 : game) : game :=
  sum g1 (negate g2).

(* Now let's analyze the winning profile of games. We begin by
defining two (mutually recursive) functions that return true if left
can win if it plays first (resp. if it plays second) *)

Fixpoint left_wins_first (g : game) : bool :=
  existsb left_wins_second (left_moves g)
with left_wins_second (g : game) : bool :=
  forallb left_wins_first (right_moves g).

(* Defining if left always wins now is easy. *)

Definition left_wins (g : game) : bool :=
  match g with
    | Game l r =>
      existsb left_wins_second l &&
      forallb left_wins_first r
  end.

(* We can use the previous functions and negate to define similar
functions for the right player. *)

Definition right_wins_first (g : game) : bool :=
  left_wins_first (negate g).
Definition right_wins_second (g : game) : bool :=
  left_wins_second (negate g).
Definition right_wins (g : game) : bool :=
  left_wins (negate g).

(* Finally, two functions that return true iff the first (resp. the
second) player to play always wins *)

Fixpoint first_wins (g : game) : bool :=
  match g with
    | Game l r =>
      existsb left_wins_second l &&
      existsb left_wins_second r
  end.

Definition second_wins (g : game) : bool :=
  match g with
    | Game l r =>
      forallb right_wins_first l &&
      forallb left_wins_first r
  end.

(* We can check that these functions behave as expected on some arguments: *)

Lemma left_wins_test_1 : left_wins zero = false.
Proof. reflexivity. Qed.
Lemma left_wins_test_2 : left_wins one = true.
Proof. reflexivity. Qed.
Lemma left_wins_test_3 : left_wins two = true.
Proof. reflexivity. Qed.

Lemma right_wins_test_1 : right_wins zero = false.
Proof. reflexivity. Qed.
Lemma right_wins_test_2 : right_wins one = false.
Proof. reflexivity. Qed.
Lemma right_wins_test_3 : right_wins minus_one = true.
Proof. reflexivity. Qed.

Lemma first_wins_test_1 : first_wins zero = false.
Proof. reflexivity. Qed.
Lemma first_wins_test_2 : first_wins one = false.
Proof. reflexivity. Qed.
Lemma first_wins_test_3 : first_wins star = true.
Proof. reflexivity. Qed.

Lemma second_wins_test_1 : second_wins zero = true.
Proof. reflexivity. Qed.
Lemma second_wins_test_2 : second_wins one = false.
Proof. reflexivity. Qed.
Lemma second_wins_test_3 : second_wins star = false.
Proof. reflexivity. Qed.

(* Using those, we can finally define comparison functions between games. *)

Definition gt (g1 g2 : game) : bool := left_wins (minus g1 g2).
Definition lt (g1 g2 : game) : bool := right_wins (minus g1 g2).
Definition eq (g1 g2 : game) : bool := second_wins (minus g1 g2).
Definition incomp (g1 g2 : game) : bool := first_wins (minus g1 g2).

Lemma gt_test : gt one zero = true.
Proof. reflexivity. Qed.
Lemma lt_test : lt minus_one zero = true.
Proof. reflexivity. Qed.
Lemma eq_test : eq (sum star star) zero = true.
Proof. reflexivity. Qed.
Lemma incomp_test : incomp star zero = true.
Proof. reflexivity. Qed.

(* In case you're thinking this is too gross, you can abstract things
a little bit more. Let's define a datatype for representing players,
and a function for comparing members of that type. *)

Inductive side : Type := Left | Right.

Definition side_eq (s1 s2 : side) : bool :=
  match s1, s2 with
    | Left, Left => true
    | Right, Right => true
    | _, _ => false
  end.

(* The next function alternates between players *)

Definition other (s : side) : side :=
  match s with
    | Left => Right
    | Right => Left
  end.

(* And moves selects the moves of a player from a game *)

Definition moves (g : game) (s : side) :=
  match s with
    | Left => left_moves g
    | Right => right_moves g
  end.

(* We can now write a function [wins s first g] that returns true iff
player [s] always wins game [g] when player [first] begins playing. *)

Fixpoint wins (s first : side) (g : game) : bool :=
  if side_eq s first then
    existsb (wins s (other first)) (moves g first)
  else
    forallb (wins s (other first)) (moves g first).

(* Now, we can define left_wins and right_wins generically: *)

Definition always_wins s g := wins s s g && wins s (other s) g.
