# frozen_string_literal: true

class CsvImporter

  require 'csv'
  require 'bcrypt'
  require 'digest/sha2'
  require 'babosa'

  HEADER_PATTERNS = {
    company: [/^фирма$/],
    division: [/^подразделение$/],
    fio: [/^сотрудник$/],
    position: [/^должность$/],
    tabno: [/^таб(\.|ельный)?\s*№$/, /^табельный\s*номер$/],
    dt: [/^дата\s*и\s*время$/, /^дата.*врем/],
    dir: [/^направлен/],
    door: [/^двер/],
    comment: [/^коммент/],
    basis: [/^расчет.*ведетс/],
    zone: [/^зона.*доступ/]
  }.freeze

  def build_header_map(headers)
    normed = headers.compact.index_by { |h| norm_header(h) }
    map = {}
    HEADER_PATTERNS.each do |key, patterns|
      found_norm = normed.keys.find { |nh| patterns.any? { |re| nh.match?(re) } }
      map[key] = found_norm ? normed[found_norm] : nil
    end
    map
  end

  def pick(row_h, key_sym)
    k = @header_map[key_sym]
    k ? to_utf8(row_h[k]) : nil
  end

  # ===== прогресс =====
  def on_progress(&block) = (@progress_cb = block)

  def progress!(done, total, note = nil)
    total = [total.to_i, 1].max
    pct   = ((done.to_f / total) * 100).round
    @progress_cb&.call(pct.clamp(0, 100), note)
  end
  # ====================

  def initialize(io_or_string, filename:)
    raw   = io_or_string.respond_to?(:read) ? io_or_string.read : io_or_string.to_s
    @data = normalize_encoding(raw)

    @checksum = Digest::SHA256.hexdigest(@data)

    # ключ: по checksum исключаем дубли
    @file = ImportFile.find_or_initialize_by(checksum: @checksum)
    @file.filename = filename if @file.new_record?

    @stats = { rows: 0, passes: 0, users_new: 0, divisions_new: 0, companies_new: 0 }
    @header_map = nil
  end

  def call!
    if @file.new_record?
      @file.save! # первый импорт этого файла
    else
      # повторный импорт того же файла: очищаем его Pass'ы
      @file.passes.delete_all
    end

    csv = CSV.parse(@data, headers: true, col_sep: detect_sep(@data), encoding: 'UTF-8')
    total = csv.size
    csv.each_with_index do |row, idx|
      @header_map ||= build_header_map(row.headers)
      import_row!(row.to_h)
      progress!(idx + 1, total, "Строк: #{idx + 1}/#{total}")
    end

    @file.update!(rows_count: @stats[:rows])
    @stats
  end

  private

  # ----- импорт одной строки -----
  def import_row!(h)
    row = {}
    h.each { |k, v| row[to_utf8(k)] = to_utf8(v) }

    company_name  = pick(h, :company).to_s.strip
    division_name = pick(h, :division).to_s.strip
    fio           = pick(h, :fio).to_s.strip
    position_name = pick(h, :position).to_s.strip
    tabno_raw     = pick(h, :tabno).to_s.strip
    dt_str        = pick(h, :dt).to_s.strip
    direction     = map_direction(pick(h, :dir).to_s.strip)
    door          = pick(h, :door).to_s.strip
    comment       = pick(h, :comment).to_s.strip
    basis         = pick(h, :basis).to_s.strip.strip.presence
    zone          = pick(h, :zone).to_s.strip

    company  = company_name.present?  ? find_or_create_company!(company_name) : nil
    division = division_name.present? ? find_or_create_division!(division_name, company) : nil

    last, first, middle = split_fio(fio)
    num4 = normalize_num(tabno_raw) # "1234" или nil

    user = find_or_create_user!(last:, first:, middle:, fallback_login: num4 && "u#{num4}")
    updates = {}
    updates[:current_division_id] = division.id if division && user.current_division_id != division.id
    updates[:position] = position_name if position_name.present? && user.position.to_s != position_name
    user.update!(updates) if updates.any?
    ensure_division_membership!(user, division) if division

    if num4
      idf = PersonalIdentifier.find_or_create_by!(normalized_value: num4) { |x| x.value = tabno_raw }
      ensure_number_assigned!(user, idf, parse_time(dt_str) || Time.current)
      ensure_pin_from_identifier!(user, idf, force: true) # PIN = 4 цифры
    end

    if (ts = parse_time(dt_str)) && direction
      Pass.create!(
        user: user, happened_at: ts, direction: direction,
        door: door, zone: zone, comment: comment, calculation_basis: basis,
        raw: h, import_file: @file
      )
      @stats[:passes] += 1
    end

    @stats[:rows] += 1
  rescue StandardError => e
    Rails.logger.warn("CSVImporter: skip row due to #{e.class}: #{e.full_message}")
  end

  # ----- кодировка -----
  def normalize_encoding(s)
    buf = s.dup
    buf = buf.byteslice(3..-1) if buf.start_with?("\xEF\xBB\xBF".b) # BOM
    buf.force_encoding(Encoding::UTF_8)
    return buf if buf.valid_encoding?

    buf.encode(Encoding::UTF_8, Encoding::Windows_1251, invalid: :replace, undef: :replace, replace: '')
  end

  # ----- справочники и уникальности -----
  def find_or_create_company!(name)
    Company.where('lower(name)=?', name.downcase).first || begin
      @stats[:companies_new] += 1
      Company.create!(name: name)
    end
  end

  def find_or_create_division!(name, company)
    div = Division.find_or_create_by!(name: name)
    CompanyDivision.find_or_create_by!(company_id: company.id, division_id: div.id) if company
    div # ВАЖНО: возвращаем сам Division
  end

  # ----- пользователи / логин -----
  def find_or_create_user!(last:, first:, middle:, fallback_login:)
    user = User.where(last_name: last, first_name: first, middle_name: middle).first
    return user if user

    login = build_login(last:, first:, middle:)
    login = fallback_login if login.blank? && fallback_login.present?
    login = disambiguate(login.presence || 'user')

    ln = last.presence  || '-'
    fn = first.presence || '-'

    u = User.create!(last_name: ln, first_name: fn, middle_name: middle, auth_login: login)
    @stats[:users_new] += 1
    u
  end

  def build_login(last:, first:, middle: nil)
    "#{last} #{first}".to_slug
                      .transliterate(:russian)
                      .normalize(separator: '.', strict: true)
                      .to_s
  end

  def disambiguate(base)
    login = base
    i = 0
    while User.exists?(['lower(auth_login) = ?', login.downcase])
      i += 1
      login = "#{base}.#{i}"
    end
    login
  end

  # ----- история номеров/подразделений -----
  def ensure_number_assigned!(user, idf, at)
    PersonalIdentifierAssignment.where(personal_identifier_id: idf.id).active_at(at).where.not(user_id: user.id)
                                .find_each { |a| a.update!(period: a.period.begin...at) }
    PersonalIdentifierAssignment.where(user_id: user.id).active_at(at).where.not(personal_identifier_id: idf.id)
                                .find_each { |a| a.update!(period: a.period.begin...at) }
    PersonalIdentifierAssignment.where(user_id: user.id, personal_identifier_id: idf.id).active_at(at).first ||
      PersonalIdentifierAssignment.create!(user: user, personal_identifier: idf, period: at..Float::INFINITY)
  end

  def ensure_division_membership!(user, division)
    now = Time.current
    active = UserDivisionMembership.where(user: user).active_at(now).first
    return if active&.division_id == division.id

    active&.update!(period: active.period.begin...now)
    UserDivisionMembership.create!(user: user, division: division, period: now..Float::INFINITY)
  end

  # ----- PIN из 4-значного идентификатора -----
  def ensure_pin_from_identifier!(user, identifier, force: false)
    return unless identifier && identifier.normalized_value.present?
    return unless force || user.pin_digest.blank?

    pin = identifier.normalized_value # ровно 4 цифры
    if user.respond_to?(:pin=)        # has_secure_password :pin
      user.pin = pin
    else
      user.pin_digest = BCrypt::Password.create(pin)
    end
    user.save!
  end

  # ----- утилиты -----
  def split_fio(fio)
    parts = fio.split(/\s+/)
    [parts[0], parts[1], parts[2..]&.join(' ')].map(&:to_s)
  end

  def parse_time(str)
    return nil if str.blank?

    Time.zone.parse(str)
  rescue StandardError
    nil
  end

  def normalize_num(num)
    d = num.to_s.gsub(/\D/, '')
    return d if d.length == 4

    nil
  end

  def detect_sep(data)
    first = data.lines.first.to_s
    first.count(';') > first.count(',') ? ';' : ','
  end

  def map_direction(val)
    v = val.to_s.strip.downcase
    return 'in'  if v.include?('вход')  || v == 'in'
    return 'out' if v.include?('выход') || v == 'out'

    nil
  end

  def to_utf8(x)
    s = x.to_s
    return s if s.encoding == Encoding::UTF_8 && s.valid_encoding?

    s2 = s.dup.force_encoding(Encoding::UTF_8)
    return s2 if s2.valid_encoding?

    s.encode(Encoding::UTF_8, Encoding::Windows_1251, invalid: :replace, undef: :replace, replace: '')
  end

  def norm_header(h)
    to_utf8(h).tr("\u00A0\u202F", '  ').gsub(/[[:space:]]+/, ' ').strip.downcase.gsub('ё', 'е')
  end

