class GamesController < ApplicationController
  def update
    game = Game.find(params[:id])
    tournament = game.tournament

    if tournament.in_progress? && !game.bye? && game.update(result: params.expect(game: :result)[:result])
      redirect_to tournament_round_path(tournament, game.round), status: :see_other
    else
      message = game.errors.full_messages.to_sentence.presence || t(".locked")
      redirect_to tournament_round_path(tournament, game.round), alert: message, status: :see_other
    end
  end
end
