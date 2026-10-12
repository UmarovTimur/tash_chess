require "test_helper"

class PlayersTest < ActionDispatch::IntegrationTest
  test "lists and searches players" do
    get players_path
    assert_response :success
    assert_select "td", text: "Anna Kowalska"

    get players_path(query: "chen")
    assert_select "td a", text: "Chen Wei"
    assert_select "td a", text: "Anna Kowalska", count: 0
  end

  test "creates a player" do
    assert_difference -> { Player.count } do
      post players_path, params: { player: { name: "Magnus Test", nickname: "magnus", fide_rating: "2500" } }
    end
    player = Player.find_by!(nickname: "magnus")
    assert_redirected_to player_path(player)
    assert_equal 2500, player.fide_rating
  end

  test "creates a player without rating straight into a tournament" do
    tournament = create_tournament(players: [])

    post players_path, params: { tournament_id: tournament.id, player: { name: "Walk In", nickname: "walkin", fide_rating: "" } }

    assert_redirected_to tournament_path(tournament)
    assert_equal [ "walkin" ], tournament.players.reload.pluck(:nickname)
    assert_nil Player.find_by!(nickname: "walkin").fide_rating
  end

  test "rejects a duplicate nickname" do
    assert_no_difference -> { Player.count } do
      post players_path, params: { player: { name: "Other Anna", nickname: "Anna_K" } }
    end
    assert_response :unprocessable_entity
    assert_select ".form-errors", /Nickname has already been taken/
  end

  test "updates a player" do
    patch player_path(players(:hana)), params: { player: { fide_rating: "1650" } }

    assert_redirected_to player_path(players(:hana))
    assert_equal 1650, players(:hana).reload.fide_rating
  end

  test "deletes a player" do
    assert_difference -> { Player.count }, -1 do
      delete player_path(players(:hana))
    end
    assert_redirected_to players_path
  end

  test "refuses to delete a player with games" do
    create_tournament(players: [ players(:anna), players(:boris) ], rounds: 1).start

    assert_no_difference -> { Player.count } do
      delete player_path(players(:anna))
    end
    assert_redirected_to player_path(players(:anna))
    assert_match "already played", flash[:alert]
  end
end
