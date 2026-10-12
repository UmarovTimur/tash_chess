require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  test "Swiss needs a number of rounds, round robin doesn't" do
    assert_not Tournament.new(name: "Swiss", pairing_system: :swiss).valid?
    assert Tournament.new(name: "RR", pairing_system: :round_robin).valid?
  end

  test "can't start with fewer than two members" do
    tournament = create_tournament(players: [ players(:anna) ])

    assert_not tournament.start
    assert tournament.reload.registration?
    assert_match "At least 2", tournament.errors.full_messages.to_sentence
  end

  test "can't start a Swiss with more rounds than possible opponents" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 4)

    assert_not tournament.start
    assert_match "maximum is 3", tournament.errors.full_messages.to_sentence
  end

  test "next round needs all results of the current one" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 3)
    tournament.start

    assert_not tournament.pair_next_round
    play_round(tournament.current_round)
    assert tournament.pair_next_round
    assert_equal 2, tournament.rounds.count
  end

  test "can't pair beyond the planned rounds, then finishes" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 1)
    tournament.start
    play_round(tournament.current_round)

    assert_not tournament.can_pair_next_round?
    assert tournament.finish
    assert tournament.reload.finished?
  end

  test "reset removes pairings only before any result" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 3)
    tournament.start
    assert tournament.can_reset?

    tournament.current_round.games.first.update!(result: :draw)
    assert_not tournament.reset

    tournament.current_round.games.first.update!(result: :pending)
    assert tournament.reset
    assert tournament.reload.registration?
    assert_equal 0, tournament.rounds.count
  end

  test "deleting the only round returns to registration" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 3)
    tournament.start

    assert tournament.remove_last_round
    assert tournament.reload.registration?
  end

  test "pairing system is locked after the start" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 3)
    tournament.start

    assert_not tournament.update(pairing_system: :round_robin)
  end

  test "members with games can't leave" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 3)
    tournament.start

    assert_not tournament.participations.first.destroy
  end

  test "a tournament with results can be deleted" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 3)
    tournament.start
    play_round(tournament.current_round)

    assert_difference -> { Tournament.count } => -1, -> { Game.count } => -2, -> { Participation.count } => -4 do
      tournament.destroy!
    end
    assert_equal 8, Player.count, "players stay in the roster"
  end
end