end

# # frozen_string_literal: true

# class CsvImporter

#   require 'csv'
#   require 'bcrypt'
#   require 'digest/sha2'
#   require 'babosa'

#   HEADER_PATTERNS = {
#     company: [/^фирма$/],
#     division: [/^подразделение$/],
#     fio: [/^сотрудник$/],
#     position: [/^должность$/],
#     tabno: [/^таб(\.|ельный)?\s*№$/, /^табельный\s*номер$/],
#     dt: [/^дата\s*и\s*время$/, /^дата.*врем/],
#     dir: [/^направлен/],
#     door: [/^двер/],
#     comment: [/^коммент/],
#     basis: [/^расчет.*ведетс/],
#     zone: [/^зона.*доступ/]
#   }.freeze

#   def build_header_map(headers)
#     normed = headers.compact.index_by { |h| norm_header(h) }
#     map = {}
#     HEADER_PATTERNS.each do |key, patterns|
#       found_norm = normed.keys.find { |nh| patterns.any? { |re| nh.match?(re) } }
#       map[key] = found_norm ? normed[found_norm] : nil
#     end
#     # Rails.logger.info("[CSV] header map: #{map.inspect}")
#     map
#   end

#   def pick(row_h, key_sym)
#     k = @header_map[key_sym]
#     k ? to_utf8(row_h[k]) : nil
#   end

