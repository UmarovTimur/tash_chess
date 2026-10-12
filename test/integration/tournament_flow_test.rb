require "test_helper"

class TournamentFlowTest < ActionDispatch::IntegrationTest
  test "runs a Swiss tournament from registration to final standings" do
    post tournaments_path, params: { tournament: { name: "Friday Blitz", pairing_system: "swiss", rounds_count: "2", location: "Club" } }
    tournament = Tournament.find_by!(name: "Friday Blitz")
    assert_redirected_to tournament_path(tournament)

    follow_redirect!
    assert_select "button", text: "Start tournament"
    assert_select "input[name='player_ids[]']", count: 8

    members = [ players(:anna), players(:boris), players(:chen), players(:daria) ]
    post tournament_participations_path(tournament), params: { player_ids: members.map(&:id) }
    assert_equal 4, tournament.participations.count

    participation = tournament.participations.find_by!(player: players(:daria))
    delete tournament_participation_path(tournament, participation)
    post tournament_participations_path(tournament), params: { player_ids: [ players(:daria).id, players(:anna).id ] }
    assert_equal 4, tournament.participations.count, "already registered players are skipped"

    post start_tournament_path(tournament)
    round = tournament.rounds.first
    assert_redirected_to tournament_round_path(tournament, round)
    assert tournament.reload.in_progress?

    get tournament_round_path(tournament, round)
    assert_response :success
    assert_select ".board-no", text: "1"
    assert_select ".board-no", text: "2"
    assert_select "tr.game", count: 2

    post tournament_rounds_path(tournament)
    assert_match "every result", flash[:alert], "can't pair round 2 before round 1 is complete"

    board1, board2 = round.games.to_a
    patch game_path(board1), params: { game: { result: "white_won" } }
    assert_redirected_to tournament_round_path(tournament, round)
    patch game_path(board2), params: { game: { result: "draw" } }
    assert_equal %w[ white_won draw ], round.games.reload.map(&:result)

    get tournament_standings_path(tournament)
    assert_response :success
    assert_select "table.table--standings tbody tr", count: 4
    assert_select "tbody tr:first-child td a", text: board1.white_player.name

    post tournament_rounds_path(tournament)
    assert_redirected_to tournament_round_path(tournament, 2)
    play_round(tournament.rounds.last)

    get tournament_round_path(tournament, 2)
    assert_select "button", text: "Finish tournament"

    post finish_tournament_path(tournament)
    assert_redirected_to tournament_standings_path(tournament)
    assert tournament.reload.finished?

    follow_redirect!
    assert_select "h2", text: "Final standings"

    patch game_path(board1), params: { game: { result: "black_won" } }
    assert_equal "white_won", board1.reload.result, "results are locked after the finish"
  end

  test "round robin shows every round's pairings at the start" do
    tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(5))
    post start_tournament_path(tournament)

    get tournament_round_path(tournament, 5)
    assert_response :success
    assert_select ".bye-label", text: "Rests"
    assert_select ".rounds__link", count: 5
  end

  test "can't add members to a running round robin" do
    tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(4))
    tournament.start

    post tournament_participations_path(tournament), params: { player_ids: [ players(:hana).id ] }
    assert_redirected_to tournament_path(tournament)
    assert_equal 4, tournament.participations.count
  end

  test "a bye result can't be changed" do
    tournament = create_tournament(players: Player.by_rating.first(3), rounds: 2)
    tournament.start
    bye = tournament.games.bye.first

    patch game_path(bye), params: { game: { result: "black_won" } }
    assert bye.reload.bye?
  end

  test "deleting the latest Swiss round" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 3)
    tournament.start
    play_round(tournament.current_round)
    tournament.pair_next_round

    delete tournament_round_path(tournament, 2)
    assert_redirected_to tournament_round_path(tournament, 1)
    assert_equal [ 1 ], tournament.rounds.reload.pluck(:number)
  end

  test "all pages render for a running tournament" do
    tournament = create_tournament(players: Player.all, rounds: 3)
    tournament.start

    [ tournaments_path, tournament_path(tournament), edit_tournament_path(tournament), tournament_standings_path(tournament),
      tournament_round_path(tournament, 1), player_path(players(:anna)) ].each do |path|
      get path
      assert_response :success, path
    end
  end
end
