class Tournaments::ParticipationsController < Tournaments::BaseController
  before_action :ensure_members_editable

  def create
    players = Player.where(id: params[:player_ids]).where.not(id: @tournament.players.select(:id)).to_a

    if players.any?
      @tournament.enroll(players)
      redirect_to @tournament, notice: [ t(".added", count: players.size), late_entry_note(@tournament) ].compact.join(" ")
    else
      redirect_to @tournament, alert: t(".none_selected")
    end
  end

  def destroy
    participation = @tournament.participations.find(params[:id])

    if @tournament.withdraw(participation)
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