#   # HEADERS = {
#   #   company: 'Фирма',
#   #   division: 'Подразделение',
#   #   fio: 'Сотрудник',
#   #   position: 'Должность',
#   #   tabno: 'Таб. №',
#   #   dt: 'Дата и время',
#   #   dir: 'Направление',
#   #   door: 'Дверь',
#   #   comment: 'Комментарий',
#   #   basis: 'Расчет ведется',
#   #   zone: 'Зона доступа'
#   # }.freeze

#   # def initialize(io_or_string, filename:)
#   #   raw = io_or_string.respond_to?(:read) ? io_or_string.read : io_or_string.to_s
#   #   @data = normalize_encoding(raw) # ← ключ: делаем валидный UTF-8
#   #   @file = ImportFile.new(filename: filename, checksum: Digest::SHA256.hexdigest(@data))
#   #   @stats = { companies_new: 0, divisions_new: 0, users_new: 0, passes: 0, rows: 0 }
#   # end

#   def initialize(io_or_string, filename:, import_file: nil)
#     raw   = io_or_string.respond_to?(:read) ? io_or_string.read : io_or_string.to_s
#     @data = normalize_encoding(raw)
#     @checksum = Digest::SHA256.hexdigest(@data)
#     # @file = import_file || ImportFile.new(filename: filename, checksum: @checksum)

#     # ⚠️ ключевая строка: НЕ new, а find_or_initialize_by по checksum
#     @file = ImportFile.find_or_initialize_by(checksum: @checksum)
#     @file.filename = filename if @file.new_record?

#     @stats = { rows: 0, passes: 0, users_new: 0, divisions_new: 0, companies_new: 0 }
#     @header_map = nil

#     @progress_cb = nil
#     @processed_rows = 0
#     @total_rows     = 0
#   end

#   def on_progress(&block) = (@progress_cb = block)

#   def progress!(i, total, note = nil)
#     pct = ((i.to_f / total) * 100).round
#     @progress_cb&.call(pct.clamp(0, 100), note)
#   end

#   def call!
#     if @file.new_record?
#       @file.save! # первый импорт этого файла
#     else
#       # повторный импорт ТОГО ЖЕ файла: чтобы не было дублей — очищаем его проходы
#       # (или убери строку ниже, если хочешь накапливать)
#       @file.passes.delete_all
#     end

#     csv = CSV.parse(@data, headers: true, col_sep: detect_sep(@data), encoding: 'UTF-8')
#     csv.each_with_index do |row, idx|
#       @header_map ||= build_header_map(row.headers)
#       import_row!(row.to_h)
#       progress!(idx + 1, total, "Строк: #{idx + 1}/#{total}")
#     end

#     @file.update!(rows_count: @stats[:rows])
#     @stats
#   end

#   # def call!
#   #   CSV.parse(@data, headers: true, col_sep: detect_sep(@data), encoding: 'UTF-8').each do |row|
#   #     import_row!(row.to_h)
#   #   end
#   #   @file.rows_count = @stats[:rows]
#   #   @file.save!
#   #   @stats
#   # end

