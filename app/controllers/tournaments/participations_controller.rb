class Tournaments::ParticipationsController < Tournaments::BaseController
  before_action :ensure_members_editable

  def create
    players = Player.where(id: params[:player_ids]).where.not(id: @tournament.players.select(:id))

    if players.any?
      Tournament.transaction { players.each { |player| @tournament.participations.create!(player:) } }
      redirect_to @tournament, notice: "#{helpers.pluralize(players.size, "player")} joined the tournament."
    else
      redirect_to @tournament, alert: "Choose at least one player to add."
    end
  end

  def destroy
    participation = @tournament.participations.find(params[:id])

    if participation.destroy
      redirect_to @tournament, notice: "#{participation.player.name} left the tournament.", status: :see_other
    else
      redirect_to @tournament, alert: participation.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def ensure_members_editable
      unless @tournament.members_editable?
        redirect_to @tournament, alert: "Members can't be changed at this stage of the tournament.", status: :see_other
      end
    end
end
