class Tournaments::RoundsController < Tournaments::BaseController
  def show
    @round = @tournament.rounds.find_by!(number: params[:number])
    @games = @round.games.includes(:white_player, :black_player)
    @standings = @tournament.standings
  end

  def create
    if @tournament.pair_next_round
      redirect_to tournament_round_path(@tournament, @tournament.current_round), notice: "Round #{@tournament.current_round.number} is paired."
    else
      redirect_back_or_to @tournament, alert: @tournament.errors.full_messages.to_sentence
    end
  end

  def destroy
    round = @tournament.rounds.find_by!(number: params[:number])

    if round != @tournament.current_round
      redirect_back_or_to @tournament, alert: "Only the latest round can be deleted.", status: :see_other
    elsif @tournament.remove_last_round
      destination = @tournament.current_round ? tournament_round_path(@tournament, @tournament.current_round) : @tournament
      redirect_to destination, notice: "Round #{round.number} was deleted.", status: :see_other
    else
      redirect_back_or_to @tournament, alert: @tournament.errors.full_messages.to_sentence, status: :see_other
    end
  end
end