#   private

#   # ----- импорт одной строки -----
#   def import_row!(h)
#     row = {}
#     h.each { |k, v| row[to_utf8(k)] = to_utf8(v) }

#     # company_name  = row['Фирма'].strip
#     # division_name = row['Подразделение'].strip
#     # fio           = row['Сотрудник'].strip
#     # position_name = row['Должность'].strip
#     # tabno_raw     = row['Таб. №'].strip
#     # dt_str        = row['Дата и время'].strip
#     # direction     = map_direction(row['Направление'])
#     # door          = row['Дверь']
#     # comment       = row['Комментарий']
#     # basis         = row['Расчет ведется'].strip.presence
#     # zone          = row['Зона доступа']

#     company_name = pick(h, :company).to_s.strip
#     division_name = pick(h, :division).to_s.strip
#     fio           = pick(h, :fio).to_s.strip
#     position_name = pick(h, :position).to_s.strip
#     tabno_raw     = pick(h, :tabno).to_s.strip
#     dt_str        = pick(h, :dt).to_s.strip
#     direction     = map_direction(pick(h, :dir).to_s.strip)
#     door          = pick(h, :door).to_s.strip
#     comment       = pick(h, :comment).to_s.strip
#     basis         = pick(h, :basis).to_s.strip.strip.presence
#     zone          = pick(h, :zone).to_s.strip

#     # pp "Company: #{company_name}"
#     # pp "Division: #{division_name}"
#     # pp "fio: #{fio}"
#     # pp "Position: #{position_name}"
#     # pp "Tab NO: #{tabno_raw}"
#     # pp "Date/Time: #{dt_str}"
#     # pp "Direction: #{direction}"
#     # pp "Door: #{door}"
#     # pp "Comment: #{comment}"
#     # pp "Basis: #{basis}"
#     # pp "Zone: #{zone}"

#     company = company_name.present? ? find_or_create_company!(company_name) : nil
#     # division = division_name.present? ? find_or_create_division!(division_name, company) : nil
#     division = find_or_create_division!(division_name, company) if division_name.present?

#     # Rails.logger.info("DIV-> #{division} / COMP-> #{company}")

#     last, first, middle = split_fio(fio)
#     num4 = normalize_num(tabno_raw) # → "1234" или nil

#     user = find_or_create_user!(last:, first:, middle:, fallback_login: num4 && "u#{num4}")
#     updates = {}
#     updates[:current_division_id] = division.id if division && user.current_division_id != division.id
#     updates[:position] = position_name if position_name.present? && user.position.to_s != position_name
#     user.update!(updates) if updates.any?
#     ensure_division_membership!(user, division) if division

#     if num4
#       idf = PersonalIdentifier.find_or_create_by!(normalized_value: num4) { |x| x.value = tabno_raw }
#       ensure_number_assigned!(user, idf, parse_time(dt_str) || Time.current)
#       ensure_pin_from_identifier!(user, idf, force: true) # PIN = 4 цифры
#     end

#     if (ts = parse_time(dt_str)) && direction
#       ps = Pass.create!(
#         user: user, happened_at: ts, direction: direction,
#         door: door, zone: zone, comment: comment, calculation_basis: basis,
#         raw: h, import_file: @file
#       )
#       @stats[:passes] += 1
#     end

#     # Rails.logger.info("NUM4-> #{num4}")
#     # Rails.logger.info("IDF-> #{idf}")
#     # Rails.logger.info("DT-> #{ts}")
#     # Rails.logger.info("PS-> #{ps.inspect}")

#     @stats[:rows] += 1
#   rescue StandardError => e
#     Rails.logger.warn("CSVImporter: skip row due to #{e.class}: #{e.full_message}")
#   end

#   # ----- кодировка -----
#   def normalize_encoding(s)
#     buf = s.dup

#     # 1) срезаем UTF-8 BOM по байтам (без регэкспов и без UTF-8)
#     buf = buf.byteslice(3..-1) if buf.start_with?("\xEF\xBB\xBF".b)

#     # 2) пробуем как UTF-8
#     buf.force_encoding(Encoding::UTF_8)
#     return buf if buf.valid_encoding?

#     # 3) fallback: возможно CP1251 → UTF-8
#     buf.encode(Encoding::UTF_8, Encoding::Windows_1251,
#                invalid: :replace, undef: :replace, replace: '')
#   end

#   # def normalize_encoding(s)
#   #   str = s.dup
#   #   str = str.sub(/\A\xEF\xBB\xBF/, '')         # срезаем UTF-8 BOM, если есть
#   #   tmp = str.dup.force_encoding('UTF-8')
#   #   return tmp if tmp.valid_encoding?           # типичный случай: bytes уже utf-8

