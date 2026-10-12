module ApplicationHelper
  STATUS_LABELS = { "registration" => "Registration", "in_progress" => "In progress", "finished" => "Finished" }.freeze

  # 0 → "0", 0.5 → "½", 2.5 → "2½"; anything else (e.g. Sonneborn-Berger 3.25) as a plain number.
  def format_score(value)
    return "" if value.nil?

    doubled = value.to_f * 2
    if doubled == doubled.round
      whole, half = doubled.round.divmod(2)
      half.zero? ? whole.to_s : "#{whole unless whole.zero?}½"
    else
      number_with_precision(value, precision: 2, strip_insignificant_zeros: true)
    end
  end

  def format_tiebreak(value)
    number_with_precision(value, precision: 2, strip_insignificant_zeros: true)
  end

  def status_badge(tournament)
    tag.span STATUS_LABELS.fetch(tournament.status), class: "badge badge--#{tournament.status.dasherize}"
  end

  def piece_color(color)
    tag.span class: "piece piece--#{color}", title: color.to_s.capitalize, aria: { label: color.to_s.capitalize }
  end

  def rating(player)
    player.fide_rating || tag.span("—", class: "muted")
  end

  def nav_link_to(name, path, active:)
    link_to name, path, class: class_names("nav__link", "nav__link--active": active), aria: { current: ("page" if active) }
  end
end
