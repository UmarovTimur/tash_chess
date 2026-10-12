# Sample club roster and one tournament in registration. Safe to run more than once.
players = [
  [ "Anna Kowalska", "anna_k", 2215 ],
  [ "Boris Lebedev", "boris", 2140 ],
  [ "Chen Wei", "chenwei", 2088 ],
  [ "Daria Melnyk", "daria.m", 1990 ],
  [ "Erik Johansson", "erikj", 1934 ],
  [ "Fatima Nurlanova", "fatima", 1876 ],
  [ "Giorgi Beridze", "giorgi", 1812 ],
  [ "Hana Novak", "hana", nil ],
  [ "Ivan Petrov", "ivanp", 1745 ],
  [ "Julia Santos", "jsantos", nil ]
].map do |name, nickname, fide_rating|
  Player.find_or_create_by!(nickname:) do |player|
    player.name = name
    player.fide_rating = fide_rating
  end
end

Tournament.find_or_create_by!(name: "Club Rapid Open") do |tournament|
  tournament.pairing_system = :swiss
  tournament.rounds_count = 5
  tournament.starts_on = Date.current
  tournament.location = "Club hall"
  tournament.players = players.first(8)
end