#   #   # fallback: конверсия CP1251 → UTF-8 (вдруг файл в win-1251)
#   #   str.encode('UTF-8', 'Windows-1251', invalid: :replace, undef: :replace, replace: '')
#   # end

#   # ----- справочники и уникальности -----
#   def find_or_create_company!(name)
#     Company.where('lower(name)=?', name.downcase).first || begin
#       @stats[:companies_new] += 1
#       Company.create!(name: name)
#     end
#   end

#   def find_or_create_division!(name, company)
#     div = Division.find_or_create_by!(name: name)
#     # завести связь m:n (без дублей)
#     CompanyDivision.find_or_create_by!(company_id: company.id, division_id: div.id) if company
#     div

#     # scope = Division.where(name: name)
#     # scope = scope.where(company_id: company&.id)
#     # Rails.logger.info("NAME: #{name} COMPANY: #{company.inspect} SCOPE: #{scope.inspect}")
#     # scope.first || begin
#     #   @stats[:divisions_new] += 1
#     #   Division.create!(name: name, company: company)
#     # end
#   end

#   # ----- пользователи / логин -----
#   def find_or_create_user!(last:, first:, middle:, fallback_login:)
#     user = User.where(last_name: last, first_name: first, middle_name: middle).first
#     return user if user

#     login = build_login(last:, first:, middle:)
#     login = fallback_login if login.blank? && fallback_login.present?
#     login = disambiguate(login.presence || 'user')

#     ln = last.presence  || '-'
#     fn = first.presence || '-'

#     u = User.create!(last_name: ln, first_name: fn, middle_name: middle, auth_login: login)
#     @stats[:users_new] += 1
#     u
#   end

#   def build_login(last:, first:, middle: nil)
#     "#{last} #{first}".to_slug
#                       .transliterate(:russian)
#                       .normalize(separator: '.', strict: true)
#                       .to_s
#   end

#   def disambiguate(base)
#     login = base
#     i = 0
#     while User.exists?(['lower(auth_login) = ?', login.downcase])
#       i += 1
#       login = "#{base}.#{i}"
#     end
#     login
#   end

#   # ----- история номеров/подразделений -----
#   def ensure_number_assigned!(user, idf, at)
#     PersonalIdentifierAssignment.where(personal_identifier_id: idf.id).active_at(at).where.not(user_id: user.id)
#                                 .find_each { |a| a.update!(period: a.period.begin...at) }
#     PersonalIdentifierAssignment.where(user_id: user.id).active_at(at).where.not(personal_identifier_id: idf.id)
#                                 .find_each { |a| a.update!(period: a.period.begin...at) }
#     PersonalIdentifierAssignment.where(user_id: user.id, personal_identifier_id: idf.id).active_at(at).first ||
#       PersonalIdentifierAssignment.create!(user: user, personal_identifier: idf, period: at..Float::INFINITY)
#   end

#   def ensure_division_membership!(user, division)
#     now = Time.current
#     active = UserDivisionMembership.where(user: user).active_at(now).first
#     return if active&.division_id == division.id

#     active&.update!(period: active.period.begin...now)

#     UserDivisionMembership.create!(user: user, division: division, period: now..Float::INFINITY)
#   end

#   # ----- PIN из 4-значного идентификатора -----
#   def ensure_pin_from_identifier!(user, identifier, force: false)
#     return unless identifier && identifier.normalized_value.present?
#     return unless force || user.pin_digest.blank?

#     pin = identifier.normalized_value # ровно 4 цифры
#     if user.respond_to?(:pin=)        # has_secure_password :pin
#       user.pin = pin
#     else
#       user.pin_digest = BCrypt::Password.create(pin)
#     end
#     user.save!
#   end

#   # ----- утилиты -----
#   def split_fio(fio)
#     parts = fio.split(/\s+/)
#     [parts[0], parts[1], parts[2..]&.join(' ')].map(&:to_s)
#   end

#   def parse_time(str)
#     return nil if str.blank?

#     Time.zone.parse(str)
#   rescue StandardError
#     nil
#   end

#   def normalize_num(num)
#     d = num.to_s.gsub(/\D/, '')
#     return d if d.length == 4

#     nil
#   end

#   def detect_sep(data)
#     first = data.lines.first.to_s
#     first.count(';') > first.count(',') ? ';' : ','
#   end

#   def map_direction(val)
#     v = val.to_s.strip.downcase
#     return 'in' if v.include?('вход') || v == 'in'

#     'out' if v.include?('выход') || v == 'out'
#   end

