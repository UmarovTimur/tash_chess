module TournamentsHelper
  def tournament_summary(tournament)
    parts = [ tournament.pairing_system_label ]
    parts << rounds_summary(tournament)
    parts << l(tournament.starts_on, format: :long) if tournament.starts_on
    parts << tournament.location if tournament.location
    parts.compact.join(" · ")
  end

  def rounds_summary(tournament)
    if tournament.in_progress? && tournament.current_round
      "Round #{tournament.current_round.number} of #{tournament.rounds_count}"
    elsif tournament.rounds_count
      pluralize(tournament.rounds_count, "round")
    elsif tournament.round_robin? && tournament.participations.size > 1
      count = tournament.participations.size
      "#{pluralize(count.even? ? count - 1 : count, "round")} (all-play-all)"
    end
  end

  def standings_cell(cell)
    return tag.span("", class: "cell cell--empty") if cell.nil?

    if cell.bye?
      title = cell.points.positive? ? "Bye" : "Rests this round"
      tag.span(cell.points.positive? ? "+" : "–", class: "cell cell--bye", title:)
    elsif cell.pending
      tag.span("…", class: "cell cell--pending", title: "Playing #{cell.opponent.name} with #{cell.color}")
    else
      result = { 1.0 => "win", 0.5 => "draw", 0.0 => "loss" }.fetch(cell.points.to_f)
      tag.span(class: "cell cell--#{result}", title: "#{result.capitalize} vs #{cell.opponent.name} (#{cell.color})") do
        safe_join([ piece_color(cell.color), format_score(cell.points) ])
      end
    end
  end
end
