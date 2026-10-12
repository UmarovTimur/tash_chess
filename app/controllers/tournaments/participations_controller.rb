class Tournaments::ParticipationsController < Tournaments::BaseController
  before_action :ensure_members_editable

  def create
    players = Player.where(id: params[:player_ids]).where.not(id: @tournament.players.select(:id))

    if players.any?
      Tournament.transaction { players.each { |player| @tournament.participations.create!(player:) } }
      redirect_to @tournament, notice: t(".added", count: players.size)
    else
      redirect_to @tournament, alert: t(".none_selected")
    end
  end

  def destroy
    participation = @tournament.participations.find(params[:id])

    if participation.destroy
      redirect_to @tournament, notice: t(".removed", name: participation.player.name), status: :see_other
    else
      redirect_to @tournament, alert: participation.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def ensure_members_editable
      unless @tournament.members_editable?
        redirect_to @tournament, alert: t("tournaments.participations.locked"), status: :see_other
      end
    end
end