#   def to_utf8(x)
#     s = x.to_s
#     return s if s.encoding == Encoding::UTF_8 && s.valid_encoding?

#     s2 = s.dup.force_encoding(Encoding::UTF_8)
#     return s2 if s2.valid_encoding?

#     s.encode(Encoding::UTF_8, Encoding::Windows_1251, invalid: :replace, undef: :replace, replace: '')
#   end

#   def norm_header(h)
#     # заменяем NBSP/узкий NBSP на обычный пробел, схлопываем пробелы, приводим к нижнему регистру, "ё"->"е"
#     to_utf8(h).tr("\u00A0\u202F", '  ').gsub(/[[:space:]]+/, ' ').strip.downcase.gsub('ё', 'е')
#   end

#   # def to_utf8(value)
#   #   s = value.to_s
#   #   return s if s.encoding == Encoding::UTF_8 && s.valid_encoding?

#   #   s2 = s.dup.force_encoding(Encoding::UTF_8)
#   #   return s2 if s2.valid_encoding?

#   #   s.encode(Encoding::UTF_8, Encoding::Windows_1251,
#   #            invalid: :replace, undef: :replace, replace: '')
#   # end

#   # def to_utf8(value)
#   #   s = value.to_s
#   #   return s if s.encoding == Encoding::UTF_8 && s.valid_encoding?

#   #   # сначала попробуем просто поменять метку кодировки
#   #   s2 = s.dup.force_encoding(Encoding::UTF_8)
#   #   return s2 if s2.valid_encoding?

#   #   # если всё ещё мусор — вероятный Windows-1251 → UTF-8
#   #   s.encode(Encoding::UTF_8, Encoding::Windows_1251, invalid: :replace, undef: :replace, replace: '')
#   # end

# end

# # class CsvImporter

# #   require 'csv'
# #   require 'bcrypt'
# #   require 'digest/sha2'
# #   require 'babosa'

# #   def initialize(io_or_string, filename:)
# #     @data = io_or_string.respond_to?(:read) ? io_or_string.read : io_or_string.to_s
# #     @file = ImportFile.new(filename: filename, checksum: Digest::SHA256.hexdigest(@data))
# #   end

# #   def call!
# #     CSV.parse(@data, headers: true, col_sep: detect_sep(@data)).each do |row|
# #       import_row!(row.to_h)
# #     end
# #     @file.rows_count = @count
# #     @file.save!
# #   end

# #   private

# #   def import_row!(h)
# #     company_name     = h['Фирма'].to_s.strip
# #     division_name    = h['Подразделение'].to_s.strip
# #     fio              = h['Сотрудник'].to_s.strip
# #     position_name    = h['Должность'].to_s.strip
# #     personal_number  = h['Таб. №'].to_s.strip
# #     happened_at      = begin
# #       Time.zone.parse(h['Дата и время'].to_s)
# #     rescue StandardError
# #       nil
# #     end
# #     direction        = map_direction(h['Направление'])
# #     door             = h['Дверь']
# #     comment          = h['Комментарий']
# #     calculation_basis = h['Расчет ведется'].to_s.strip.presence
# #     zone = h['Зона доступа']

# #     company  = Company.find_or_create_by!(name: company_name) if company_name.present?
# #     division = if division_name.present?
# #                  Division.where(name: division_name, company: company).first ||
# #                    Division.create!(name: division_name, company: company)
# #                end

# #     last, first, middle = split_fio(fio)
# #     num4 = normalize_num(personal_number) # "1234" или nil

# #     user = find_or_create_user!(last:, first:, middle:, fallback_login: num4 && "u#{num4}")

# #     # обновим текущие атрибуты
# #     updates = {}
# #     updates[:current_division_id] = division.id if division && user.current_division_id != division.id
# #     updates[:position] = position_name if position_name.present? && user.position.to_s != position_name
# #     user.update!(updates) if updates.any?

# #     ensure_division_membership!(user, division) if division

# #     if num4
# #       idf = PersonalIdentifier.find_or_create_by!(normalized_value: num4) { |x| x.value = personal_number }
# #       ensure_number_assigned!(user, idf, happened_at || Time.current)
# #       ensure_pin_from_identifier!(user, idf, force: true) # PIN = те же 4 цифры
# #     end

# #     if happened_at && direction
# #       Pass.create!(
# #         user: user,
# #         happened_at: happened_at,
# #         direction: direction,
# #         door: door,
# #         zone: zone,
# #         comment: comment,
# #         calculation_basis: calculation_basis,
# #         raw: h,
# #         import_file: @file
# #       )
# #     end

# #     @count = (@count || 0) + 1
# #   end

# #   # ---------- связи и история ----------

