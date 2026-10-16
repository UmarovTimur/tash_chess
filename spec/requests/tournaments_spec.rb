require "rails_helper"

RSpec.describe "Tournaments" do
  it "runs a Swiss tournament from registration to final standings" do
    post tournaments_path, params: { tournament: { name: "Friday Blitz", pairing_system: "swiss", rounds_count: "2", location: "Club" } }
    tournament = Tournament.find_by!(name: "Friday Blitz")
    expect(response).to redirect_to(tournament_path(tournament))

    follow_redirect!
    expect(texts("button")).to include(I18n.t("tournaments.header.start"))
    expect(page_html.css("input[name='player_ids[]']").size).to eq(8)

    members = [ players(:anna), players(:boris), players(:chen), players(:daria) ]
    post tournament_participations_path(tournament), params: { player_ids: members.map(&:id) }
    expect(tournament.participations.count).to eq(4)

    participation = tournament.participations.find_by!(player: players(:daria))
    delete tournament_participation_path(tournament, participation)
    post tournament_participations_path(tournament), params: { player_ids: [ players(:daria).id, players(:anna).id ] }
    expect(tournament.participations.count).to eq(4), "already registered players are skipped"

    post start_tournament_path(tournament)
    round = tournament.rounds.first
    expect(response).to redirect_to(tournament_round_path(tournament, round))
    expect(tournament.reload).to be_in_progress

    get tournament_round_path(tournament, round)
    expect(response).to have_http_status(:success)
    expect(texts(".board-no")).to eq(%w[ 1 2 ])
    expect(page_html.css("tr.game").size).to eq(2)

    post tournament_rounds_path(tournament)
    expect(flash[:alert]).to eq(I18n.t("activerecord.errors.models.tournament.attributes.base.round_incomplete")),
      "round 2 can't be paired before round 1 is complete"

    board1, board2 = round.games.to_a
    patch game_path(board1), params: { game: { result: "white_won" } }
    expect(response).to redirect_to(tournament_round_path(tournament, round))
    patch game_path(board2), params: { game: { result: "draw" } }
    expect(round.games.reload.map(&:result)).to eq(%w[ white_won draw ])

    get tournament_standings_path(tournament)
    expect(response).to have_http_status(:success)
    expect(page_html.css("table.table--standings tbody tr").size).to eq(4)
    expect(texts("tbody tr:first-child td a")).to eq([ board1.white_player.name ])

    post tournament_rounds_path(tournament)
    expect(response).to redirect_to(tournament_round_path(tournament, 2))
    play_round(tournament.rounds.last)

    get tournament_round_path(tournament, 2)
    expect(texts("button")).to include(I18n.t("tournaments.header.finish"))

    post finish_tournament_path(tournament)
    expect(response).to redirect_to(tournament_standings_path(tournament))
    expect(tournament.reload).to be_finished

    follow_redirect!
    expect(texts("h2")).to include(I18n.t("tournaments.standings.show.final"))

    patch game_path(board1), params: { game: { result: "black_won" } }
    expect(board1.reload.result).to eq("white_won"), "results are locked after the finish"
  end

  it "shows every round's pairings of a round robin at the start" do
    tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(5))
    post start_tournament_path(tournament)

    get tournament_round_path(tournament, 5)
    expect(response).to have_http_status(:success)
    expect(texts(".bye-label")).to eq([ I18n.t("tournaments.rounds.show.rests") ])
    expect(page_html.css(".rounds__link").size).to eq(5)
  end

  it "adds a player to a running round robin and re-pairs the rounds that haven't started" do
    tournament = create_tournament(system: :round_robin, rounds: 5, players: Player.by_rating.first(4))
    tournament.start

    get tournament_round_path(tournament, 1)
    expect(page_html.at_css("a[href='#{tournament_path(tournament, anchor: "add-players")}']").text).to eq(I18n.t("tournaments.header.add_player"))

    post tournament_participations_path(tournament), params: { player_ids: [ players(:hana).id ] }
    expect(response).to redirect_to(tournament_path(tournament))
    expect(flash[:notice]).to eq("#{I18n.t("tournaments.participations.create.added", count: 1)} #{I18n.t("tournaments.late_entry.replanned", number: 2)}")
    expect(tournament.participations.count).to eq(5)
    expect(tournament.rounds.reload.drop(1).flat_map { |round| round.games.flat_map(&:players) }).to include(players(:hana))
  end

  it "tells when a late entry has no rounds left to play" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 1)
    tournament.start

    post tournament_participations_path(tournament), params: { player_ids: [ players(:hana).id ] }
    expect(flash[:notice]).to include(I18n.t("tournaments.late_entry.no_rounds_left"))
  end

  it "doesn't add members to a finished tournament" do
    tournament = create_tournament(players: Player.by_rating.first(2), rounds: 1)
    tournament.start
    play_round(tournament.current_round)
    tournament.finish

    post tournament_participations_path(tournament), params: { player_ids: [ players(:hana).id ] }
    expect(flash[:alert]).to eq(I18n.t("tournaments.participations.locked"))
    expect(tournament.participations.count).to eq(2)
  end

  it "starts a Swiss with more rounds than opponents" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 10)

    post start_tournament_path(tournament)
    expect(tournament.reload).to be_in_progress
  end

  it "doesn't change a bye result" do
    tournament = create_tournament(players: Player.by_rating.first(3), rounds: 2)
    tournament.start
    bye = tournament.games.bye.first

    patch game_path(bye), params: { game: { result: "black_won" } }
    expect(bye.reload).to be_bye
  end

  it "deletes the latest Swiss round" do
    tournament = create_tournament(players: Player.by_rating.first(4), rounds: 3)
    tournament.start
    play_round(tournament.current_round)
    tournament.pair_next_round

    delete tournament_round_path(tournament, 2)
    expect(response).to redirect_to(tournament_round_path(tournament, 1))
    expect(tournament.rounds.reload.pluck(:number)).to eq([ 1 ])
  end
end