# #   def ensure_number_assigned!(user, idf, at)
# #     PersonalIdentifierAssignment.where(personal_identifier_id: idf.id).active_at(at).where.not(user_id: user.id)
# #                                 .find_each { |a| a.update!(period: a.period.begin...at) }
# #     PersonalIdentifierAssignment.where(user_id: user.id).active_at(at).where.not(personal_identifier_id: idf.id)
# #                                 .find_each { |a| a.update!(period: a.period.begin...at) }
# #     PersonalIdentifierAssignment.where(user_id: user.id, personal_identifier_id: idf.id).active_at(at).first ||
# #       PersonalIdentifierAssignment.create!(user: user, personal_identifier: idf, period: at..Float::INFINITY)
# #   end

# #   def ensure_division_membership!(user, division)
# #     now = Time.current
# #     active = UserDivisionMembership.where(user: user).active_at(now).first
# #     return if active&.division_id == division.id

# #     active&.update!(period: active.period.begin...now)
# #     UserDivisionMembership.create!(user: user, division: division, period: now..Float::INFINITY)
# #   end

# #   # ---------- пользователи / логин ----------

# #   def find_or_create_user!(last:, first:, middle:, fallback_login: nil)
# #     user = User.where(last_name: last, first_name: first, middle_name: middle).first
# #     return user if user

# #     login = build_login(last:, first:, middle:)
# #     login = fallback_login if login.blank? && fallback_login.present?
# #     login = disambiguate(login.presence || 'user')

# #     ln = last.presence  || '-'
# #     fn = first.presence || '-'

# #     User.create!(
# #       last_name: ln,
# #       first_name: fn,
# #       middle_name: middle,
# #       auth_login: login
# #     )
# #   end

# #   def build_login(last:, first:, middle: nil)
# #     "#{last} #{first}".to_slug
# #                       .transliterate(:russian)
# #                       .normalize(separator: '.', strict: true)
# #                       .to_s
# #   end

# #   def disambiguate(base)
# #     login = base
# #     i = 0
# #     while User.exists?(['lower(auth_login) = ?', login.downcase])
# #       i += 1
# #       login = "#{base}.#{i}"
# #     end
# #     login
# #   end

# #   # ---------- PIN из 4-значного номера ----------

# #   def ensure_pin_from_identifier!(user, identifier, force: false)
# #     return unless identifier && identifier.normalized_value.present?
# #     return unless force || user.pin_digest.blank?

# #     pin = identifier.normalized_value # ровно 4 цифры
# #     if user.respond_to?(:pin=)        # has_secure_password :pin
# #       user.pin = pin
# #     else
# #       user.pin_digest = BCrypt::Password.create(pin)
# #     end
# #     user.save!
# #   end

# #   # ---------- вспомогалки ----------

# #   def split_fio(fio)
# #     parts = fio.split(/\s+/)
# #     [parts[0], parts[1], parts[2..]&.join(' ')].map(&:to_s)
# #   end

# #   def normalize_num(num)
# #     d = num.to_s.gsub(/\D/, '')
# #     return d if d.length == 4

# #     nil
# #   end

# #   def detect_sep(data)
# #     first = data.lines.first.to_s
# #     first.count(';') > first.count(',') ? ';' : ','
# #   end

# #   def map_direction(val)
# #     v = val.to_s.strip.downcase
# #     return 'in' if v.include?('вход') || v == 'in'

# #     'out' if v.include?('выход') || v == 'out'
# #   end

# # end

# # class CsvImporter

# #   require 'csv'
# #   require 'bcrypt'
# #   require 'digest/sha2'

# #   def initialize(io_or_string, filename:)
# #     @data = io_or_string.respond_to?(:read) ? io_or_string.read : io_or_string.to_s
# #     @file = ImportFile.new(filename: filename, checksum: Digest::SHA256.hexdigest(@data))
# #   end

# #   def call!
# #     CSV.parse(@data, headers: true, col_sep: detect_sep(@data)).each do |row|
# #       import_row!(row.to_h)
# #     end
# #     @file.rows_count = @count
# #     @file.save!
# #   end

# #   private

# #   def import_row!(h)
# #     division_name   = h['Подразделение'].to_s.strip
# #     fio             = h['Сотрудник'].to_s.strip
# #     personal_number = h['Таб. №'].to_s.strip
# #     happened_at     = begin
# #       Time.zone.parse(h['Дата и время'].to_s)
# #     rescue StandardError
# #       nil
# #     end
# #     direction       = map_direction(h['Направление'])
# #     door            = h['Дверь']
# #     zone            = h['Зона доступа']
# #     comment         = h['Комментарий']

# #     division = Division.find_or_create_by!(name: division_name) if division_name.present?

# #     last, first, middle = split_fio(fio)
# #     user = find_or_create_user!(last:, first:, middle:)
# #     ensure_auth_login!(user, last:, first:, middle:)
# #     user.update!(current_division: division) if division && user.current_division_id != division&.id
# #     ensure_division_membership!(user, division) if division

# #     if personal_number.present?
# #       num4 = normalize_num(personal_number) # ← РОВНО 4 цифры или nil
# #       if num4
# #         idf = PersonalIdentifier.find_or_create_by!(normalized_value: num4) { |x| x.value = personal_number }
# #         ensure_number_assigned!(user, idf, happened_at || Time.current)
# #         ensure_pin_from_identifier!(user, idf, force: true) # PIN = те же 4 цифры
# #       else
# #         Rails.logger.warn "CSVImporter: пропустил строку — некорректный персональный номер: #{personal_number.inspect}"
# #       end
# #     end

# #     if happened_at && direction
# #       Pass.create!(
# #         user: user, happened_at: happened_at, direction: direction,
# #         door: door, zone: zone, comment: comment, raw: h, import_file: @file
# #       )
# #     end

# #     @count = (@count || 0) + 1
# #   end

# #   # --- история номеров/подразделений (как было) ---
# #   def ensure_number_assigned!(user, idf, at)
# #     PersonalIdentifierAssignment.where(personal_identifier_id: idf.id).active_at(at).where.not(user_id: user.id)
# #                                 .find_each { |a| a.update!(period: a.period.begin...at) }
# #     PersonalIdentifierAssignment.where(user_id: user.id).active_at(at).where.not(personal_identifier_id: idf.id)
# #                                 .find_each { |a| a.update!(period: a.period.begin...at) }
# #     PersonalIdentifierAssignment.where(user_id: user.id, personal_identifier_id: idf.id).active_at(at).first ||
# #       PersonalIdentifierAssignment.create!(user: user, personal_identifier: idf, period: at..Float::INFINITY)
# #   end

# #   def ensure_division_membership!(user, division)
# #     now = Time.current
# #     active = UserDivisionMembership.where(user: user).active_at(now).first
# #     return if active&.division_id == division.id

# #     active&.update!(period: active.period.begin...now)
# #     UserDivisionMembership.create!(user: user, division: division, period: now..Float::INFINITY)
# #   end

# #   # --- пользователи/логин ---
# #   def find_or_create_user!(last:, first:, middle:)
# #     User.where(last_name: last, first_name: first, middle_name: middle).first ||
# #       User.create!(last_name: last, first_name: first, middle_name: middle)
# #   end

# #   def ensure_auth_login!(user, last:, first:, middle:)
# #     return if user.auth_login.present?

# #     user.update!(auth_login: build_login(last:, first:, middle:))
# #   end

# #   def build_login(last:, first:, middle: nil)
# #     base = "#{last} #{first}".to_slug
# #                              .transliterate(:russian)
# #                              .normalize(separator: '.', strict: true)
# #                              .to_s
# #     base = 'user' if base.blank?
# #     disambiguate(base)
# #   end

# #   def disambiguate(base)
# #     login = base
# #     i = 0
# #     while User.exists?(['lower(auth_login) = ?', login.downcase])
# #       i += 1
# #       login = "#{base}.#{i}"
# #     end
# #     login
# #   end

# #   # --- PIN из 4-значного номера ---
# #   def ensure_pin_from_identifier!(user, identifier, force: false)
# #     return unless identifier && identifier.normalized_value.present?
# #     return unless force || user.pin_digest.blank?

# #     pin = identifier.normalized_value # уже ровно 4 цифры
# #     if user.respond_to?(:pin=)        # has_secure_password :pin
# #       user.pin = pin
# #     else
# #       user.pin_digest = BCrypt::Password.create(pin)
# #     end
# #     user.save!
# #   end

# #   # --- утилиты ---
# #   def split_fio(fio)
# #     parts = fio.split(/\s+/)
# #     [parts[0], parts[1], parts[2..]&.join(' ')].map(&:to_s)
# #   end

# #   def normalize_num(num)
# #     d = num.to_s.gsub(/\D/, '')
# #     return d if d.length == 4

# #     nil
# #   end

# #   def detect_sep(data)
# #     first = data.lines.first.to_s
# #     first.count(';') > first.count(',') ? ';' : ','
# #   end

# #   def map_direction(val)
# #     v = val.to_s.strip.downcase
# #     return 'in' if v.include?('вход') || v == 'in'

# #     'out' if v.include?('выход') || v == 'out'
# #   end

# # end
